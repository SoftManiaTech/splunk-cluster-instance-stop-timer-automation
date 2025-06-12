# Outputs (updated for multiple instances)
output "splunk_instance_names" {
  value = {
    for idx, instance in aws_instance.splunk_server : instance.tags["Name"] => instance.id
  }
}

output "splunk_public_ips" {
  value = { 
    for idx, instance in aws_instance.splunk_server :
    instance.tags["Name"] => (lookup(aws_eip.splunk_eip, idx, null) !=null ? aws_eip.splunk_eip[idx].public_ip : instance.public_ip)
  }
}

output "splunk_private_ips" {
  value = {
    for idx, instance in aws_instance.splunk_server : 
    instance.tags["Name"] => instance.private_ip
  }
}

output "instance_states" {
  value = {
    for idx, instance in aws_instance.splunk_server : 
    instance.tags["Name"] => instance.instance_state
  }
}

output "splunk_ssh_strings" {
  value = {
    for idx, instance in aws_instance.splunk_server :
    instance.tags["Name"] => "ssh -i ${var.instances[idx].key_name}.pem ec2-user@${lookup(aws_eip.splunk_eip, idx, { public_ip = instance.public_ip }).public_ip}"
  }
}
