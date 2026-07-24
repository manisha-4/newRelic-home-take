# Reuse the provided VPC instead of relying on the default VPC.
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Current AWS account ID for building service ARNs.
data "aws_caller_identity" "current" {}

# Subnets that already exist in the selected VPC (used for the ALB and Fargate tasks).
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}
