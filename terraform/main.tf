locals {
  name     = "${var.project_name}-${var.environment}"
  ecr_name = lower(local.name)
}

# ECR repository that stores the application image built by CI.
resource "aws_ecr_repository" "app" {
  name                 = local.ecr_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS cluster to run the Fargate service.
resource "aws_ecs_cluster" "app_cluster" {
  name = local.name
}

# CloudWatch log group for container logs.
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

# Task execution role: lets ECS pull the image and write logs.
resource "aws_iam_role" "execution" {
  name = "${local.name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_ecr_pull" {
  name = "${local.name}-execution-ecr-pull"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetAuthorizationToken"
      ]
      Resource = [aws_ecr_repository.app.arn]
    }]
  })
}

resource "aws_iam_policy" "ecr_push" {
  name        = "${local.name}-ecr-push"
  description = "Allow the GitHub Actions role to push container images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
      Resource = [aws_ecr_repository.app.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr" {
  role       = "GithubOIDC"
  policy_arn = aws_iam_policy.ecr_push.arn
}

resource "aws_iam_policy" "ecs_service_update" {
  name        = "${local.name}-ecs-update"
  description = "Allow the GitHub Actions role to update ECS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecs:DescribeServices",
        "ecs:UpdateService"
      ]
      Resource = [
        "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.app_cluster.name}/${aws_ecs_service.app_service.name}"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecs" {
  role       = "GithubOIDC"
  policy_arn = aws_iam_policy.ecs_service_update.arn
}

# Security group for the application load balancer.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Allow inbound HTTP to the application load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-alb"
  }
}

# Security group for the ECS service, only reachable from the ALB.
resource "aws_security_group" "service" {
  name        = "${local.name}-svc"
  description = "Allow inbound HTTP to the ECS service"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-svc"
  }
}

resource "aws_lb" "app_alb" {
  name               = substr(replace(local.name, "-", ""), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.selected.ids
}

resource "aws_lb_target_group" "app_target_group" {
  name        = substr("${local.name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# Fargate task definition for the container.
resource "aws_ecs_task_definition" "app_task_definition" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    environment = [{
      name  = "ENVIRONMENT"
      value = var.environment
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

# ECS service running the task on Fargate in the existing subnets.
resource "aws_ecs_service" "app_service" {
  name            = local.name
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task_definition.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.selected.ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_iam_role_policy_attachment.execution, aws_lb_listener.http_listener]
}
