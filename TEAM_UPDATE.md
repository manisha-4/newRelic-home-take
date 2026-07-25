# Team Update (Slack)

> :rocket: *Deploying sample-app on AWS ECS Fargate — environment: devl*

*What & why:* sample-app is a simple Flask-based application that demonstrates a complete container deployment lifecycle on AWS. It is being deployed to validate Terraform infrastructure provisioning, Docker image publishing to ECR, and GitHub-based deployment through an assumed AWS role.

*Key changes / impact:*
• Provisioned ECS Fargate infrastructure using Terraform in the existing VPC and subnets
• Added an ECR repository and container-based deployment path for sample-app
• Wired GitHub Actions to deploy through an AWS role using OIDC, while local deployment continues to use access key and secret key credentials
• Added health and readiness behavior so the app can be validated through the load balancer

*Deployment flow:*
1. Build the container image locally or in GitHub Actions
2. Push the image to Amazon ECR
3. Terraform updates the ECS service to run the latest image
4. Requests flow through the Application Load Balancer to the container and are logged in CloudWatch

*Timeline:* The deployment workflow runs from GitHub Actions and completes in a few minutes for a standard update.

*Links:*
• Architecture overview: README.md
• Deployment guide: RUNBOOK.md
• Pipeline runs: GitHub → Actions → Terraform

*Risks / concerns:*
• The current deployment is a baseline implementation and does not yet include full production hardening
• Future improvements will include HTTPS, autoscaling, and stronger network isolation

*Questions / issues:* ping me in #devops if the deployment or health checks need attention.
