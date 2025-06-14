# Terraform module to deploy an Auto Scaling group of EC2 workers
# that run Docker Compose workloads pulled from ECR and consume an SQS queue.
# The group scales in when the queue is empty for a period of time. Scale-out
# can be performed manually by adjusting the desired capacity.

########################
# 1. IAM role & profile
########################

resource "aws_iam_role" "worker" {
  name = "${var.environment}-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "sqs_read" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.environment}-worker-profile"
  role = aws_iam_role.worker.name
}

########################################
# 2. User-data template
########################################

locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    region               = var.aws_region,
    repo                 = var.ecr_repo,
    tag                  = var.image_tag,
    worker_command       = var.worker_command,
    worker_env           = var.worker_env,
    worker_secret_ids    = var.worker_secret_ids,
    workers_per_instance = var.workers_per_instance
  })
}

########################################
# 3. Launch template
########################################

resource "aws_launch_template" "worker" {
  name_prefix   = "${var.environment}-worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = base64encode(local.user_data)

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = aws_iam_instance_profile.worker.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.worker_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Environment = var.environment
      Application = "queue-worker"
    }
  }
}

########################################
# 4. Auto Scaling Group + warm pool
########################################

resource "aws_autoscaling_group" "workers" {
  name                = "${var.environment}-worker-asg"
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = var.private_subnets_ids
  health_check_type   = "EC2"
  default_cooldown    = 900

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  dynamic "warm_pool" {
    for_each = var.warm_pool_capacity > 0 ? [1] : []
    content {
      max_group_prepared_capacity = var.warm_pool_capacity
      reuse_on_scale_in           = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

########################################
# 5. CloudWatch alarm & scale-in policy
########################################

resource "aws_cloudwatch_metric_alarm" "queue_empty" {
  alarm_name          = "${var.environment}-queue-empty-${var.queue_empty_minutes}m"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = var.queue_empty_minutes
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  dimensions          = { QueueName = var.sqs_queue_name }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.environment}-asg-scale-in"
  autoscaling_group_name = aws_autoscaling_group.workers.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 900

  step_adjustment {
    metric_interval_lower_bound = 0
    adjustment                  = -1
  }
}

########################################
# 6. Outputs
########################################

output "asg_name" {
  value = aws_autoscaling_group.workers.name
}

output "launch_template_id" {
  value = aws_launch_template.worker.id
}
