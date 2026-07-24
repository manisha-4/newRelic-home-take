# Deployment Runbook

Step-by-step guide to deploy, verify, and roll back the `cass-tutorial` web app.
Written so someone who did not build it can run it at 2am.

## 1. Prerequisites

**Tools**
- Terraform >= 1.5
- AWS CLI v2
- Docker (to build/push the app image)
- Git

**Credentials & permissions**
- AWS access key + secret for an IAM principal in the target account.
  - For `terraform plan` only: `ReadOnlyAccess` is enough.
  - For `terraform apply`: permissions for ECR, ECS, IAM (create role + attach policy),
    CloudWatch Logs, and EC2 (security groups) plus VPC/subnet read.
- The target account must have an existing **default VPC** with at least one subnet.

**Local setup**
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

## 2. Deploy

### Option A — via GitHub Actions (recommended)
1. Ensure repo secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set.
2. Merge your change into `main`.
3. Watch the **Terraform** workflow → the `Apply` step deploys.

### Option B — locally
```bash
cd terraform
terraform init

# 1. Create the ECR repo first.
terraform apply -target=aws_ecr_repository.app

# 2. Build & push the image.
REPO=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${REPO%/*}"
docker build -t "$REPO:latest" ../app
docker push "$REPO:latest"

# 3. Deploy everything.
terraform apply    # type "yes" to confirm
```

## 3. Deploying to different environments (dev / staging / prod)

Environment is a variable. Use a per-environment tfvars file or `-var`:
```bash
terraform apply -var="environment=staging"
# or
terraform apply -var-file=staging.tfvars
```
For real isolation, run each environment against its own state backend / AWS account.

## 4. Verify the deployment

```bash
CLUSTER=$(terraform output -raw cluster_name)
SERVICE=$(terraform output -raw service_name)

# Service should report runningCount == desiredCount.
aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].{running:runningCount,desired:desiredCount,status:status}'

# Find the task's public IP, then curl it (expect the nginx welcome page).
TASK=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --query 'taskArns[0]' --output text)
ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
aws ec2 describe-network-interfaces --network-interface-ids "$ENI" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```
Then `curl http://<public-ip>:8080/health` (expect `{"status":"ok"}`).
Also check container logs in CloudWatch under `/ecs/<project>-<env>`.

## 5. Rollback

- **Bad change not yet applied:** close/revert the PR — nothing is live.
- **Bad change applied:** revert the commit on `main` and let the pipeline re-apply
  the previous known-good state, or locally:
  ```bash
  git revert <bad-commit> && git push
  ```
- **Full teardown:**
  ```bash
  cd terraform
  terraform destroy
  ```

## 6. Common issues & troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `no matching EC2 VPC found` | Account has no default VPC | Create a default VPC or point the data source at an existing one |
| `UnauthorizedOperation` / `AccessDenied` on apply | Credentials are read-only | Use a role/keys with ECS + IAM write permissions |
| Task stuck in `PENDING` / stopping | Can't pull image or no route to internet | Confirm public subnet + `assign_public_ip=true`; check image name |
| Pipeline fails at `fmt -check` | Unformatted code | Run `terraform fmt -recursive` and commit |
| App not reachable | SG blocks you / task still starting | Wait ~1 min; confirm your IP matches `allowed_http_cidr` |
| `Error acquiring state lock` | Concurrent run | Wait or `terraform force-unlock <id>` |
