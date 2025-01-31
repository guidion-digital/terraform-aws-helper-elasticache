module "memcached" {
  source = "../../"

  project          = "test_app"
  application_name = "test-app"
  stage            = "dev"

  engine         = "memcached"
  engine_version = "1.6.16"
  node_type      = "cache.t3.micro"

  # Use 'availablity_zone' if az_mode is 'single-az'
  az_mode                      = "cross-az"
  preferred_availability_zones = ["eu-central-1a", "eu-central-1b"]

  vpc_id     = "vpc-0dfab25adab0ea4d5"
  subnet_ids = ["subnet-0c778aad2e6e3b88b", "subnet-0a5208d551253a002", "subnet-0720e2396dc948d72"]

  parameters = [
    {
      name  = "maxmemory-policy"
      value = "noeviction"
    }
  ]

  # There are a number of ways to control access to the cluster. By default, setting
  # only vpc_id as above means that the entire VPC CIDR will have access.
  #
  # The next most direct way is setting explicit security group rules:
  # security_group_rules = {
  #   default = {
  #     type        = "ingress"
  #     from_port   = 11211
  #     to_port     = 11211
  #     protocol    = "tcp"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }
  # }
  # Or you could add security group IDs that were created elsewhere:
  # security_group_ids = [
  #   "sg-01234567890abcdef0"
  # ]
  # Finally, you can set the CIDR blocks to allow access to the cache cluster:
  # allowed_cidrs = ["10.0.0.0/16"]
  #
  # These are all cumulative, so using all three methods does not result in overrides.
  # Bear in mind however, that the default behaviour of allowing all IPs from the
  # VPC (var.vpc_id) will be overridden if any of these methods are used
}

output "memcached_address" {
  value = module.memcached.cluster_address
}
