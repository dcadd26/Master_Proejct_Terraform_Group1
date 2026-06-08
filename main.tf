# ==========================================
# LOCALS & NETWORKING (VPC & SUBNETS)
# ==========================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
}

locals {
  group_name  = "group1"
  environment = "Production"
  project     = "DCADD Master Project"
}

resource "aws_vpc" "master_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.group_name}-master-vpc"
  }
}

# Public Subnets (Për Load Balancer dhe NAT Gateway)
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-subnet-b"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.group_name}-public-subnet-c"
  }
}

# Private Subnets (Ku do të rrinë serverat EC2)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "${local.group_name}-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "${local.group_name}-private-subnet-b"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.master_vpc.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "eu-central-1c"

  tags = {
    Name = "${local.group_name}-private-subnet-c"
  }
}

# ==========================================
# GATEWAYS & ROUTE TABLES
# ==========================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.master_vpc.id

  tags = {
    Name = "${local.group_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${local.group_name}-nat-gateway"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.master_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.group_name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.master_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "${local.group_name}-private-route-table"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================
# SECURITY GROUPS
# ==========================================

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

# ==========================================
# LOAD BALANCER & TARGET GROUP
# ==========================================

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

# ==========================================
# LAUNCH TEMPLATE (AMAZON LINUX 2023)
# ==========================================

resource "aws_launch_template" "lt" {
  name_prefix   = "${local.group_name}-master-LT-"
  image_id      = data.aws_ami.amazon_linux_2023.id # Imazhi i saktë Linux për Frankfurt
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

# ==========================================
# AUTO SCALING GROUP
# ==========================================

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
