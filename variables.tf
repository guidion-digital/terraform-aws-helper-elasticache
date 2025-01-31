variable "project" {
  description = "The project name"
  type        = string
}

variable "application_name" {
  description = "The application name"
  type        = string
}

variable "name" {
  description = "The name of the cluster. If not provided, it will be the application name"
  type        = string
  default     = null
}

locals {
  name = var.name != null ? var.name : var.application_name
}

variable "stage" {
  description = "The stage name"
  type        = string
}

variable "engine" {
  description = "NOTE: Only memcached is supported at the moment. Engine to use. Valid values: memcached, redis"
  type        = string
  default     = "memcached"

  validation {
    condition     = contains(["memcached", "redis"], var.engine)
    error_message = "engine must be either 'memcached' or 'redis'"
  }
}

variable "engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "1.6.17"
}

variable "apply_immediately" {
  description = "Whether to apply the changes immediately"
  type        = bool
  default     = false
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in-transit. Supported only with Memcached versions 1.6.12 and later, running in a VPC"
  type        = bool
  default     = true
}

locals {
  engine_version_as_int      = tonumber(replace(var.engine_version, ".", ""))
  transit_encryption_enabled = var.transit_encryption_enabled && var.engine == "memcached" && local.engine_version_as_int >= 1612
}

variable "auto_minor_version_upgrade" {
  description = "Whether to automatically upgrade to the latest minor version"
  type        = bool
  default     = null
}

variable "node_type" {
  description = "The node type to use"
  type        = string
  default     = "cache.t4g.micro"
}

variable "subnet_ids" {
  description = "Subnets to add to the cache's subnet group"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "One or more VPC existing security groups associated with the cache cluster. You can also add rules to the security group this module creates by supplying values to var.security_group_rules"
  type        = list(string)
  default     = []
}

variable "security_group_rules" {
  description = "Rules to add to the security group this module creates. All IPs in the VPC are allowed if this is not supplied"
  type = map(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))

  default = {}
}

variable "vpc_id" {
  description = "The VPC ID to create the security group in"
  type        = string
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

variable "allowed_cidrs" {
  description = "Used to determine which IPs will be allowed to allow access cache. By default, all IPs from var.vpc_id are allowed"
  type        = list(string)

  default = null
}

locals {
  security_group_rules = length(var.security_group_rules) != 0 ? var.security_group_rules : {
    default = {
      type        = "ingress"
      from_port   = local.port
      to_port     = local.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs != null ? var.allowed_cidrs : [data.aws_vpc.this.cidr_block]
    }
  }
}

variable "az_mode" {
  description = "single-az or cross-az"
  type        = string
  default     = "single-az"

  validation {
    condition     = var.az_mode == null || contains(["single-az", "cross-az"], var.az_mode)
    error_message = "az_mode must be either 'single-az' or 'cross-az'"
  }
}

variable "availability_zone" {
  description = "Availability Zone for the cache cluster. If you want to create cache nodes in multi-az, use preferred_availability_zones instead"
  type        = string
  default     = null
}

variable "preferred_availability_zones" {
  description = "The preferred availability zones to use"
  type        = list(string)
  default     = null
}

variable "num_cache_nodes" {
  description = "The initial number of cache nodes that the cache cluster will have. For Redis, this value must be 1. For Memcached, this value must be between 1 and 40, and will be automatically bumped to 2 if az-mode is set to cross-az and you've tried to set this to 1. If this number is reduced on subsequent runs, the highest numbered nodes will be removed"
  type        = number
  default     = 1
}

locals {
  num_cache_nodes = var.az_mode == "cross-az" && var.num_cache_nodes < 2 ? 2 : var.num_cache_nodes
}

variable "maintenance_window" {
  description = "The maintenance window to use"
  type        = string
  default     = "sun:05:00-sun:09:00"
}

variable "parameters" {
  description = "The parameters to use"
  type = list(object({
    name  = string
    value = string
  }))

  default = []
}

variable "ip_discovery" {
  description = "The IP version to advertise in the discovery protocol"
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "ipv6"], var.ip_discovery)
    error_message = "ip_discovery must be either 'ipv4' or 'ipv6'"
  }
}

variable "network_type" {
  description = "The IP versions for cache cluster connections. IPv6 is supported with Redis engine 6.2 onword or Memcached version 1.6.6 for all Nitro system instances"
  type        = string
  default     = "ipv4"
}

variable "port" {
  description = "The port to use"
  type        = number
  default     = null
}

locals {
  port = var.port == null && var.engine == "memcached" ? 11211 : var.port == null && var.engine == "redis" ? 6379 : var.port
}

variable "notification_topic_arn" {
  description = "The notification topic ARN to use"
  type        = string
  default     = null
}
