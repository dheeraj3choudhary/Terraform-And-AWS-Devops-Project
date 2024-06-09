#---------------------Create Custom VPC----------------------
resource "aws_vpc" "CustomVPC" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "CustomVPC"
  }
}
#---------------------Create IGW And associate with VPC----------------------
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.CustomVPC.id

  tags = {
    Name = "IGW"
  }
}
#---------------------Create 2 Public Subnets----------------------
resource "aws_subnet" "PublicSubnet1" {
  vpc_id                  = aws_vpc.CustomVPC.id
  cidr_block              = "10.0.0.0/18"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet1"
    Type = "Public"
  }
}
resource "aws_subnet" "PublicSubnet2" {
  vpc_id                  = aws_vpc.CustomVPC.id
  cidr_block              = "10.0.64.0/18"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet2"
    Type = "Public"
  }
}
#---------------------Create Custom Public route table----------------------
resource "aws_route_table" "PublicRouteTable" {
  vpc_id = aws_vpc.CustomVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}
#---------------------Create route table association with public route table----------------------
resource "aws_route_table_association" "PublicSubnetRouteTableAssociation1" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.PublicRouteTable.id
}

resource "aws_route_table_association" "PublicSubnetRouteTableAssociation2" {
  subnet_id      = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.PublicRouteTable.id
}
#---------------------Create Target Group----------------------
resource "aws_lb_target_group" "CustomTG" {
  name        = "CustomTG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.CustomVPC.id
  target_type = "instance"
  health_check {
    interval            = 30     # Time between health checks in seconds
    path                = "/"    # The destination path for the health check
    protocol            = "HTTP" # Protocol to use for the health check
    timeout             = 5      # Time to wait for a health check response
    healthy_threshold   = 2      # Number of consecutive successes for a healthy state
    unhealthy_threshold = 2      # Number of consecutive failures for an unhealthy state
  }
}
#---------------------Create Security Group For Load Balancer----------------------
resource "aws_security_group" "elb_sg" {
  name        = "allow_http_elb"
  description = "Allow http inbound traffic for elb"
  vpc_id      = aws_vpc.CustomVPC.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "terraform-elb-security-group"
  }
}
#-------------------------Fetch Public Subnets List---------------------------------
data "aws_subnets" "GetSubnet" {
  depends_on = [aws_subnet.PublicSubnet1, aws_subnet.PublicSubnet2]
  filter {
    name   = "vpc-id"
    values = [aws_vpc.CustomVPC.id]
  }
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}
#---------------------Create Load Balancer----------------------
resource "aws_alb" "CustomELB" {
  name            = "CustomELB"
  depends_on      = [aws_subnet.PublicSubnet1, aws_subnet.PublicSubnet2]
  security_groups = [aws_security_group.elb_sg.id]
  subnets         = data.aws_subnets.GetSubnet.ids
  tags = {
    Name = "CustomELB"
  }
}
#---------------------Create Load Balancer Listener----------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.CustomELB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.CustomTG.arn
      }
      stickiness {
        enabled  = true
        duration = 28800
      }
    }
  }
}

#---------------------Create Security Group For EC2----------------------
resource "aws_security_group" "ec2_sg" {
  name        = "allow_http_ec2"
  description = "Allow http inbound traffic for elb"
  vpc_id      = aws_vpc.CustomVPC.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb_sg.id}"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "terraform-elb-security-group"
  }
}

# # Create IAM Role and Policy for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ssm_role_policy_attachment" {
  name       = "attach_ssm_policy"
  roles      = [aws_iam_role.ec2_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}


#---------------------Create ASG Launch Configuration----------------------
resource "aws_launch_configuration" "webteir_launch_config" {
  name_prefix                 = "webteir"
  image_id                    = data.aws_ami.latest_amazon_linux.id
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  associate_public_ip_address = true
  user_data                   = file("userdata.sh")
  lifecycle {
    create_before_destroy = true
  }
}

#---------------------Create Autoscaling Group----------------------
resource "aws_autoscaling_group" "autoscaling_group_webteir" {
  depends_on           = [aws_subnet.PublicSubnet1, aws_subnet.PublicSubnet2]
  launch_configuration = aws_launch_configuration.webteir_launch_config.id
  min_size             = var.autoscaling_group_min_size
  max_size             = var.autoscaling_group_max_size
  target_group_arns    = ["${aws_lb_target_group.CustomTG.arn}"]
  vpc_zone_identifier  = data.aws_subnets.GetSubnet.ids

  tag {
    key                 = "Name"
    value               = "autoscaling-group-webteir"
    propagate_at_launch = true
  }
}
