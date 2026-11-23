locals {
  use_vm       = var.deployment_mode == "vm"
  use_cloudsql = var.deployment_mode == "cloudsql"

  vm_ip   = one(google_compute_address.vm_ip[*].address)
  sql_ip  = one(google_sql_database_instance.mysql[*].public_ip_address)
  db_host = coalesce(local.vm_ip, local.sql_ip)
}

resource "google_project_service" "compute" {
  count              = local.use_vm ? 1 : 0
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  count              = local.use_cloudsql ? 1 : 0
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}