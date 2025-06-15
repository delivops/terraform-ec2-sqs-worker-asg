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
  name                 = "queue-worker"
  aws_region           = "eu-west-1"
  ami_id               = "ami-0123456789abcdef0"
  instance_type        = "g5.4xlarge"    # use a CPU instance type if GPUs aren't needed
  ecr_repo             = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/my-worker"
  sqs_queue_name       = "jobs-queue"
  image_tag            = "v1.2.3"
  worker_command       = "python worker.py"
  worker_env = {
    QUEUE_URL = "https://sqs.eu-west-1.amazonaws.com/123456789012/jobs-queue"
    LOG_LEVEL = "info"
  }
  worker_secret_ids = [
    "arn:aws:secretsmanager:eu-west-1:123456789012:secret:mysecret"
  ]
  # Optional: fetch Fluent Bit configuration from this SSM parameter
  fluentbit_config_ssm_path = "/logging/fluent-bit"
  enable_gpu          = true             # set only when workers need GPUs
  vpc_id               = "vpc-abc123"
  private_subnets_ids  = ["subnet-1", "subnet-2"]
  security_group_ids   = ["sg-1"]
  key_name             = "my-key"
  workers_per_instance = 5
  asg_max_size         = 10
  warm_pool_capacity   = 2
  additional_policies  = [
    jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::example-bucket"
      }]
    })
  ]
}
```

`worker_secret_ids` contains the Secrets Manager IDs whose JSON contents are
expanded into environment variables for the worker containers. The secrets are
parsed with Python at boot time so no additional tools like `jq` are required.

Scale out by running:

```sh
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw asg_name) \
  --desired-capacity <N> --honor-cooldown
```

The ASG will scale in automatically when the queue has been empty for the
configured period (default 15 minutes).

Set `enable_gpu` to `true` and choose a GPU instance type if the workload
requires GPU access. When `enable_gpu` is `false` (the default), the instances
run with the standard Docker runtime.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.workers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.scale_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_cloudwatch_metric_alarm.queue_empty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_instance_profile.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.cw_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecr_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sqs_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_policies"></a> [additional\_policies](#input\_additional\_policies) | List of additional IAM policy documents to attach to the worker role | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID with Docker and needed drivers installed | `string` | n/a | yes |
| <a name="input_asg_desired_capacity"></a> [asg\_desired\_capacity](#input\_asg\_desired\_capacity) | n/a | `number` | `0` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | n/a | `number` | `5` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | n/a | `number` | `0` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | n/a | `string` | n/a | yes |
| <a name="input_ecr_repo"></a> [ecr\_repo](#input\_ecr\_repo) | ECR repository URI | `string` | n/a | yes |
| <a name="input_enable_gpu"></a> [enable\_gpu](#input\_enable\_gpu) | Whether worker containers require GPU access | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_fluentbit_config_ssm_path"></a> [fluentbit\_config\_ssm\_path](#input\_fluentbit\_config\_ssm\_path) | SSM parameter name containing Fluent Bit configuration. When empty, Fluent Bit is not deployed | `string` | `""` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Tag of the container image to run | `string` | `"latest"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | n/a | `string` | `"t3.large"` | no |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | n/a | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the application or workload | `string` | n/a | yes |
| <a name="input_private_subnets_ids"></a> [private\_subnets\_ids](#input\_private\_subnets\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_queue_empty_minutes"></a> [queue\_empty\_minutes](#input\_queue\_empty\_minutes) | n/a | `number` | `15` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_sqs_queue_name"></a> [sqs\_queue\_name](#input\_sqs\_queue\_name) | n/a | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |
| <a name="input_warm_pool_capacity"></a> [warm\_pool\_capacity](#input\_warm\_pool\_capacity) | n/a | `number` | `0` | no |
| <a name="input_worker_command"></a> [worker\_command](#input\_worker\_command) | Optional command override for the worker container | `string` | `""` | no |
| <a name="input_worker_disk_size"></a> [worker\_disk\_size](#input\_worker\_disk\_size) | n/a | `number` | `50` | no |
| <a name="input_worker_env"></a> [worker\_env](#input\_worker\_env) | Environment variables for the worker container | `map(string)` | `{}` | no |
| <a name="input_worker_secret_ids"></a> [worker\_secret\_ids](#input\_worker\_secret\_ids) | List of Secrets Manager secret ARNs or names whose JSON values are converted to environment variables | `list(string)` | `[]` | no |
| <a name="input_workers_per_instance"></a> [workers\_per\_instance](#input\_workers\_per\_instance) | n/a | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | n/a |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | n/a |
<!-- END_TF_DOCS -->
