# ================================== Required =====================================

variable "application_name" {
  description = "This value is added to any log in Kibana as a tag for filtering"
  type        = string
}

variable "functionbeat_version" {
  description = "Funtionbeat version to deploy"
  type        = string
  validation {
    condition     = tonumber(split(".", var.functionbeat_version)[0]) >= 8 && tonumber(split(".", var.functionbeat_version)[1]) >= 12 && tonumber(split(".", var.functionbeat_version)[2]) >= 1
    error_message = "The functionbeat_version must be at least '8.12.1' to be able to use the provided.al2 aws lambda runtime."
  }
}

variable "lambda_config" {
  description = "Minimal required configuration for Functionbeat lambda"
  type = object({
    name = string
    vpc_config = object({
      vpc_id             = string
      subnet_ids         = list(string)
      security_group_ids = list(string)
    })
    output_elasticsearch = optional(any)
    output_logstash      = optional(any)
  })
}

# ================================= Extra Lambda ==================================

variable "lambda_reserved_concurrent_execution" {
  description = "ReservedConcurrentExecutions for the Lambda"
  type        = number
  default     = 5
}

variable "lambda_memory_size" {
  description = "Memory limit for the Lambda"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda"
  type        = number
  default     = 3
}

variable "lambda_description" {
  description = "Description added to the Lambda"
  type        = string
  default     = "Lambda function to ship cloudwatch logs to Kibana"
}

variable "lambda_write_arn_to_ssm" {
  description = "Will write the actual Functionbeat Lambda ARN to SSM"
  type        = bool
  default     = true
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function. Default is 'provided.al2023' which is required for Functionbeat version 8.12.1 and above."
  type        = string
  default     = "provided.al2023"
}

variable "lambda_architecture" {
  description = "Architecture for the Lambda function. Default is 'x86_64' other runtimes are not tested"
  type        = string
  default     = "x86_64"
}

variable "functionbeat_cache_dir" {
  description = "Directory used to cache the Functionbeat archive and store generated config files. Defaults to .terraform/functionbeat under the root module."
  type        = string
  default     = null
}

# ============================== Extra Functionbeat ===============================

variable "fb_extra_configuration" {
  description = "All valid Functionbeat configuration passed as valid HCL object. For configuration options head over to Functionbeat documentation."
  type        = any
  default     = {}
}

variable "fb_extra_tags" {
  description = "The tags of the shipper are included in their own field with each transaction published"
  type        = list(string)
  default     = []
}

variable "fb_log_level" {
  description = "Loglevel for Lambda"
  type        = string
  default     = "info"
}

# ================================ Extra Terraform ================================

variable "loggroup_name" {
  description = "Name of the Cloudwatch log group to be added as trigger for the function"
  type        = string
  default     = null
}

variable "loggroup_filter_pattern" {
  description = "Filter on the Cloudwatch log group to trigger the function only in case of matches"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to add to the actual AWS resources"
  type        = map(any)
  default     = {}
}
