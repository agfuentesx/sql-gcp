output "db_host" {
  value = coalesce(
    one(google_compute_address.vm[*].address),
    one(google_sql_database_instance.mysql[*].public_ip_address)
  )
}

output "ssh_command" {
  value = local.vm_enabled ? "gcloud compute ssh ${google_compute_instance.vm[0].name} --zone ${var.zone} --tunnel-through-iap" : null
}

output "bootstrap_log_command" {
  value = local.vm_enabled ? "gcloud compute ssh ${google_compute_instance.vm[0].name} --zone ${var.zone} --tunnel-through-iap --command 'sudo tail -n 50 /var/log/mysql-bootstrap.log'" : null
}

output "connection_name" {
  value = one(google_sql_database_instance.mysql[*].connection_name)
}