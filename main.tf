# Terraform configuration

###############################
# get the list of available AZ
###############################
locals {
  service_name = "forum"
  owner        = "Community Team"
  name         = "WORDPRESS"
}


data "aws_availability_zones" "available" {}


#################################################
# get the latests AMI (this is region specific)
# call with:
# ami                         = "${data.aws_ami.amazon-linux-2.id}"
#################################################


data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# data "aws_ami" "amazon-linux-2" {
#  most_recent      = true
#  owners           = ["amazon"]


#  filter {
#    name   = "owner-alias"
#    values = ["amazon"]
#  }


#  filter {
#    name   = "name"
#    values = ["ami-083ac7c7ecf9bb9b0"]
#  }
# }

###########################
# EC2 template with user data
###########################


data "template_file" "user_data" {
  template = <<EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
sudo yum install -y httpd mariadb-server
sudo systemctl start httpd
sudo systemctl enable httpd
sudo usermod -a -G apache ec2-user
sudo chown -R ec2-user:apache /var/www
sudo chmod 2775 /var/www
sudo find /var/www -type d -exec chmod 2775 {} \;
sudo find /var/www -type f -exec chmod 0664 {} \;
sudo echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
EOF
}



###########################
# deploy an IAM role 
###########################

resource "aws_iam_role" "wordpress_instance" {
  name = "wordpress-instance-iam-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


###########################################################
#  NAT for public subnet interaction with internet gateway
###########################################################

resource "aws_eip" "nat" {
  count = 3
  vpc = true 
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway

  tags = var.vpc_tags
}

################################################################################################
#  deploy (2) Security Groups:
# "ingress" to allow Internet to get to the http/https server 
# "load-balancer to instance" to allow ELB to forward traffic from the Internet to the instance
################################################################################################

module "wordpress-ingress-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "WORDPRESS-INGRESS"
  description = "Security group for web-server with HTTP ports open within VPC"
  #vpc_id      = "vpc-12345678"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["50.82.222.12/32"]
  #egress_rules = ["http-80-tcp"]
  computed_egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.wordpress-instance-sg.security_group_id
    },
  ]
}

module "wordpress-instance-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "WORDPRESS-INSTANCE"
  description = "Security group for web-server with HTTP ports open within VPC"
  #vpc_id      = "vpc-12345678"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.wordpress-ingress-sg.security_group_id
    }
  ]
}


################################################################################
# basic ASG with Launch Template
################################################################################


# module "asg" {
#   source  = "terraform-aws-modules/autoscaling/aws"
#   version = "~> 4.0"

#   # Autoscaling group
#   name = local.name

#   vpc_zone_identifier = module.vpc.private_subnets
#   min_size            = 1
#   max_size            = 1
#   desired_capacity    = 1

#   # Launch template
#   lt_name                = local.name
#   description            = "wordpress instance with user data"
#   update_default_version = true

#   image_id      = data.aws_ami.amazon-linux-2.id
#   instance_type = "t2.micro"
#   user_data = "${base64encode(data.template_file.user_data.rendered)}"
#   tags        = local.tags
#   tags_as_map = local.tags_as_map
# }