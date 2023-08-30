data "external" "lambda_loader" {
  program = ["${path.module}/lambda_loader.sh"]

  query = {
    version          = var.functionbeat_version
    config_file      = local_file.functionbeat_config.filename
    enabled_function = var.lambda_config.name
  }
}

resource "local_file" "functionbeat_config" {
  content = templatefile("${path.module}/file/functionbeat.yml.tftpl", {
    enabled_function_name  = var.lambda_config.name
    application_name       = var.application_name
    output_elasticsearch   = var.lambda_config.output_elasticsearch
    output_logstash        = var.lambda_config.output_logstash
    fb_transaction_tags    = var.fb_extra_tags
    fb_extra_configuration = var.fb_extra_configuration
  })
  filename = "${path.module}/functionbeat.yml"
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
  source_code_hash = filebase64sha256(data.external.lambda_loader.result.filename)
  # unused by this runtime but still required
  handler          = "null.handler"
  role             = aws_iam_role.lambda_execution_role.arn
  runtime          = "provided.al2"
  architectures    = ["x86_64"]
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
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
