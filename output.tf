output "functionbeat_arn" {
  value     = aws_lambda_function.functionbeat.arn
  sensitive = false
}

output "ssm_parameter_name" {
  value     = var.lambda_write_arn_to_ssm ? aws_ssm_parameter.functionbeat_arn[0].name : null
  sensitive = false
}
