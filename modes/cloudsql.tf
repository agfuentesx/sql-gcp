# ===========================================================================
# MODO "cloudsql": MySQL administrado
# ===========================================================================
locals {
  sql_enabled = var.deployment_mode == "cloudsql"
}

resource "google_project_service" "sqladmin" {
  count              = local.sql_enabled ? 1 : 0
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Cloud SQL no deja reutilizar el nombre de una instancia borrada recientemente
resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_sql_database_instance" "mysql" {
  count               = local.sql_enabled ? 1 : 0
  name                = "${var.name_prefix}-${random_id.suffix.hex}"
  database_version    = var.cloudsql.mysql_version
  region              = var.region
  deletion_protection = var.cloudsql.deletion_protection

  settings {
    tier                        = var.cloudsql.tier
    edition                     = "ENTERPRISE" # db-f1-micro solo existe en Enterprise
    availability_type           = "ZONAL"
    disk_size                   = var.cloudsql.disk_size_gb
    deletion_protection_enabled = var.cloudsql.deletion_protection

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = var.cloudsql.require_tls ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      dynamic "authorized_networks" {
        for_each = var.authorized_cidrs
        content {
          name  = "allowed-${authorized_networks.key}"
          value = authorized_networks.value
        }
      }
    }
  }

  depends_on = [google_project_service.sqladmin]
}

resource "google_sql_database" "db" {
  count    = local.sql_enabled ? 1 : 0
  name     = var.db_name
  instance = google_sql_database_instance.mysql[0].name
}

# Mismo usuario y contraseña que en la VM; puede crear bases de datos y tablas
resource "google_sql_user" "user" {
  count    = local.sql_enabled ? 1 : 0
  name     = var.db_user
  host     = "%"
  instance = google_sql_database_instance.mysql[0].name
  password = var.db_password
}

# Carga el esquema desde local. Requiere el cliente "mysql" local y la IP en authorized_cidrs.
resource "null_resource" "schema" {
  count = local.sql_enabled && var.schema_path != null ? 1 : 0

  triggers = {
    schema_hash = filemd5(var.schema_path)
    instance_id = google_sql_database_instance.mysql[0].id
  }

  provisioner "local-exec" {
    command     = "mysql --host=${google_sql_database_instance.mysql[0].public_ip_address} --user=${var.db_user} ${var.db_name} -e \"source ${var.schema_path}\""
    environment = { MYSQL_PWD = var.db_password }
  }

  depends_on = [google_sql_database.db, google_sql_user.user]
}