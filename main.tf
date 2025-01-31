module "these_tags" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace = var.project
  name      = local.name
  delimiter = "-"

  tags = {
    "Terraform"   = "true",
    "Module"      = "elasticache",
    "project"     = var.project,
    "application" = var.application_name,
    "stage"       = var.stage,
    "service"     = "memcached"
  }
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${local.name}-${var.engine}"
  family = "${var.engine}${join(".", slice(split(".", var.engine_version), 0, 2))}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${local.name}-${var.engine}"
  description = "Used within the ${local.name} ${var.engine} cluster"
  subnet_ids  = var.subnet_ids
  tags        = module.these_tags.tags
}

resource "aws_security_group" "this" {
  name        = "${local.name}-${var.engine}"
  description = "Used within the ${local.name} ${var.engine} cluster"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "these" {
  for_each = local.security_group_rules

  security_group_id = aws_security_group.this.id
  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id                 = local.name
  engine                     = "memcached"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  apply_immediately          = var.apply_immediately
  maintenance_window         = var.maintenance_window
  transit_encryption_enabled = local.transit_encryption_enabled
  parameter_group_name       = aws_elasticache_parameter_group.this.name
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  network_type               = var.network_type
  port                       = local.port
  ip_discovery               = var.ip_discovery
  notification_topic_arn     = var.notification_topic_arn

  security_group_ids = concat(var.security_group_ids, [aws_security_group.this.id])
  subnet_group_name  = aws_elasticache_subnet_group.this.name

  az_mode                      = var.az_mode
  num_cache_nodes              = local.num_cache_nodes
  availability_zone            = var.availability_zone
  preferred_availability_zones = var.preferred_availability_zones

  tags = module.these_tags.tags
}

# This has not been tested, and only here to avoid refactoring outputs later
resource "aws_elasticache_cluster" "redis" {
  count = var.engine == "redis" ? 1 : 0

  cluster_id                 = local.name
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  apply_immediately          = var.apply_immediately
  maintenance_window         = var.maintenance_window
  transit_encryption_enabled = local.transit_encryption_enabled
  parameter_group_name       = aws_elasticache_parameter_group.this.name
}
