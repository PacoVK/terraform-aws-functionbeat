data "aws_caller_identity" "account" {}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "vpc_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "FunctionBeat-${var.lambda_config.name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_execution_policy" {
  policy_arn = data.aws_iam_policy.vpc_execution_policy.arn
  role       = aws_iam_role.lambda_execution_role.id
}

resource "aws_lambda_permission" "allow_invoke_lambda_from_cloudwatch" {
  count          = var.loggroup_name != null ? 1 : 0
  statement_id   = "AllowTriggerFromCloudwatchLogGroup"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.functionbeat.function_name
  principal      = "logs.eu-central-1.amazonaws.com"
  source_account = data.aws_caller_identity.account.account_id
  source_arn     = format("arn:aws:logs:eu-central-1:%s:log-group:%s:*", data.aws_caller_identity.account.account_id, var.loggroup_name)
}

