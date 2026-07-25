# Deployment Runbook

This runbook explains how to deploy, verify, and roll back the sample-app service. The application is a small Flask-based API running in AWS ECS Fargate behind an Application Load Balancer and backed by Amazon ECR.

## 1. Prerequisites

**Tools**
- Terraform 1.9 or newer
- AWS CLI v2
- Docker
- Git

**Credentials and permissions**
- For local deployment, set an AWS access key and secret key for an IAM principal that can manage ECS, ECR, IAM, CloudWatch Logs, and networking resources.
- For GitHub deployment, use an AWS IAM role that GitHub Actions can assume through OIDC. This role should include the permissions needed for Terraform apply and image rollout.
- The target account must have an existing VPC and subnet set available for the deployment.

**Local setup**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-2"
```

## 2. Deploy locally

### Option A — deploy infrastructure with Terraform
```bash
cd terraform
terraform init
terraform plan -var="environment=devl" -var="vpc_id=vpc-03ce369b7374fd1e6"
terraform apply -var="environment=devl" -var="vpc_id=vpc-03ce369b7374fd1e6"
```

### Option B — build and push the application image
```bash
cd ../app
docker build -t sample-app:latest .
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com
docker tag sample-app:latest <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com/sample-app-devl:latest
docker push <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com/sample-app-devl:latest
```

The Terraform configuration uses the image tag supplied in the variables file so that ECS runs the pushed image.

## 3. Deploy through GitHub Actions

GitHub Actions is the preferred workflow for repeatable deployments.

1. Ensure the repository is connected to an AWS role that GitHub can assume through OIDC.
2. Push changes to the target branch.
3. Trigger the workflow from the GitHub Actions UI or by merge to the main branch.
4. The workflow runs Terraform, pushes the image to ECR if needed, and updates the ECS service.

This path is preferred because it uses the AWS role directly and avoids storing long-lived AWS secrets in GitHub.

## 4. Verify the deployment

```bash
CLUSTER=$(terraform output -raw cluster_name)
SERVICE=$(terraform output -raw service_name)

aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].{running:runningCount,desired:desiredCount,status:status}'
```

You can also test the public endpoint:

```bash
curl http://<alb-dns-name>/
curl http://<alb-dns-name>/health
```

A successful response should include the sample-app JSON message and a health status of `ok`.

## 5. Roll back or destroy

- For a safe rollback, revert the application change or Terraform change and re-run the pipeline.
- To remove the deployment completely:

```bash
cd terraform
terraform destroy -var="environment=devl" -var="vpc_id=vpc-03ce369b7374fd1e6"
```

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Access denied during apply | Local AWS keys do not have enough permissions | Use an IAM principal with ECS, ECR, IAM, and networking permissions |
| GitHub workflow cannot assume the AWS role | OIDC trust policy or role permissions are incorrect | Verify the GitHub repository and role trust relationship |
| Task stays pending | The container image was not pulled successfully | Confirm the ECR image exists and the task execution role can pull it |
| Application is unreachable | Security group or target group health check is failing | Check ALB target group health and the container port |

## 7. Future scope

The deployment is a working baseline for sample-app. The next phase can add HTTPS, a managed database, autoscaling, and a stronger production-grade networking layout.
