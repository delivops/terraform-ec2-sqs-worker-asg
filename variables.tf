variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ami_id" {
  type        = string
  description = "AMI ID with Docker and needed drivers installed"
}

variable "instance_type" {
  type    = string
  default = "g5.4xlarge"
}

variable "ecr_repo" {
  type        = string
  description = "ECR repository URI"
}

variable "sqs_queue_name" {
  type = string
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
