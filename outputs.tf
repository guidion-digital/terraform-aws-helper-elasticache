output "arn" {
  description = "The ARN of the created ElastiCache Cluster"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].arn : aws_elasticache_cluster.redis[0].arn
}

output "engine_version_actual" {
  description = "Because ElastiCache pulls the latest minor or patch for a version, this attribute returns the running version of the cache engine"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].engine_version_actual : aws_elasticache_cluster.redis[0].engine_version_actual
}

output "cache_nodes" {
  description = "List of node objects including id, address, port and availability_zone"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cache_nodes : aws_elasticache_cluster.redis[0].cache_nodes
}

output "cluster_address" {
  description = "(Memcached only) DNS name of the cache cluster without the port appended"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_address : null
}

output "configuration_endpoint" {
  description = "(Memcached only) Configuration endpoint to allow host discovery"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].configuration_endpoint : aws_elasticache_cluster.redis[0].configuration_endpoint
}

output "tags_all" {
  description = "Map of tags assigned to the resource, including those inherited from the provider default_tags configuration block"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].tags_all : aws_elasticache_cluster.redis[0].tags_all
}
