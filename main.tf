locals {
  functionbeat_cache_dir = var.functionbeat_cache_dir != null ? var.functionbeat_cache_dir : "${path.root}/.terraform/functionbeat"
}

data "external" "lambda_loader" {
  program = ["${path.module}/lambda_loader.sh"]

  query = {
    version          = var.functionbeat_version
    cache_dir        = "${local.functionbeat_cache_dir}/${terraform.workspace}"
    enabled_function = var.lambda_config.name
    architecture     = var.lambda_architecture
    functionbeat_yml = base64encode(templatefile("${path.module}/file/functionbeat.yml.tftpl", {
      enabled_function_name  = var.lambda_config.name
      application_name       = var.application_name
      output_elasticsearch   = var.lambda_config.output_elasticsearch
      output_logstash        = var.lambda_config.output_logstash
      fb_transaction_tags    = var.fb_extra_tags
      fb_extra_configuration = var.fb_extra_configuration
      fb_log_level           = var.fb_log_level
    }))
  }
}

resource "aws_cloudwatch_log_group" "functionbeat_logs" {
  name              = "/aws/lambda/${var.lambda_config.name}"
  retention_in_days = 1
  tags              = var.tags
}

resource "aws_lambda_function" "functionbeat" {
  function_name    = var.lambda_config.name
  description      = var.lambda_description
  filename         = data.external.lambda_loader.result.filename
  source_code_hash = data.external.lambda_loader.result.filehash
  # unused by this runtime but still required
  handler       = "null.handler"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = var.lambda_runtime
  architectures = [var.lambda_architecture]
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  vpc_config {
    security_group_ids = var.lambda_config.vpc_config.security_group_ids
    subnet_ids         = var.lambda_config.vpc_config.subnet_ids
  }
  reserved_concurrent_executions = var.lambda_reserved_concurrent_execution
  environment {
    variables = {
      BEAT_STRICT_PERMS = "false"
      ENABLED_FUNCTIONS = var.lambda_config.name
      LOG_LEVEL         = var.fb_log_level
    }
  }

  tags = var.tags

  depends_on = [
    data.external.lambda_loader,
    aws_cloudwatch_log_group.functionbeat_logs
  ]
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_subscription" {
  count           = var.loggroup_name != null ? 1 : 0
  name            = "CloudwatchSubscriber-${var.lambda_config.name}"
  destination_arn = aws_lambda_function.functionbeat.arn
  filter_pattern  = var.loggroup_filter_pattern
  log_group_name  = var.loggroup_name

  depends_on = [
    aws_lambda_permission.allow_invoke_lambda_from_cloudwatch
  ]
}
