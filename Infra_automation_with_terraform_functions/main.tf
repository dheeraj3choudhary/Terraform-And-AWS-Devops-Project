# Create a VPC
resource "aws_vpc" "customvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "CustomVPC"
  }
}

# Create Public Subnets
resource "aws_subnet" "customsub" {
  count  = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.customvpc.id

  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = true

  tags = {
    Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
    Type = "Public"
  }
}

# Create EC2 instances in the public subnets
resource "aws_instance" "custom_instances" {
  count         = length(aws_subnet.customsub)
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = element(aws_subnet.customsub[*].id, count.index)

  tags = {
    Name = "ServerNo-${count.index}"
    Env  = "Dev"
  }
}
