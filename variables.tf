variable "PREFIX" {
    default = "main-infra"
}

variable "DB_NAME" {
    default = "db"
}

variable "DB_PASSWORD" {
    default = "mypassword"
}

variable "vpc_cidr" {
    description = "CIDR for the VPC"
    default = "30.0.0.0/16"
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = ["30.0.0.0/24", "30.0.1.0/24", "30.0.2.0/24"]
}

variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "30.0.255.0/24"
}