# ============================================================
# ECS Module — Main
# ============================================================
# Creates:
#   → ECS Cluster
#   → CloudWatch Log Groups (one per service)
#   → IAM: Task Execution Role (ECS agent permissions)
#   → IAM: Task Role (app runtime permissions)
#   → Task Definitions (4 services)
#   → ECS Services (4 services)
#
# TWO IAM roles explained:
#
#   Task Execution Role → used BY ECS AGENT
#     to SETUP the task before app starts:
#     → pull image from ECR
#     → write logs to CloudWatch
#     → fetch secrets from Secrets Manager
#        and inject as env vars into container
#
#   Task Role → used BY YOUR APP (running container)
#     runtime permissions your app needs:
#     → call Secrets Manager API directly
#     → call other AWS services if needed
#
#   Interview: "Execution role = ECS agent
#               Task role = your application"
# ============================================================

# ── ECS Cluster ───────────────────────────────────────────────
# Logical grouping of all ECS services
# Fargate = no EC2 instances to manage!
# AWS manages all underlying infrastructure
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  # Container Insights = CloudWatch metrics per task!
  # CPU, memory, network per container
  # Costs extra but worth it in prod!
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project}-${var.environment}-cluster"
  }
}

# ── CloudWatch Log Groups ─────────────────────────────────────
# One log group per service
# Container stdout/stderr → CloudWatch automatically!
# No SSH needed to check logs! ✅
# retention_in_days = 7 (dev) saves cost!
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project}/${var.environment}/frontend"
  retention_in_days = 7

  tags = {
    Service = "frontend"
  }
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/ecs/${var.project}/${var.environment}/gateway"
  retention_in_days = 7

  tags = {
    Service = "gateway"
  }
}

resource "aws_cloudwatch_log_group" "user_service" {
  name              = "/ecs/${var.project}/${var.environment}/user-service"
  retention_in_days = 7

  tags = {
    Service = "user-service"
  }
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${var.project}/${var.environment}/order-service"
  retention_in_days = 7

  tags = {
    Service = "order-service"
  }
}

# ── Task Execution Role ───────────────────────────────────────
# Used BY ECS AGENT (not your app!)
# Needs permissions to:
#   → pull image from ECR (before container starts)
#   → write logs to CloudWatch (container stdout)
#   → fetch secrets from Secrets Manager
#      and inject as environment variables!
resource "aws_iam_role" "task_execution" {
  name = "${var.project}-${var.environment}-ecs-task-execution-role"

  # ECS tasks service assumes this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ecs-task-execution-role"
  }
}

# AWS managed policy for ECS task execution
# Includes: ECR pull + CloudWatch logs write
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Extra policy: allow execution role to fetch secrets
# Needed when task definition references secrets from SM
# ECS agent fetches secret VALUE and injects into container
resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "secrets-manager-fetch"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      # Restrict to only our secrets!
      # Not wildcard * — least privilege! ✅
      Resource = [
        var.user_db_secret_arn,
        var.order_db_secret_arn
      ]
    }]
  })
}

# ── Task Role ─────────────────────────────────────────────────
# Used BY YOUR RUNNING APP (container)
# Your Node.js app calls Secrets Manager API directly
# to fetch full DB credentials at runtime
resource "aws_iam_role" "task" {
  name = "${var.project}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ecs-task-role"
  }
}

# App runtime permissions:
# user-service and order-service call SM to get DB password
resource "aws_iam_role_policy" "task_secrets" {
  name = "secrets-manager-read"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        var.user_db_secret_arn,
        var.order_db_secret_arn
      ]
    }]
  })
}

# ── Task Definition: Frontend ─────────────────────────────────
# Nginx serving static index.html
# Polls /api/dashboard (handled by ALB → gateway)
# Port 80 → mapped to container port 80
#
# No secrets needed! Frontend is static HTML + JS
# Just needs to be served by nginx on port 80
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory

  # Execution role → ECS agent pulls image + writes logs
  execution_role_arn = aws_iam_role.task_execution.arn
  # Task role → container runtime (frontend needs no AWS calls)
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "${var.ecr_registry}/frontend:${var.image_tag}"

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    # awslogs driver → sends stdout/stderr to CloudWatch!
    # No sidecar needed, built into Fargate!
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }

    # Health check inside container
    # ECS marks task unhealthy if this fails!
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    essential = true
  }])

  tags = {
    Name    = "${var.project}-${var.environment}-frontend-td"
    Service = "frontend"
  }
}

# ── Task Definition: Gateway ──────────────────────────────────
# Aggregates user-service + order-service data
# Port 3000
# Needs to know where user-service and order-service are!
#
# In ECS with awsvpc networking:
#   Each task gets its OWN private IP!
#   Services communicate via:
#   → ECS Service Discovery (DNS based) ← we use this!
#   → Or direct IP (not recommended, IPs change!)
#
# Service Discovery creates DNS:
#   user-service.micro-dash.local → task IP
#   order-service.micro-dash.local → task IP
resource "aws_ecs_task_definition" "gateway" {
  family                   = "${var.project}-${var.environment}-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.gateway_cpu
  memory                   = var.gateway_memory

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "gateway"
    image = "${var.ecr_registry}/gateway:${var.image_tag}"

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    # Tell gateway where to find other services!
    # Uses ECS Service Discovery DNS names
    environment = [
      {
        name  = "USER_SERVICE_URL"
        value = "http://user-service.${var.project}-${var.environment}.local:3001"
      },
      {
        name  = "ORDER_SERVICE_URL"
        value = "http://order-service.${var.project}-${var.environment}.local:3002"
      },
      {
        name  = "PORT"
        value = "3000"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.gateway.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "gateway"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    essential = true
  }])

  tags = {
    Name    = "${var.project}-${var.environment}-gateway-td"
    Service = "gateway"
  }
}

# ── Task Definition: User Service ─────────────────────────────
# CRUD on PostgreSQL usersdb
# Port 3001
# Needs DB credentials from Secrets Manager!
#
# DB_SECRET_NAME env var → app reads this at startup
# App calls: aws secretsmanager get-secret-value
#   → gets host, port, username, password, dbname
#   → creates pg connection pool
resource "aws_ecs_task_definition" "user_service" {
  family                   = "${var.project}-${var.environment}-user-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.user_service_cpu
  memory                   = var.user_service_memory

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "user-service"
    image = "${var.ecr_registry}/user-service:${var.image_tag}"

    portMappings = [{
      containerPort = 3001
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "PORT"
        value = "3001"
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        # App reads this to know WHICH secret to fetch!
        # db.js: const secret = await SM.getSecretValue({
        #          SecretId: process.env.DB_SECRET_NAME })
        name  = "DB_SECRET_NAME"
        value = var.user_db_secret_name
      },
      {
        # Disable SSL cert verification
        # RDS uses self-signed cert → Node.js rejects by default
        # Production: use proper RDS CA cert instead!
        name  = "NODE_TLS_REJECT_UNAUTHORIZED"
        value = "0"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.user_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "user-service"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    essential = true
  }])

  tags = {
    Name    = "${var.project}-${var.environment}-user-service-td"
    Service = "user-service"
  }
}

# ── Task Definition: Order Service ────────────────────────────
# CRUD on PostgreSQL ordersdb
# Port 3002
resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.project}-${var.environment}-order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.order_service_cpu
  memory                   = var.order_service_memory

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name  = "order-service"
    image = "${var.ecr_registry}/order-service:${var.image_tag}"

    portMappings = [{
      containerPort = 3002
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "PORT"
        value = "3002"
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "DB_SECRET_NAME"
        value = var.order_db_secret_name
      },
      {
        name  = "NODE_TLS_REJECT_UNAUTHORIZED"
        value = "0"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.order_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "order-service"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3002/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    essential = true
  }])

  tags = {
    Name    = "${var.project}-${var.environment}-order-service-td"
    Service = "order-service"
  }
}

# ── Service Discovery Namespace ───────────────────────────────
# Private DNS namespace for internal service communication!
#
# Without service discovery:
#   gateway needs to know user-service IP
#   But Fargate task IPs change on every restart!
#   Hardcoding IPs = breaks every deploy! ❌
#
# With service discovery:
#   user-service registers as:
#   user-service.micro-dash-dev.local → auto-updated IP!
#   gateway always resolves correct IP! ✅
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project}-${var.environment}.local"
  description = "Private DNS for ECS service discovery"
  vpc         = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-namespace"
  }
}

# ── Service Discovery: User Service ──────────────────────────
resource "aws_service_discovery_service" "user_service" {
  name = "user-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

}

# ── Service Discovery: Order Service ─────────────────────────
resource "aws_service_discovery_service" "order_service" {
  name = "order-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

}

# ── ECS Service: Frontend ─────────────────────────────────────
# "Always keep desired_count frontend tasks running!"
# Auto-registers tasks with ALB frontend target group!
# Rolling deployment: replaces tasks one by one!
resource "aws_ecs_service" "frontend" {
  name            = "${var.project}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # awsvpc networking:
  # Each task gets own ENI + private IP
  # Tasks in private subnets (secure!)
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  # Register tasks with ALB target group!
  # ECS auto-registers on task start
  # ECS auto-deregisters on task stop
  load_balancer {
    target_group_arn = var.frontend_tg_arn
    container_name   = "frontend"
    container_port   = 80
  }

  # Rolling deployment settings:
  # minimum_healthy_percent = 50
  #   → during deploy, keep at least 50% tasks running
  #   → for desired=1: stop old, start new (brief downtime)
  #   → for desired=2: always 1 task running! zero downtime!
  #
  # maximum_percent = 200
  #   → can run up to 200% tasks during deployment
  #   → for desired=2: run 4 tasks briefly (2 old + 2 new)
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Wait for tasks to be healthy before considering deploy done
  deployment_circuit_breaker {
    enable   = true
    rollback = true
    # If new tasks fail health checks → auto rollback! ✅
    # Interview: "ECS has built-in rollback on failed deploy!"
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution
  ]

  tags = {
    Name    = "${var.project}-${var.environment}-frontend-svc"
    Service = "frontend"
  }
}

# ── ECS Service: Gateway ──────────────────────────────────────
resource "aws_ecs_service" "gateway" {
  name            = "${var.project}-${var.environment}-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.gateway_tg_arn
    container_name   = "gateway"
    container_port   = 3000
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution
  ]

  tags = {
    Name    = "${var.project}-${var.environment}-gateway-svc"
    Service = "gateway"
  }
}

# ── ECS Service: User Service ─────────────────────────────────
# No ALB attachment! Internal service only!
# Gateway calls user-service via Service Discovery DNS
# user-service.micro-dash-dev.local:3001
resource "aws_ecs_service" "user_service" {
  name            = "${var.project}-${var.environment}-user-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  # Service Discovery registration!
  # Task IP auto-registered in Route53 private zone
  # user-service.micro-dash-dev.local → task IP
  service_registries {
    registry_arn = aws_service_discovery_service.user_service.arn
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution
  ]

  tags = {
    Name    = "${var.project}-${var.environment}-user-service-svc"
    Service = "user-service"
  }
}

# ── ECS Service: Order Service ────────────────────────────────
resource "aws_ecs_service" "order_service" {
  name            = "${var.project}-${var.environment}-order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.order_service.arn
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution
  ]

  tags = {
    Name    = "${var.project}-${var.environment}-order-service-svc"
    Service = "order-service"
  }
}