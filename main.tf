terraform {
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

# Security Group Creation 
resource "aws_security_group" "splunk_sg" {
  for_each = { for idx, instance in var.instances : idx => instance }

  name_prefix = "splunk-sg-${each.value.name}"

  dynamic "ingress" {
    for_each = each.value.security_group_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✅ Get Latest RHEL 9.x AMI
data "aws_ami" "latest_rhel" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat AWS account

  filter {
    name   = "name"
    values = ["RHEL-9.?*-x86_64-*"]
  }
}



# Splunk instances
resource "aws_instance" "splunk_server" {
  for_each = { for idx, instance in var.instances : idx => instance }

  provider = aws
  ami           = data.aws_ami.latest_rhel.id
  instance_type = each.value.instance_type
  key_name = each.value.key_name
  vpc_security_group_ids = [aws_security_group.splunk_sg[each.key].id]
  associate_public_ip_address = each.value.elastic_ip_needed

  root_block_device {
    volume_size = each.value.storage_size
  }

  user_data = file("scripts/splunk-setup.sh")

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file("${each.value.key_name}.pem")
      host = self.public_ip
    }

    inline = [
       "echo '${var.ssh_public_key}' >> ~/.ssh/authorized_keys"
    ]
  }

  tags = {
    Name = each.value.name
    AutoStop = true
  }
  
}

resource "time_sleep" "wait_10_seconds" {
  depends_on = [aws_instance.splunk_server, aws_eip.splunk_eip]
  create_duration = "10s"
}

resource "local_file" "ansible_inventory" {
  depends_on = [time_sleep.wait_10_seconds]
  filename   = "inventory.ini"
  
  content    = join("\n", flatten([
    "[ClusterManager]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "ClusterManager"],

    "[indexers]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "idx1"],
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "idx2"],
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "idx3"],

    "[SH1]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH1"],

    "[SH2]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH2"],

    "[SH3]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH3"],

    "[search_heads]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH1"],
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH2"],
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "SH3"],

    "[Deployment_Server]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "Deployment-Server"],

    "[Management_server]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "Management_server"],

    "[Deployer]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "Deployer"],

    "[IFs]",
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "IF1"],
    [for idx, instance in var.instances : "${instance.name} ansible_host=${lookup(aws_eip.splunk_eip, idx, { public_ip = aws_instance.splunk_server[idx].public_ip }).public_ip} instance_id=${aws_instance.splunk_server[idx].id} ansible_user=ec2-user" if instance.name == "IF2"],

    "[all_splunk:children]",
    "ClusterManager",
    "indexers",
    "search_heads",
    "Deployment_Server",
    "Deployer",
    "IFs",
  ]))
}



resource "local_file" "ansible_group_vars" {
  filename = "group_vars/all.yml"

  content = templatefile("${path.module}/group_vars_template.yml", {
    cluster_manager    = [for instance in aws_instance.splunk_server : { private_ip = instance.private_ip, instance_id = instance.id } if instance.tags["Name"] == "ClusterManager"]
    indexers          = { for instance in aws_instance.splunk_server : instance.tags["Name"] => { private_ip = instance.private_ip, instance_id = instance.id } if startswith(instance.tags["Name"], "idx") }
    search_heads      = { for instance in aws_instance.splunk_server : instance.tags["Name"] => { private_ip = instance.private_ip, instance_id = instance.id } if startswith(instance.tags["Name"], "SH") }
    deployment_server = [for instance in aws_instance.splunk_server : { private_ip = instance.private_ip, instance_id = instance.id } if instance.tags["Name"] == "Deployment-Server"]
    Management_server    = [for instance in aws_instance.splunk_server : { private_ip = instance.private_ip, instance_id = instance.id } if instance.tags["Name"] == "Management_server"]
    deployer          = [for instance in aws_instance.splunk_server : { private_ip = instance.private_ip, instance_id = instance.id } if instance.tags["Name"] == "Deployer"]
    ifs              = { for instance in aws_instance.splunk_server : instance.tags["Name"] => { private_ip = instance.private_ip, instance_id = instance.id } if startswith(instance.tags["Name"], "IF") }
    splunk_license_url = "${var.splunk_license_url}"
    splunk_admin_password = "admin123"
  })
}

# Elastic IPs (only if needed)
resource "aws_eip" "splunk_eip" {
  for_each = { for idx, instance in var.instances : idx => instance if instance.elastic_ip_needed }

  instance = aws_instance.splunk_server[each.key].id
  vpc = true
}


# ✌️Instance Stop timer for 3 hours



data "aws_caller_identity" "current" {}

# Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  name = "LambdaEC2StopperRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy" "lambda_policy" {
  name   = "LambdaEC2Policy"
  role   = aws_iam_role.lambda_role.id
  policy = file("iam_policies/lambda_role_policy.json")
}

# Archive Lambda Code
data "archive_file" "stop_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/stop_ec2.py"
  output_path = "${path.module}/lambda/stop_ec2.zip"
}

data "archive_file" "schedule_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/schedule_stop.py"
  output_path = "${path.module}/lambda/schedule_stop.zip"
}

# Stop Lambda
resource "aws_lambda_function" "stop_ec2" {
  function_name = var.stop_lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "stop_ec2.lambda_handler"
  runtime       = "python3.9"
  timeout       = var.lambda_timeout
  filename      = data.archive_file.stop_lambda.output_path

  depends_on = [
    aws_instance.splunk_server
  ]
}

# Schedule Lambda
resource "aws_lambda_function" "schedule_lambda" {
  function_name = var.schedule_lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "schedule_stop.lambda_handler"
  runtime       = "python3.9"
  timeout       = var.lambda_timeout
  filename      = data.archive_file.schedule_lambda.output_path

  environment {
    variables = {
      STOP_EC2_LAMBDA_ARN = aws_lambda_function.stop_ec2.arn
    }
  }

  depends_on = [
    aws_instance.splunk_server
  ]
}

# Event Rule: Trigger on EC2 Start
resource "aws_cloudwatch_event_rule" "ec2_start_rule" {
  name        = "TriggerLambdaOnEC2Start"
  description = "Trigger Schedule Lambda on EC2 start"
  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["EC2 Instance State-change Notification"],
    "detail": {
      "state": ["running"]
    }
  })
}

# CloudWatch Target → Schedule Lambda
resource "aws_cloudwatch_event_target" "trigger_lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_start_rule.name
  target_id = "TriggerScheduleLambda"
  arn       = aws_lambda_function.schedule_lambda.arn
}

# Permission for CloudWatch to trigger schedule_lambda
resource "aws_lambda_permission" "allow_eventbridge_schedule" {
  statement_id  = "AllowScheduleInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.schedule_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_start_rule.arn
}

# ✅ Permission for EventBridge to trigger stop_ec2 Lambda
resource "aws_lambda_permission" "allow_eventbridge_stop_lambda" {
  statement_id  = "stopec2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/Stop-*"
}
