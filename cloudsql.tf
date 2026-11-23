# ===========================================================================
# MODO 2: Cloud SQL (MySQL administrado, ya instalado)
# Se crea solo si deployment_mode = "cloudsql"
# ===========================================================================

resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_sql_database_instance" "mysql" {
  count            = local.use_cloudsql ? 1 : 0
  name             = "${var.name_prefix}-${random_id.suffix.hex}"
  database_version = var.cloudsql_mysql_version
  region           = var.gcp_region

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.cloudsql_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = var.cloudsql_disk_size_gb

    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = var.cloudsql_require_tls ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

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
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_name
  instance = google_sql_database_instance.mysql[0].name
}

resource "google_sql_user" "user" {
  count    = local.use_cloudsql ? 1 : 0
  name     = var.db_user
  host     = "%"
  instance = google_sql_database_instance.mysql[0].name
  password = var.db_password
}

resource "null_resource" "schema" {
  count = local.use_cloudsql && var.load_schema ? 1 : 0

  # Se vuelve a ejecutar si cambia schema.sql o se recrea la instancia
  triggers = {
    schema_hash = filemd5("${path.module}/schema.sql")
    instance_id = google_sql_database_instance.mysql[0].id
  }

  provisioner "local-exec" {
    command = "mysql --host=${google_sql_database_instance.mysql[0].public_ip_address} --user=${var.db_user} ${var.db_name} -e \"source ${path.module}/schema.sql\""

    environment = {
      MYSQL_PWD = var.db_password
    }
  }

  depends_on = [google_sql_database.db, google_sql_user.user]
}