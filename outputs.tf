output "db_host" {
  description = "IP pública para conectar."
  value       = module.modes.db_host
}

output "mysql_connection_command" {
  value = "mysql -h ${module.modes.db_host} -P 3306 -u ${var.db_user} -p ${var.db_name}"
}

output "vm_ssh_command" {
  description = "Solo modo vm."
  value       = module.modes.ssh_command
}

output "vm_bootstrap_log_command" {
  description = "Solo modo vm."
  value       = module.modes.bootstrap_log_command
}

output "cloudsql_connection_name" {
  description = "Solo modo cloudsql."
  value       = module.modes.connection_name
}