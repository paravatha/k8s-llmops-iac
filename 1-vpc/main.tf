module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.4.0"

  azs                                             = local.azs
  cidr                                            = var.vpc_cidr
  name                                            = var.vpc_name
  
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  create_database_subnet_group	                  = false
  
  enable_dhcp_options                             = true
  enable_dns_hostnames                            = true
  enable_dns_support                              = true
  
  enable_flow_log                                 = true
  flow_log_cloudwatch_log_group_retention_in_days = 7
  flow_log_max_aggregation_interval               = 60
  
  enable_nat_gateway                              = true
  single_nat_gateway                              = true
  one_nat_gateway_per_az                          = false

  private_subnets                                 = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets                                  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]  

  private_subnet_suffix                           = "private"
  public_subnet_suffix                            = "public"

  private_subnet_tags                             = { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared", "kubernetes.io/role/internal-elb" = 1 }
  public_subnet_tags                              = { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared", "kubernetes.io/role/elb" = 1 }

  tags                                            = var.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = ">= 5.4.0"


  vpc_id = module.vpc.vpc_id
  tags   = var.tags

  endpoints = {
    s3 = {
      route_table_ids = local.vpc_route_tables
      service         = "s3"
      service_type    = "Gateway"
      tags            = { Name = "${var.vpc_name}-s3-vpc-endpoint" }
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoint.id]
      tags                = { Name = "${var.vpc_name}-ec2-vpc-endpoint" }
    }
  }
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.vpc_name}-vpc-endpoint"
  description = "VPC endpoint security group allowing traffic for VPC CIDR"
  vpc_id      = module.vpc.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "vpc_endpoint_egress" {
  from_port         = 0
  protocol          = -1
  security_group_id = aws_security_group.vpc_endpoint.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "vpc_endpoint_ingress" {
  from_port         = 0
  protocol          = -1
  security_group_id = aws_security_group.vpc_endpoint.id
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = [var.vpc_cidr]
}
