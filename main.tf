locals {
  group_name  = "group1"
  environment = "PROD"
  project     = "DCADD_MASTER"
}

resource "aws_vpc" "master_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.group_name}-master-vpc"
    Environment = local.environment
    CreatedBy   = local.group_name
    Project     = local.project
    Description = "Main VPC for the group1 master project"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.master_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.master_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-b"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.master_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-c"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "${local.group_name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "${local.group_name}-private-b"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.13.0/24"
  availability_zone = "eu-central-1c"

  tags = {
    Name = "${local.group_name}-private-c"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.master_vpc.id

  tags = {
    Name = "${local.group_name}-master-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${local.group_name}-master-nat-eip"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${local.group_name}-master-natgw"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.master_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.group_name}-master-rt-public"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.master_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "${local.group_name}-master-rt-private"
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_c_assoc" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b_assoc" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_c_assoc" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "alb_sg" {
  name   = "${local.group_name}-alb-sg"
  vpc_id = aws_vpc.master_vpc.id

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
    Name = "${local.group_name}-alb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "${local.group_name}-ec2-sg"
  vpc_id = aws_vpc.master_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.group_name}-ec2-sg"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "${local.group_name}-master-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.master_vpc.id

  health_check {
    path              = "/"
    protocol          = "HTTP"
    healthy_threshold = 2
    interval          = 10
  }
}

resource "aws_lb" "alb" {
  name               = "${local.group_name}-master-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${local.group_name}-master-LT-"
  image_id      = "ami-092d44e3043413333"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.group_name}-ec2"
      Environment = local.environment
      CreatedBy   = local.group_name
      Project     = local.project
      Description = "Private EC2 instance for the static web app"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "${local.group_name}-master-asg"
  desired_capacity    = 3
  min_size            = 2
  max_size            = 6
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  target_group_arns = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "${local.group_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = local.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "CreatedBy"
    value               = local.group_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = local.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Description"
    value               = "Private EC2 instance behind ALB"
    propagate_at_launch = true
  }
}
