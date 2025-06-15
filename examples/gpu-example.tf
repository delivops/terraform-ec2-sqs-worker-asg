# Variables for GPU example
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ecr_repo" {
  description = "ECR repository URI"
  type        = string
}

variable "sqs_queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

variable "fluentbit_config_ssm_path" {
  description = "SSM parameter path for Fluent Bit config"
  type        = string
  default     = ""
}

variable "enable_gpu" {
  description = "Enable GPU support"
  type        = bool
  default     = false
}

variable "workers_per_instance" {
  description = "Number of workers per instance"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 1
}

module "simple-worker-asg" {
  source         = "../"
  environment    = var.environment
  aws_region     = var.aws_region
  ami_id         = var.ami_id
  instance_type  = var.instance_type
  ecr_repo       = var.ecr_repo
  sqs_queue_name = var.sqs_queue_name
  image_tag      = var.image_tag
  worker_env = {
    STAGE = var.environment
  }
  enable_gpu                = var.enable_gpu
  fluentbit_config_ssm_path = var.fluentbit_config_ssm_path
  vpc_id                    = var.vpc_id
  private_subnets_ids       = var.private_subnets_ids
  security_group_ids        = var.security_group_ids
  key_name                  = var.key_name
  workers_per_instance      = var.workers_per_instance
  asg_max_size              = var.asg_max_size
  asg_min_size              = var.asg_min_size
  asg_desired_capacity      = var.asg_desired_capacity
}
