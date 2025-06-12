
variable "region" {
    type = string
    description = "mention your region. if you change region must change ami name & key-pair"
}

variable "splunk_license_url" {
  type    = string
}

# List of instance configurations
variable "instances" {
  type = list(object({

    name = string
    region            = string
    instance_type     = string
    storage_size      = number
    key_name          = string
    elastic_ip_needed = bool
    security_group_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))

  }))
  description = "List of Splunk instances with individual configurations."
}

variable "ssh_public_key" {
  description = "SSH public key for authentication"
  type        = string
}


variable "aws_secret_key" {
  type        = string
}

variable "aws_access_key" {
  type        = string
}

# ✌️Instance stop timer variable

variable "stop_lambda_name" {
  description = "Name of the stop EC2 Lambda function"
  type        = string
  default     = "stop-ec2-instances"
}

variable "schedule_lambda_name" {
  description = "Name of the schedule Lambda function"
  type        = string
  default     = "schedule-ec2-stop"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30
}