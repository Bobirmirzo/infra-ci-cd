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
  cidr_block        = var.private_subnet_cidr[0]
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.PREFIX}_private_subnet"
  }
}

resource "aws_subnet" "private_subnet_db1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr[1]
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${var.PREFIX}_private_subnet_db1"
  }
}

resource "aws_subnet" "private_subnet_db2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr[2]
  availability_zone = "ap-northeast-1d"

  tags = {
    Name = "${var.PREFIX}_private_subnet_db2"
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

resource "aws_route_table_association" "assoc_3" {
  subnet_id      = aws_subnet.private_subnet_db1.id
  route_table_id = aws_route_table.route_table_private.id
}

resource "aws_route_table_association" "assoc_4" {
  subnet_id      = aws_subnet.private_subnet_db2.id
  route_table_id = aws_route_table.route_table_private.id
}

# EC2 Instance
## Security Group
resource "aws_security_group" "server_sg" {
  name        = "server_sg"
  description = "Server sg"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "${var.PREFIX}_server_sg"
  }
}

## Network interface
resource "aws_network_interface" "net_interface" {
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [ aws_security_group.server_sg.id ]

  tags = {
    Name = "${var.PREFIX}_server_net_interface"
  }
}

## Elastic Ip
resource "aws_eip" "server_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.net_interface.id
  depends_on                = [ aws_internet_gateway.int_gateway ]
}

## Server
resource "aws_instance" "server" {
  ami                       = "ami-0f2dd5fc989207c82"
  instance_type             = "t2.micro"
  availability_zone         = "ap-northeast-1a"
  key_name                  = "access-key"

  network_interface {
    device_index            = 0
    network_interface_id    = aws_network_interface.net_interface.id
  }

  tags = {
    Name = "${var.PREFIX}_bastion"
  }
}

# Subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.PREFIX}-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id,
                aws_subnet.private_subnet_db1.id,
                aws_subnet.private_subnet_db2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier              = "${var.PREFIX}-cluster"
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.KMSkeyDB.arn
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.09.1"
  availability_zones              = ["ap-northeast-1c", "ap-northeast-1a", "ap-northeast-1d"]
  database_name                   = var.DB_NAME
  master_username                 = "root"
  master_password                 = var.DB_PASSWORD
  backup_retention_period         = 2
  db_subnet_group_name            = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot             = true
  vpc_security_group_ids          = [aws_security_group.sql_sg.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db_parameter_group.name
}