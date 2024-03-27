# tflint-ignore: terraform_unused_declarations
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  description = "Exising VPC name"
  type        = string
  default     = "llmops-test-vpc"
}

variable "cluster_name" {
  description = "Name of cluster"
  type        = string
  default     = "llmops-test"
}

variable "cluster_region" {
  description = "Region to create the cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "The EKS version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "The instance type for EKS node"
  type        = string
  default     = "t3.xlarge"
}

variable "nvidia_gpu_node_instance_type" {
  description = "The NVIDIA instance type for EKS GPU node"
  type        = string
  default     = "g4dn.xlarge"
}

variable "amd_gpu_node_instance_type" {
  description = "The AMD instance type for EKS GPU node"
  type        = string
  default     = "g4ad.xlarge"
}

variable "node_group_min_size" {
  type    = number
  default = 1
}

variable "node_group_desired_size" {
  type    = number
  default = 1
}

variable "node_group_max_size" {
  type    = number
  default = 6
}

variable "enable_argo" {
  type    = bool
  default = false
}

variable "tags" {
  type = map(string)
  default = {
    team : "mlops",
    usage : "llmops-test",
    env : "dev",
  }
}