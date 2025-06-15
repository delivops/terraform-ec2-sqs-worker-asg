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

resource "aws_iam_role_policy_attachment" "sqs_read" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
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
        Resource = "arn:aws:ssm:*:*:parameter${var.fluentbit_config_ssm_path}"
      }
    ]
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
