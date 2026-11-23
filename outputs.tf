output "deployment_mode" {
  description = "Modo desplegado."
  value       = var.deployment_mode
}

output "db_host" {
  description = "IP pública para conectarte (DBeaver, DataGrip, mysql, etc.)."
  value       = local.db_host
}

output "db_port" {
  value = 3306
}

output "db_name" {
  value = var.db_name
}

output "db_user" {
  value = var.db_user
}

output "mysql_connection_command" {
  description = "Comando para conectarte con el cliente mysql (pedirá la contraseña)."
  value       = "mysql -h ${local.db_host} -P 3306 -u ${var.db_user} -p ${var.db_name}"
}

output "vm_ssh_command" {
  description = "Solo modo vm: SSH a la VM mediante IAP."
  value       = local.use_vm ? "gcloud compute ssh ${one(google_compute_instance.mysql_vm[*].name)} --zone ${var.gcp_zone} --tunnel-through-iap" : null
}

output "vm_bootstrap_log_command" {
  description = "Solo modo vm: ver el progreso de la instalación de MySQL (tarda 1-3 min tras el apply)."
  value       = local.use_vm ? "gcloud compute ssh ${one(google_compute_instance.mysql_vm[*].name)} --zone ${var.gcp_zone} --tunnel-through-iap --command 'sudo tail -n 50 /var/log/mysql-bootstrap.log'" : null
}

output "cloudsql_connection_name" {
  description = "Solo modo cloudsql: connection name de la instancia."
  value       = one(google_sql_database_instance.mysql[*].connection_name)
}