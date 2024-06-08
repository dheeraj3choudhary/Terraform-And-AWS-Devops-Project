output "vpc_id" {
  value       = aws_vpc.CustomVPC.id
  description = "This is vpc id."
}
output "enable_dns_support" {
  value       = aws_vpc.CustomVPC.enable_dns_support
  description = "Check whether dns support is enabled for VPC."
}
output "enable_dns_hostnames" {
  value       = aws_vpc.CustomVPC.enable_dns_hostnames
  description = "Check whether dns hostname is enabled for VPC."
}
output "aws_internet_gateway_id" {
  value       = aws_internet_gateway.IGW.id
  description = "Internet gateway id."
}
output "igw_aws_account" {
  value       = aws_internet_gateway.IGW.owner_id
  description = "AWS Account id to which internet gateway is associated."
}
output "PublicSubnet1" {
  value       = aws_subnet.PublicSubnet1.id
  description = "This is first public subnet id."
}
output "PublicSubnet2" {
  value       = aws_subnet.PublicSubnet2.id
  description = "This is first second subnet id."
}
output "PublicRouteTable" {
  value       = aws_route_table.PublicRouteTable.id
  description = "List custom public route table id."
}
output "CustomTG" {
  value       = aws_lb_target_group.CustomTG.id
  description = "This is Target Group id."
}
output "CustomELB" {
  value       = aws_alb.CustomELB.id
  description = "This is load balancer ID."
}
output "elb_sg" {
  value       = aws_security_group.elb_sg.id
  description = "This is Security Group ID for load balancer."
}
output "asg_sg" {
  value       = aws_security_group.ec2_sg.id
  description = "This is Security Group ID for Ec2."
}
output "aws_launch_configuration" {
  value       = aws_launch_configuration.webteir_launch_config.id
  description = "This is ASG Launch Configuration ID."
}
output "autoscaling_group_dev" {
  value       = aws_autoscaling_group.autoscaling_group_webteir.id
  description = "This is ASG ID."
}
