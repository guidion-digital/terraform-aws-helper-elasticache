# Networking the examples depend on. These are created in MiniStack (see providers.tf)
# so the tests don't rely on pre-existing infrastructure in a real AWS account.

locals {
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

resource "aws_vpc" "test" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "elasticache-test"
  }
}

resource "aws_subnet" "test" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.test.id
  availability_zone = local.availability_zones[count.index]
  cidr_block        = cidrsubnet(aws_vpc.test.cidr_block, 8, count.index)

  tags = {
    Name = "elasticache-test-${local.availability_zones[count.index]}"
  }
}
