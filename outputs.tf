# Output variable definitions

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}


output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}


output "vpc_private_subnets" {
  description = "IDs of the VPC's private subnets"
  value       = module.vpc.private_subnets
}

output "wordpress_ingress_sg_id" {
  description = "The ID of the security group"
  value       = module.wordpress-ingress-sg.security_group_id
}

output "wordpress_instance_sg_id" {
  description = "The ID of the security group"
  value       = module.wordpress-instance-sg.security_group_id
}