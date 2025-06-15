resource "aws_autoscaling_group" "workers" {
  name                = "${var.environment}-${var.name}-asg"
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
      instance_reuse_policy {
        reuse_on_scale_in = true
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
