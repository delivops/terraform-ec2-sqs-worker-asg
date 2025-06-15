locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    region                    = var.aws_region,
    repo                      = var.ecr_repo,
    tag                       = var.image_tag,
    worker_command            = var.worker_command,
    worker_env                = var.worker_env,
    worker_secret_ids         = var.worker_secret_ids,
    workers_per_instance      = var.workers_per_instance,
    enable_gpu                = var.enable_gpu,
    fluentbit_config_ssm_path = var.fluentbit_config_ssm_path,
    name                      = var.name,
    environment               = var.environment,
  })
}
