locals {
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    environment_name          = var.environment,
    application_name          = replace(var.name, "-", "_"),
    asg_name                  = "${var.environment}-${var.name}-asg",
    region                    = var.aws_region,
    repo                      = var.ecr_repo,
    tag                       = var.image_tag,
    worker_command            = var.worker_command,
    worker_env                = var.worker_env,
    worker_secret_ids         = var.worker_secret_ids,
    workers_per_instance      = var.workers_per_instance,
    enable_gpu                = var.enable_gpu,
    fluentbit_config_ssm_path = var.fluentbit_config_ssm_path,
  })
}
