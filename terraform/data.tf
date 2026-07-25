# Current AWS account ID for building service ARNs.
data "aws_caller_identity" "current" {}

# Subnets that already exist in the selected VPC (used for the ALB and Fargate tasks).
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}
