Part of the [Terrappy framework](https://github.com/guidion-digital/terrappy).

---

![Latest Tag](https://img.shields.io/github/v/tag/guidion-digital/terraform-aws-helper-elasticache?label=Latest%20Tag)
![Latest Stable Tag](https://img.shields.io/github/v/tag/guidion-digital/terraform-aws-helper-elasticache?filter=!*alpha*&label=Latest%20Stable%20Tag)
![Registry Downloads](https://img.shields.io/terraform/module/dm/guidion-digital/helper-elasticache/aws?label=Registry%20Downloads)
![Static Badge](https://img.shields.io/badge/https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fguidion-digital%2Fhelper-elasticache%2Faws%2Flatest?label=Terraform%20Registry)

# Usage

See [example](./examples/example/main.tf).

No networking resources other than security groups will be created, so a VPC and subnets must already exist, and `var.vpc_id` must be set.
