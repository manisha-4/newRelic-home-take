# Team Update (Slack)

> :rocket: *Deploying: cass-tutorial app (nginx on ECS Fargate) to AWS — `dev`*

*What & why:* Shipping a basic containerized app on ECS Fargate to validate our
Terraform + GitHub Actions deployment path end to end.

*Key changes / impact:*
• New ECS cluster, Fargate service + security group in the **existing default VPC** (no new networking)
• CI/CD: `terraform plan` on every PR, auto `apply` on merge to `main`
• No impact to existing resources

*Timeline:* Deploys automatically on merge to `main` (~2–3 min).

*Links:*
• PR: <link>
• Architecture & decisions: `README.md`
• Deploy steps / rollback: `RUNBOOK.md`
• Pipeline runs: GitHub → Actions → *Terraform*

*Risks / concerns:*
• Single task, no load balancer = public IP changes on task replacement (demo only)
• HTTP open to `0.0.0.0/0` by default — lock down before real use

*Questions / issues:* ping me (@you) in #devops.
