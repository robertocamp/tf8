## Networking
module "network" {
  source = "./modules/network"
}


# module "compute" {
#   source = "./modules/compute"
# }

module "security" {
  source = "./modules/security"
  vpc_id      = module.network.vpc_id
}