resource "aws_ssm_parameter" "functionbeat_arn" {
  count       = var.lambda_write_arn_to_ssm ? 1 : 0
  name        = format("%s_arn", var.lambda_config.name)
  description = "ARN of the Functionbeat-Lambda shipping logs"
  type        = "String"
  value       = aws_lambda_function.functionbeat.arn
}
