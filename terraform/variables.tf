variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "sample-app-NewRelic"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)."
  type        = string
  default     = "devl"
}

variable "vpc_id" {
  description = "Existing VPC ID to deploy into."
  type        = string
  default     = "vpc-03ce369b7374fd1e6"
}

variable "image_tag" {
  description = "Tag of the application image in ECR to deploy."
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "allowed_http_cidr" {
  description = "CIDR range allowed to reach the app over HTTP."
  type        = string
  default     = "0.0.0.0/0"
}
