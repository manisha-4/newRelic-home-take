# cass-tutorial — AWS ECS Fargate App via Terraform + GitHub Actions

A minimal, production-minded example that deploys a basic containerized app to
**AWS ECS Fargate** using Terraform, with a GitHub Actions pipeline that runs
`terraform plan` on every pull request and deploys (`terraform apply`) on merge to
`main`.

## What is being deployed (and why)

A small **Python (Flask) HTTP API** packaged as a Docker image and run as a
single-task **ECS Fargate service**. It exposes `/` (a JSON hello message) and
`/health` (a health check).

- **Why this app?** It is a real, self-contained service (own code + Dockerfile)
  that is still tiny enough to reason about. It proves the full path: build image →
  push to ECR → run on Fargate → serve traffic → ship logs.
- **Why Fargate (not EC2/Lambda)?** Fargate runs containers with **no servers to
  manage** and no capacity to patch. It is the simplest way to run a container on
  AWS and mirrors how most teams ship services today.
- **Why build our own image?** The container image is the deployable artifact; CI
  builds it, pushes it to **ECR**, and ECS runs that exact tagged image.

## AWS architecture (and why)

```
                 Internet
                    │  HTTP :80
          ┌─────────▼──────────┐
          │  Security Group    │  ingress 80, egress all
          └─────────┬──────────┘
   Existing VPC     │
   (default)  ┌─────▼───────────────┐
              │ ECS Fargate Service │  awsvpc, public IP
              │   └─ Task (nginx)   │──▶ CloudWatch Logs
              └─────────────────────┘
```

- **Reuses the existing (default) VPC** and its subnets via data sources — the
  config **never creates a VPC**.
- **App image is stored in ECR** and referenced by immutable commit-SHA tag.
- **Fargate launch type**, so there are no EC2 hosts to manage.
- **Least-privilege IAM:** only a task execution role (pull image + write logs)
  via the AWS-managed `AmazonECSTaskExecutionRolePolicy`.
- **Observability built in:** container logs stream to a CloudWatch log group.
- **Consistent tagging** via provider `default_tags` (Project / Environment / ManagedBy).

## Repository layout

```
.
├── .github/workflows/terraform.yml   # CI/CD: infra job (plan/apply) + image job (ECR)
├── app/
│   ├── app.py                         # Flask app (/ and /health)
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/
│   ├── versions.tf                   # provider + version pins, default tags
│   ├── variables.tf                  # inputs
│   ├── data.tf                       # existing VPC + subnets
│   ├── main.tf                       # ECR, cluster, IAM, logs, task def, service, SG
│   ├── outputs.tf                    # cluster/service/task-def, ecr url, vpc_id
│   └── terraform.tfvars.example      # sample values
├── README.md
├── RUNBOOK.md
└── TEAM_UPDATE.md
```

## How to use the Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # optional; edit as needed
terraform init
terraform plan
terraform apply
```

## How to use the GitHub Actions pipeline

The workflow has two jobs:

1. **Infrastructure** (`terraform`) — runs `fmt`, `init`, `validate`, and `plan` on
   every PR; on merge to `main` it runs `apply` to provision the ECR repo, ECS
   cluster, task definition, and service.
2. **Image upload to ECR** (`image`) — runs after the infrastructure job on merge to
   `main`: builds the Docker image, pushes it to ECR (tagged with the commit SHA and
   `latest`), and forces a new ECS deployment to roll it out.

Add repository secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` first.

## Run the app locally

```bash
cd app
docker build -t cass-tutorial .
docker run -p 8080:8080 cass-tutorial
curl localhost:8080/        # {"message":"Hello from cass-tutorial!",...}
curl localhost:8080/health  # {"status":"ok"}
```

## Trade-offs I made

- **No load balancer.** Tasks get a public IP directly to keep the demo minimal.
  This means the public IP changes if the task is replaced.
- **Local state**, not remote. Simplest for a time-boxed task; production should use
  an S3 backend with DynamoDB locking.
- **Static AWS keys** as GitHub secrets (as the assignment specifies). Production
  should use **GitHub OIDC → IAM role** so no long-lived keys are stored.
- **`allowed_http_cidr` defaults to `0.0.0.0/0`** for easy testing; lock this down
  in real environments.

## What I would change for production

- Front the service with an **Application Load Balancer** (stable DNS + health checks)
  and place tasks in private subnets.
- Remote state (S3 + DynamoDB lock) and per-environment backends.
- OIDC-based authentication instead of static keys.
- Autoscaling on CPU/memory, HTTPS via ACM, and CloudWatch alarms/dashboards.
