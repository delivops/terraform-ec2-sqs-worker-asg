# EC2 SQS Worker ASG Module

This module provisions an Auto Scaling group of EC2 instances that run a
Docker Compose workload pulled from ECR and reading tasks from an SQS queue.
Instances can be manually scaled out by adjusting the desired capacity of the
ASG. When the queue is empty for a configurable number of minutes, the group
scales in automatically.

## Usage

```hcl
module "workers" {
  source  = "./"

  environment          = "prod"
  aws_region           = "eu-west-1"
  ami_id               = "ami-0123456789abcdef0"
  instance_type        = "g5.4xlarge"
  ecr_repo             = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-worker"
  sqs_queue_name       = "jobs-queue"
  image_tag            = "v1.2.3"
  worker_command       = "python worker.py"
  worker_env = {
    QUEUE_URL = "https://sqs.eu-west-1.amazonaws.com/123456789012/jobs-queue"
    LOG_LEVEL = "info"
  }
  vpc_id               = "vpc-abc123"
  private_subnets_ids  = ["subnet-1", "subnet-2"]
  security_group_ids   = ["sg-1"]
  key_name             = "my-key"
  workers_per_instance = 5
  asg_max_size         = 10
  warm_pool_capacity   = 2
}
```

Scale out by running:

```sh
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw asg_name) \
  --desired-capacity <N> --honor-cooldown
```

The ASG will scale in automatically when the queue has been empty for the
configured period (default 15 minutes).
