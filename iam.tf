data "aws_caller_identity" "current" {}

resource "aws_iam_role" "worker" {
  name = "${var.environment}-${var.name}-role"
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

resource "aws_iam_role_policy" "sqs" {
  name  = "${var.environment}-${var.name}-sqs"
  role  = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = "arn:aws:sqs:*:*:${var.sqs_queue_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Add CloudWatch Logs permissions for Fluent Bit
resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = var.fluentbit_config_ssm_path != "" ? 1 : 0
  name  = "${var.environment}-${var.name}-cloudwatch-logs"
  role  = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/${var.fluentbit_config_ssm_path}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "secrets" {
  count = length(var.worker_secret_ids) > 0 ? 1 : 0
  name  = "${var.environment}-${var.name}-secrets"
  role  = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        for sid in var.worker_secret_ids : "${sid}"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "lifecycle" {
  name = "${var.environment}-${var.name}-lifecycle"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["autoscaling:CompleteLifecycleAction"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.environment}-${var.name}-profile"
  role = aws_iam_role.worker.name
}

resource "aws_iam_role_policy" "additional" {
  for_each = { for idx, policy in var.additional_policies : idx => policy }
  name     = "${var.environment}-${var.name}-additional-${each.key}"
  role     = aws_iam_role.worker.id
  policy   = each.value
}
