terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block        = var.vpc_cidr
  instance_tenancy  = "default"

  tags = {
    Name = "${var.PREFIX}-vpc"
  }
}

# Internet Gateway for the Public Subnets
resource "aws_internet_gateway" "int_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.PREFIX}_int_gateway"
  }
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.PREFIX}_private_subnet"
  }
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.PREFIX}_public_subnet"
  }
}

# Nat Gateway for private subnet
resource "aws_eip" "nat_gateway_eip" {
  vpc = true
  tags = {
    Name = "${var.PREFIX}_nat_gateway_eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.PREFIX}_nat_gateway"
  }
}

# Public route table
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int_gateway.id
  }

  tags = {
    Name = "${var.PREFIX}_public"
  }
}

# Private route table
resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.PREFIX}_private"
  }
}

# Associations
resource "aws_route_table_association" "assoc_1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table_public.id
}

resource "aws_route_table_association" "assoc_2" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route_table_private.id
}

# ECR repository
resource "aws_ecr_repository" "ECR_repository" {
  name                 = var.PREFIX
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.PREFIX}-cluster"
  capacity_providers = [
    "FARGATE"]
  setting {
    name = "containerInsights"
    value = "enabled"
  }
}

# Task execution role for used for ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.PREFIX}_ecs_task_execution_role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

# Attach policy to task execution role
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "admin-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Secrets
resource "aws_secretsmanager_secret" "PAT" {
  name = "${var.PREFIX}-PAT"
}

resource "aws_secretsmanager_secret_version" "PAT_version" {
  secret_id     = aws_secretsmanager_secret.PAT.id
  secret_string = var.PAT
}

resource "aws_secretsmanager_secret" "ORG" {
  name = "${var.PREFIX}-ORG"
}

resource "aws_secretsmanager_secret_version" "ORG_version" {
  secret_id     = aws_secretsmanager_secret.ORG.id
  secret_string = var.ORG
}

resource "aws_secretsmanager_secret" "REPO" {
  name = "${var.PREFIX}-REPO"
}

resource "aws_secretsmanager_secret_version" "REPO_version" {
  secret_id     = aws_secretsmanager_secret.REPO.id
  secret_string = var.REPO
}

resource "aws_secretsmanager_secret" "AWS_DEFAULT_REGION" {
  name = "${var.PREFIX}-AWS_DEFAULT_REGION"
}

resource "aws_secretsmanager_secret_version" "AWS_DEFAULT_REGION_version" {
  secret_id     = aws_secretsmanager_secret.AWS_DEFAULT_REGION.id
  secret_string = var.AWS_DEFAULT_REGION
}

resource "aws_secretsmanager_secret" "AWS_SECRET_ACCESS_KEY" {
  name = "${var.PREFIX}-AWS_SECRET_ACCESS_KEY"
}

resource "aws_secretsmanager_secret_version" "AWS_SECRET_ACCESS_KEY_version" {
  secret_id     = aws_secretsmanager_secret.AWS_SECRET_ACCESS_KEY.id
  secret_string = var.AWS_SECRET_ACCESS_KEY
}

resource "aws_secretsmanager_secret" "AWS_ACCESS_KEY_ID" {
  name = "${var.PREFIX}-AWS_ACCESS_KEY_ID"
}

resource "aws_secretsmanager_secret_version" "AWS_ACCESS_KEY_ID_version" {
  secret_id     = aws_secretsmanager_secret.AWS_ACCESS_KEY_ID.id
  secret_string = var.AWS_ACCESS_KEY_ID
}

# Task definition
resource "aws_cloudwatch_log_group" "ecs-log-group" {
  name = "/ecs/${var.PREFIX}-task-def"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.PREFIX}-task-def"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = "1024"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "ecs-runner",
      "image": "747632300909.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-runner:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "network_mode": "awsvpc",
      "portMappings": [
        {
            "containerPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-region" : "ap-northeast-1",
            "awslogs-group" : "/ecs/${var.PREFIX}-task-def",
            "awslogs-stream-prefix" : "ecs"
        }
      },
      "command": ["./start.sh"],
      "secrets": [{
        "name": "PAT",
        "valueFrom": "${aws_secretsmanager_secret.PAT.arn}"
      },
      {
        "name": "ORG",
        "valueFrom": "${aws_secretsmanager_secret.ORG.arn}"
      },
      {
        "name": "REPO",
        "valueFrom": "${aws_secretsmanager_secret.REPO.arn}"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "valueFrom": "${aws_secretsmanager_secret.AWS_DEFAULT_REGION.arn}"
      },
      {
        "name": "AWS_SECRET_ACCESS_KEY",
        "valueFrom": "${aws_secretsmanager_secret.AWS_SECRET_ACCESS_KEY.arn}"
      },
      {
        "name": "AWS_ACCESS_KEY_ID",
        "valueFrom": "${aws_secretsmanager_secret.AWS_ACCESS_KEY_ID.arn}"
      }]
    }
  ]
  TASK_DEFINITION
}

# A security group for ECS
resource "aws_security_group" "ecs_sg" {
  name        = "${var.PREFIX}-ecs-sg"
  description = "Allow incoming traffic for ecs"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.PREFIX}_ecs_sg"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name            = "${var.PREFIX}-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = "1"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = [aws_subnet.private_subnet.id]
    assign_public_ip = false
  }
}

# Autoscaling
resource "aws_appautoscaling_target" "dev_to_target" {
  max_capacity = 2
  min_capacity = 1
  resource_id = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "dev_to_memory" {
  name               = "dev-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 80
  }
}

resource "aws_appautoscaling_policy" "dev_to_cpu" {
  name = "dev-to-cpu"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.dev_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.dev_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}

# Giving a Fargate access to the Secrets in the Secret Manager
resource "aws_iam_role_policy" "password_policy_secretsmanager" {
  name = "password-policy-secretsmanager"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}