# Define your region
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-west-2"
}

# Data source to get available AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

#-------------------------Fetch AMI ID---------------------
data "aws_ami" "latest_amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Data source to get the current AWS account ID
data "aws_caller_identity" "current" {}
