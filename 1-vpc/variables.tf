data "aws_availability_zones" "available" {}

locals {
  azs               = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_route_tables  = flatten([module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
  eks_cluster_name  = var.eks_cluster_name 
  
}

variable "eks_cluster_name" {
  type    = string
  default = "llmops-test"
}

variable "vpc_name" {
  type    = string
  default = "llmops-test-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "101.0.0.0/16"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment"
  default     = "dev"
}

variable "tags" {
  type    = map(string)
  default = {
    team  : "mlops",
    usage : "llmops-test",
    env   : "dev",
  }
}
