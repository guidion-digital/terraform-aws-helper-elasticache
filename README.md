<!--- One-liner explaining the purpose of this module. -->

<!--- A note on naming: See [here](https://guidiondev.atlassian.net/wiki/spaces/DIG/pages/3959947265/Terraform+Module+Naming+Convention) for our naming convention -->

# Usage

See [example](./examples/example/main.tf).

> [!IMPORTANT]
> Whilst this module _will_ take "redis" as an option for var.engine, it currently only officially supports memcached. The redis resources are only present to avoid refactoring the outputs later when Redis is properly added. Redis creation has not been tested, use at your own risk

No networking resources other than security groups will be created, so a VPC and subnets must already exist, and `var.vpc_id` must be set.
