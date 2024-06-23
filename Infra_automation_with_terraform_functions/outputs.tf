output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.customvpc.id
}

output "subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.customsub[*].id
}

output "instance_ids" {
  description = "The IDs of the EC2 instances"
  value       = aws_instance.custom_instances[*].id
}

output "instance_public_ips" {
  description = "The public IPs of the EC2 instances"
  value       = aws_instance.custom_instances[*].public_ip
}