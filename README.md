# newrelic-home-take-app — AWS ECS Fargate deployment with Terraform and GitHub Actions

newrelic-home-take-app is a lightweight containerized web application that demonstrates a full cloud-native deployment path on AWS. The application is a small Python Flask API that serves a friendly response on the root endpoint and a health check endpoint for readiness and monitoring.

## What the project deploys

This repository provisions a production-style deployment for newrelic-home-take-app on AWS using:

- an **Amazon ECR repository** for the application image
- an **Amazon ECS Fargate cluster** and service
- an **Application Load Balancer** and target group for HTTP traffic
- **IAM roles and policies** for container execution and GitHub-based deployment
- **CloudWatch Logs** for container observability
- **Terraform** for infrastructure as code and **GitHub Actions** for automation

The deployed app is a simple Flask service that exposes:

- `/` — returns a JSON message identifying the application and environment
- `/health` — returns a health response used by the load balancer and monitoring checks

## Application flow

1. The developer updates the application code or infrastructure configuration.
2. The Docker image is built locally or in GitHub Actions.
3. The image is pushed to Amazon ECR.
4. Terraform provisions or updates the ECS service so the new image runs on Fargate.
5. The ALB forwards traffic to the running container, and logs are published to CloudWatch.

This gives a complete end-to-end workflow for building, shipping, and running a containerized service in AWS.

## Local deployment flow

Local deployment uses AWS access credentials directly.

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-2"

cd terraform
terraform init
terraform plan -var="environment=devl" -var="vpc_id=vpc-03ce369b7374fd1e6"
terraform apply -var="environment=devl" -var="vpc_id=vpc-03ce369b7374fd1e6"
```

After the infrastructure is ready, build and push the image:

```bash
cd ../app
docker build -t newrelic-home-take-app:latest .
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com
docker tag newrelic-home-take-app:latest <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com/newrelic-home-take-app-devl:latest
docker push <account-id>.dkr.ecr.ap-southeast-2.amazonaws.com/newrelic-home-take-app-devl:latest
```

## GitHub deployment flow

GitHub Actions uses an AWS IAM role through OIDC instead of long-lived secrets. The workflow assumes the deployment role and runs Terraform and image deployment steps from the repository.

This makes the GitHub pipeline suitable for:

- automated infrastructure changes
- image build and push to ECR
- ECS service updates from the latest application version

## Repository structure

```text
.
├── app/                  # Flask application and Dockerfile
├── terraform/            # Terraform configuration for ECS, ECR, ALB, IAM, networking
├── .github/workflows/    # GitHub Actions workflow for deployment
├── README.md             # overview and architecture summary
├── RUNBOOK.md            # deployment and rollback steps
└── TEAM_UPDATE.md        # project status summary
```

## Why this solution exists

newrelic-home-take-app is a foundational example for teams that want to learn or standardize on:

- container-based deployment on AWS
- infrastructure as code with Terraform
- automated delivery through GitHub Actions
- observability with logs and health checks
- a repeatable path from code commit to live service

