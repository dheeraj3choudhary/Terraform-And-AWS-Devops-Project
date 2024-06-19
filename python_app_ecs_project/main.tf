# Data source to get the current AWS account ID
data "aws_caller_identity" "current" {}

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

#----------------------Create Target Group--------------------------
resource "aws_lb_target_group" "CustomTG" {
  name        = "CustomTG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.CustomVPC.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
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

# Fetch subnet ids & Create a Load Balancer & ELB Listener
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
resource "aws_alb" "CustomELB" {
  name            = "CustomELB"
  depends_on      = [aws_subnet.PublicSubnet1, aws_subnet.PublicSubnet2]
  internal        = false
  security_groups = [aws_security_group.elb_sg.id]
  subnets         = data.aws_subnets.GetSubnet.ids
  tags = {
    Name = "CustomELB"
  }
}
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

# Set up CloudWatch group and log stream and retain logs for 30 days
resource "aws_cloudwatch_log_group" "cb_log_group" {
  name              = "/ecs/cb-app"
  retention_in_days = 30

  tags = {
    Name = "cb-log-group"
  }
}

resource "aws_cloudwatch_log_stream" "cb_log_stream" {
  name           = "cb-log-stream"
  log_group_name = aws_cloudwatch_log_group.cb_log_group.name
}

# Create an ECR repository
resource "aws_ecr_repository" "my_app" {
  name                 = "my-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Docker Build and Push to ECR
resource "null_resource" "docker_build_push" {
  depends_on = [aws_ecr_repository.my_app]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com
      docker build -t my-python-app .
      docker tag my-python-app:latest ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
      docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/my-app:latest
    EOT
  }
}

# Define an IAM role for ECS task execution "ecr:GetDownloadUrlForLayer",
resource "aws_iam_role" "custom-ecs-role" {
  name = "custom-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "ECRPermissions"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage"
          ],
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name = "CloudWatchLogsPermissions"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [{
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }]
    })
  }
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

# ECS Task security group
resource "aws_security_group" "ecs_task_sg" {
  name        = "ecs-task-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.CustomVPC.id
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
}

# Create an ECS service
resource "aws_ecs_service" "my_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.GetSubnet.ids
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.CustomTG.arn
    container_name   = "ECS_Container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

# Define the ECS task definition
resource "aws_ecs_task_definition" "my_task" {
  depends_on = [null_resource.docker_build_push]
  family     = "ECS_Task"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.custom-ecs-role.arn
  execution_role_arn       = aws_iam_role.custom-ecs-role.arn
  cpu                      = 1024
  memory                   = 2048

  container_definitions = jsonencode([{
    name  = "ECS_Container"
    image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-west-2.amazonaws.com/my-app:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    "logConfiguration" : {
      "logDriver" : "awslogs",
      "options" : {
        "awslogs-group" : "/ecs/cb-app",
        "awslogs-region" : "us-west-2",
        "awslogs-stream-prefix" : "ecs"
      }
    }
  }])
}


# Create an Application Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.my_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Create an Application Auto Scaling Policy for Scaling Out
resource "aws_appautoscaling_policy" "scale_out_policy" {
  name               = "scale-out"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# Create an Application Auto Scaling Policy for Scaling In
resource "aws_appautoscaling_policy" "scale_in_policy" {
  name               = "scale-in"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# CloudWatch Alarm for Scaling Out
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "ecs-scale-out-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "Alarm for scaling out ECS service"
  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_out_policy.arn]
}

# CloudWatch Alarm for Scaling In
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "ecs-scale-in-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "25"
  alarm_description   = "Alarm for scaling in ECS service"
  dimensions = {
    ClusterName = aws_ecs_cluster.my_cluster.name
    ServiceName = aws_ecs_service.my_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.scale_in_policy.arn]
}