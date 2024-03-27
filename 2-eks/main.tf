data "aws_availability_zones" "available" {}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

locals {
  cluster_name    = var.cluster_name
  region          = var.region
  cluster_version = var.cluster_version

  vpc_name = var.vpc_name
  vpc_id   = data.aws_vpc.vpc.id
  vpc_cidr = data.aws_vpc.vpc.cidr_block
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = var.tags
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["${local.vpc_name}-private-us-east-1a", "${local.vpc_name}-private-us-east-1b", "${local.vpc_name}-private-us-east-1c"]
  }
}


################################################################################
# Cluster
################################################################################

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = ">= 5.33"

  role_name_prefix = "${local.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  enable_cluster_creator_admin_permissions = true

  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  vpc_id     = local.vpc_id
  subnet_ids = toset(data.aws_subnets.private.ids)

  eks_managed_node_groups = {
    platfrom-ng = {
      name                           = "${local.cluster_name}-managed"
      iam_role_name                  = "${local.cluster_name}-managed"
      ami_type                       = "AL2_x86_64"
      use_latest_ami_release_version = true
      instance_types                 = [var.node_instance_type]
      disk_size                      = 50
      min_size                       = var.node_group_min_size
      desired_size                   = var.node_group_desired_size
      max_size                       = var.node_group_max_size
      labels = {
        ng_group = "${local.cluster_name}-platform"
      }
    },
     platfrom-nvidia-gpu-ng = {
       name                           = "${local.cluster_name}-nvidia-gpu-managed"
       iam_role_name                  = "${local.cluster_name}-nvidia-gpu-managed"
       #ami_id                         = "ami-031e889e75cb38be6"
       ami_type                       = "AL2_x86_64_GPU"
       use_latest_ami_release_version = true
       instance_types                 = [var.nvidia_gpu_node_instance_type]
       disk_size                      = 100
       block_device_mappings = {
         xvda = {
           device_name = "/dev/xvda"
           ebs = {
             volume_size           = 75
             volume_type           = "gp3"
             iops                  = 3000
             throughput            = 150
             encrypted             = true
             delete_on_termination = true
           }
         }
       }
       min_size                       = var.node_group_min_size
       desired_size                   = var.node_group_desired_size
       max_size                       = var.node_group_max_size
       labels = {
         ng_group = "${local.cluster_name}-nvidia-gpu-platform"
       }
       taints = {
         dedicated = {
           key    = "nvidia.com/gpu"
           value  = "true"
           effect = "NO_SCHEDULE"
         }
       }
     }
    # platfrom-amd-gpu-ng = {
    #   name                           = "${local.cluster_name}-amd-gpu-managed"
    #   iam_role_name                  = "${local.cluster_name}-amd-gpu-managed"
    #   #ami_id                         = "ami-031e889e75cb38be6"
    #   ami_type                       = "AL2_x86_64_GPU"
    #   use_latest_ami_release_version = true
    #   instance_types                 = [var.amd_gpu_node_instance_type]
    #   disk_size                      = 100
    #   block_device_mappings = {
    #     xvda = {
    #       device_name = "/dev/xvda"
    #       ebs = {
    #         volume_size           = 75
    #         volume_type           = "gp3"
    #         iops                  = 3000
    #         throughput            = 150
    #         encrypted             = true
    #         delete_on_termination = true
    #       }
    #     }
    #   }      
    #   min_size                       = var.node_group_min_size
    #   desired_size                   = var.node_group_desired_size
    #   max_size                       = var.node_group_max_size
    #   labels = {
    #     ng_group = "${local.cluster_name}-amd-gpu-platform"
    #   }
    #   taints = {
    #     dedicated = {
    #       key    = "amd.com/gpu"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #   }
    # }    
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = var.tags
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = ">= 1.12.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  # Add-ons
  enable_metrics_server               = true
  enable_vpa                          = true
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  cluster_autoscaler = {
    name = "${local.cluster_name}-cluster-autoscaler"
  }

  enable_argocd = var.enable_argo
  argocd = {
    name          = "argocd"
    chart_version = "5.51.6"
    repository    = "https://argoproj.github.io/argo-helm"
    namespace     = "argocd"
  }

  enable_argo_rollouts              = var.enable_argo
  enable_argo_workflows             = var.enable_argo
  enable_aws_gateway_api_controller = false

  # Pass in any number of Helm charts to be created for those that are not natively supported
  # helm_releases = {
  #   gpu-operator = {
  #     description      = "A Helm chart for NVIDIA GPU operator"
  #     namespace        = "gpu-operator"
  #     create_namespace = true
  #     chart            = "gpu-operator"
  #     chart_version    = "v23.9.0"
  #     repository       = "https://nvidia.github.io/gpu-operator"
  #     values = [
  #       <<-EOT
  #         operator:
  #           defaultRuntime: containerd
  #           toolkit.version: v1.14.5-centos7
  #       EOT
  #     ]
  #   }
  # }

  tags = var.tags
}