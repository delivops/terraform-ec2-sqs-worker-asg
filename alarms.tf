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
  policy_type            = "SimpleScaling"
  adjustment_type        = "ExactCapacity"
  scaling_adjustment     = var.asg_min_size
}
