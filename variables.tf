variable "environment" {
  type = string
}

variable "name" {
  type        = string
  description = "Name of the application or workload"
}

variable "aws_region" {
  type = string
}

variable "ami_id" {
  type        = string
  description = "AMI ID with Docker and needed drivers installed"
}

variable "instance_type" {
  type = string
  # t3.large works for generic CPU workloads; override for GPU instances
  default = "t3.large"
}

variable "ecr_repo" {
  type        = string
  description = "ECR repository URI"
}

variable "sqs_queue_name" {
  type = string
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag of the container image to run"
}

variable "worker_command" {
  type        = string
  default     = ""
  description = "Optional command override for the worker container"
}

variable "worker_env" {
  type        = map(string)
  default     = {}
  description = "Environment variables for the worker container"
}

variable "worker_secret_ids" {
  type        = list(string)
  default     = []
  description = "List of Secrets Manager secret ARNs or names whose JSON values are converted to environment variables"
}

variable "fluentbit_config_ssm_path" {
  type        = string
  default     = ""
  description = "SSM parameter name containing Fluent Bit configuration. When empty, Fluent Bit is not deployed"
}

variable "enable_gpu" {
  type        = bool
  default     = false
  description = "Whether worker containers require GPU access"
}

variable "vpc_id" {
  type = string
}

variable "private_subnets_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "workers_per_instance" {
  type    = number
  default = 1
}

variable "asg_min_size" {
  type    = number
  default = 0
}

variable "asg_max_size" {
  type    = number
  default = 5
}

variable "asg_desired_capacity" {
  type    = number
  default = 0
}

variable "warm_pool_capacity" {
  type    = number
  default = 0
}

variable "worker_disk_size" {
  type    = number
  default = 50
}

variable "queue_empty_minutes" {
  type    = number
  default = 15
}

variable "additional_policies" {
  type        = list(string)
  default     = []
  description = "List of additional IAM policy documents to attach to the worker role"
}
