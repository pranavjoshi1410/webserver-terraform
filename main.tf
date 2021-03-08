provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "terra_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "TerraVPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "terra_igw" {
  vpc_id = aws_vpc.terra_vpc.id
  tags = {
    Name = "terra_igw"
  }
}

# Subnets : public
resource "aws_subnet" "public" {
  count             = length(var.public_subnets_cidr)
  vpc_id            = aws_vpc.terra_vpc.id
  cidr_block        = element(var.public_subnets_cidr, count.index)
  map_public_ip_on_launch = true
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "Public-Subnet-${count.index + 1}"
  }
}

# Subnets : private
resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.terra_vpc.id
  cidr_block        = element(var.private_subnets_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "Private-Subnet-${count.index + 1}"
  }
}

# Route table: attach Internet Gateway  to Public RT
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.terra_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra_igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

# Route table association with public subnets
resource "aws_route_table_association" "Public-RT-Association" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

## Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.terra_igw]
}
resource "aws_eip" "nat_eip2" {
  vpc        = true
  depends_on = [aws_internet_gateway.terra_igw]
}


## NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public.*.id, 0)
  depends_on    = [aws_internet_gateway.terra_igw]
  tags = {
    Name        = "nat"
  }
}
resource "aws_nat_gateway" "nat2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = element(aws_subnet.public.*.id, 1)
  depends_on    = [aws_internet_gateway.terra_igw]
  tags = {
    Name        = "nat2"
  }
}
## Routing table for private subnet 
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.terra_vpc.id
  tags = {
    Name = "private_rt"
  }
}
resource "aws_route_table" "private_rt2" {
  vpc_id = aws_vpc.terra_vpc.id
  tags = {
    Name = "private_rt2"
  }
}
## Route for Private subnet
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
resource "aws_route" "private_nat_gateway2" {
  route_table_id         = aws_route_table.private_rt2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat2.id
}


## Route Table Association for Private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = element(aws_subnet.private.*.id, 0)
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private2" {
  subnet_id      = element(aws_subnet.private.*.id, 1)
  route_table_id = aws_route_table.private_rt2.id
}

#Get Ubuntu Latest AMI ID
data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
    owners = ["099720109477"] # Canonical
}

#Security Group For ALB and Webserver
resource "aws_security_group" "webserver_sg" {
  name = "webserver_sg"
  description = "webserver security group"
  vpc_id = aws_vpc.terra_vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Security Group For EFS
resource "aws_security_group" "efs_sg" {
  name = "efs_sg"
  description = "efs security group"
  vpc_id = aws_vpc.terra_vpc.id

  // EFS
   ingress {
     security_groups = ["${aws_security_group.webserver_sg.id}"]
     from_port = 2049
     to_port = 2049
     protocol = "tcp"
   }
  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#get all public subnet ids. This will be used in ALB
data "aws_subnet_ids" "all" {
  depends_on = [ aws_subnet.public ]
  vpc_id = aws_vpc.terra_vpc.id
  filter {
    name   = "tag:Name"
    values = ["Public-Subnet-*"] # insert values here
  }
}

#get all private subnet ids. This will be used in ASG
data "aws_subnet_ids" "all_private" {
  depends_on = [ aws_subnet.private ]
  vpc_id = aws_vpc.terra_vpc.id
  filter {
    name   = "tag:Name"
    values = ["Private-Subnet-*"] # insert values here
  }
}


#ALB and TG Creation
resource "aws_alb" "alb" {
  name            = "alb"
  internal        = false
  idle_timeout    = "300"
  security_groups = ["${aws_security_group.webserver_sg.id}"]
  subnets = data.aws_subnet_ids.all.ids
  enable_deletion_protection = false
}

# Define a listener
resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb-tg.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "alb-tg" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terra_vpc.id
}
##EFS for Webroot
resource "aws_efs_file_system" "efs-webserver" {
   creation_token = "efs-webserver"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "efs-webserver"
   }
 }

 resource "aws_efs_mount_target" "efs-mt-webserver" {
   count = length(aws_subnet.private.*.id)
   file_system_id  = aws_efs_file_system.efs-webserver.id
   subnet_id = element(aws_subnet.private.*.id, count.index)
   security_groups = ["${aws_security_group.efs_sg.id}"]
 }

 ##EFS for Logs
resource "aws_efs_file_system" "efs-logs" {
   creation_token = "efs-logs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "efs-logs"
   }
 }

 resource "aws_efs_mount_target" "efs-mt-logs" {
   count = length(aws_subnet.private.*.id)
   file_system_id  = aws_efs_file_system.efs-logs.id
   subnet_id = element(aws_subnet.private.*.id, count.index)
   security_groups = ["${aws_security_group.efs_sg.id}"]
 }

## User data script to install webserver and mount EFS
data "template_file" "userdata_script" {
template = file("./userdata.sh")
vars = {
efs_name = aws_efs_file_system.efs-webserver.dns_name
efs_logs_name = aws_efs_file_system.efs-logs.dns_name
}
}

## Creating Launch Configuration
resource "aws_launch_configuration" "launch_config" {
  image_id               = data.aws_ami.ubuntu.id
  #key_name = "pranav"
  instance_type          = var.instance_type
  security_groups        = ["${aws_security_group.webserver_sg.id}"]
  user_data = data.template_file.userdata_script.rendered
  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp2"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}
## Creating AutoScaling Group
resource "aws_autoscaling_group" "ASG" {
  name                      = "ASG"
  depends_on                = [aws_launch_configuration.launch_config]
  vpc_zone_identifier       = data.aws_subnet_ids.all_private.ids
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch_config.id
  target_group_arns         = [aws_alb_target_group.alb-tg.arn]

  tag {
    key                 = "Name"
    value               = "ASG-WebServers"
    propagate_at_launch = true
  }
}

## Target Tracking Policy
resource "aws_autoscaling_policy" "ASG_target_tracking_policy" {
name = "webserver-target-tracking-policy"
policy_type = "TargetTrackingScaling"
autoscaling_group_name = aws_autoscaling_group.ASG.name
estimated_instance_warmup = 200

target_tracking_configuration {
predefined_metric_specification {
predefined_metric_type = "ASGAverageCPUUtilization"
}

    target_value = "50"

}
}