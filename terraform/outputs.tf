output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.app_cluster.name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the app image."
  value       = aws_ecr_repository.app.repository_url
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.app_service.name
}

output "task_definition_arn" {
  description = "ARN of the Fargate task definition."
  value       = aws_ecs_task_definition.app_task_definition.arn
}

output "load_balancer_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = aws_lb.app_alb.dns_name
}

output "vpc_id" {
  description = "Existing VPC the app was deployed into."
  value       = data.aws_vpc.selected.id
}
