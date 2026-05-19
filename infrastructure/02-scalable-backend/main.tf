terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.45.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "leader-developer-personal"
}

#################################################
# VARIABLES
#################################################

variable "env" {
  type = string
}

variable "app_image" {
  type        = string
  description = "URI de imagen ECR: 123456789.dkr.ecr.us-east-1.amazonaws.com/backend-dev:latest"
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "cors_origin" {
  type        = string
  description = "URL del frontend permitido en CORS (ej: https://tuapp.com)"
}

variable "aws_bucket_name" {
  type        = string
  description = "Nombre del bucket S3 de la Arquitectura 01 (CDN)"
}

variable "cloudfront_domain" {
  type        = string
  description = "Dominio CloudFront de la Arquitectura 01 (ej: https://xxxx.cloudfront.net)"
}

variable "cloudfront_keypair_id" {
  type        = string
  description = "ID del key pair de CloudFront (APKA...)"
}

variable "cloudfront_private_key" {
  type        = string
  sensitive   = true
  description = "Contenido PEM de la private key de CloudFront"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}

variable "cpu_scaling_target" {
  type    = number
  default = 60
}

#################################################
# DATA SOURCES
#################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Bucket S3 de la Arquitectura 01 (para dar permisos al Task Role)
data "aws_s3_bucket" "assets" {
  bucket = var.aws_bucket_name
}

#################################################
# VPC
#################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "vpc-backend-${var.env}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "igw-backend-${var.env}" }
}

# Subredes públicas — ALB
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "subnet-public-${count.index + 1}-${var.env}" }
}

# Subredes privadas — ECS tasks (sin IP pública)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "subnet-private-${count.index + 1}-${var.env}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "eip-nat-${var.env}" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]

  tags = { Name = "nat-backend-${var.env}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-public-${var.env}" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "rt-private-${var.env}" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#################################################
# SECURITY GROUPS
#################################################

resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.env}"
  description = "ALB: HTTP desde internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg-${var.env}" }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-sg-${var.env}"
  description = "ECS tasks: traffic only from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ecs-sg-${var.env}" }
}

#################################################
# ECR
#################################################

resource "aws_ecr_repository" "backend" {
  name                 = "backend-${var.env}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener últimas 10 imágenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

#################################################
# SECRETS MANAGER — secretos de la aplicación
#################################################

resource "aws_secretsmanager_secret" "app" {
  name                    = "backend-secrets-${var.env}"
  description             = "JWT secrets y CloudFront private key del backend"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    JWT_SECRET             = var.jwt_secret
    JWT_REFRESH_SECRET     = var.jwt_refresh_secret
    CLOUDFRONT_KEYPAIR_ID  = var.cloudfront_keypair_id
    CLOUDFRONT_PRIVATE_KEY = var.cloudfront_private_key
  })
}

#################################################
# IAM — Execution Role (pull ECR, CloudWatch, Secrets Manager)
#################################################

resource "aws_iam_role" "ecs_execution" {
  name = "ecs-execution-role-backend-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "ecs-secrets-access-${var.env}"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

#################################################
# IAM — Task Role (permisos de la app: S3 + CloudFront)
#################################################

resource "aws_iam_role" "ecs_task" {
  name = "ecs-task-role-backend-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "ecs-task-s3-${var.env}"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = "${data.aws_s3_bucket.assets.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = data.aws_s3_bucket.assets.arn
      }
    ]
  })
}

#################################################
# CLOUDWATCH — Log Group
#################################################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/backend-${var.env}"
  retention_in_days = 7
}

#################################################
# ECS CLUSTER
#################################################

resource "aws_ecs_cluster" "main" {
  name = "cluster-backend-${var.env}"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#################################################
# ECS TASK DEFINITION
#################################################

resource "aws_ecs_task_definition" "backend" {
  family                   = "backend-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = var.app_image

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    # Secretos desde Secrets Manager — nunca en texto plano
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:JWT_SECRET::" },
      { name = "JWT_REFRESH_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:JWT_REFRESH_SECRET::" },
      { name = "CLOUDFRONT_KEYPAIR_ID", valueFrom = "${aws_secretsmanager_secret.app.arn}:CLOUDFRONT_KEYPAIR_ID::" },
      { name = "CLOUDFRONT_PRIVATE_KEY", valueFrom = "${aws_secretsmanager_secret.app.arn}:CLOUDFRONT_PRIVATE_KEY::" },
    ]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT", value = tostring(var.app_port) },
      { name = "API_PREFIX", value = "/api/v1" },
      { name = "CORS_ORIGIN", value = var.cors_origin },
      { name = "AWS_REGION", value = data.aws_region.current.name },
      { name = "AWS_BUCKET_NAME", value = var.aws_bucket_name },
      { name = "CLOUDFRONT_DOMAIN", value = var.cloudfront_domain },
      { name = "RATE_LIMIT_WINDOW_MS", value = "900000" },
      { name = "RATE_LIMIT_MAX", value = "100" },
      { name = "LOG_LEVEL", value = "combined" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "backend"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:${var.app_port}/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))\""]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

#################################################
# APPLICATION LOAD BALANCER
#################################################

resource "aws_lb" "main" {
  name               = "alb-backend-${var.env}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = { Name = "alb-backend-${var.env}" }
}

resource "aws_lb_target_group" "backend" {
  name        = "tg-backend-${var.env}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = { Name = "tg-backend-${var.env}" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

#################################################
# ECS SERVICE
#################################################

resource "aws_ecs_service" "backend" {
  name            = "backend-service-${var.env}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = var.app_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

#################################################
# AUTO SCALING
#################################################

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "cpu-tracking-backend-${var.env}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_scaling_target
    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
}

#################################################
# CLOUDWATCH — Alarmas
#################################################

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "ecs-cpu-high-backend-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU del backend > 80% por 2 minutos"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "alb-unhealthy-hosts-backend-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Hay containers no saludables detrás del ALB"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

#################################################
# CLOUDWATCH — Dashboard
#################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "backend-${var.env}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          region = "us-east-1"
          title  = "ECS CPU Utilization (%)"
          period = 60
          stat   = "Average"
          view   = "timeSeries"

          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.backend.name
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          region = "us-east-1"
          title  = "ECS Memory Utilization (%)"
          period = 60
          stat   = "Average"
          view   = "timeSeries"

          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.backend.name
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          region = "us-east-1"
          title  = "ALB Request Count"
          period = 60
          stat   = "Sum"
          view   = "timeSeries"

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.main.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          region = "us-east-1"
          title  = "ALB Target Response Time (s)"
          period = 60
          stat   = "Average"
          view   = "timeSeries"

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              aws_lb.main.arn_suffix
            ]
          ]
        }
      }
    ]
  })
}

#################################################
# OUTPUTS
#################################################

output "api_endpoint" {
  description = "Endpoint público del backend"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR para push de imágenes"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.backend.name
}

output "cloudwatch_dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
