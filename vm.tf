# ===========================================================================
# MODO 1: VM vacía (Ubuntu) + startup script que instala MySQL
# Se crea solo si deployment_mode = "vm"
# ===========================================================================

resource "google_compute_network" "vpc" {
  count                   = local.use_vm ? 1 : 0
  name                    = "${var.name_prefix}-network"
  auto_create_subnetworks = true

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "mysql" {
  count   = local.use_vm ? 1 : 0
  name    = "${var.name_prefix}-allow-mysql"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = var.authorized_cidrs
  target_tags   = ["${var.name_prefix}-vm"]
}

resource "google_compute_firewall" "ssh" {
  count   = local.use_vm ? 1 : 0
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = concat(["35.235.240.0/20"], var.authorized_cidrs)
  target_tags   = ["${var.name_prefix}-vm"]
}

resource "google_compute_address" "vm_ip" {
  count  = local.use_vm ? 1 : 0
  name   = "${var.name_prefix}-ip"
  region = var.gcp_region

  depends_on = [google_project_service.compute]
}

resource "google_compute_instance" "mysql_vm" {
  count        = local.use_vm ? 1 : 0
  name         = "${var.name_prefix}-vm"
  machine_type = var.vm_machine_type
  zone         = var.gcp_zone
  tags         = ["${var.name_prefix}-vm"]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.vm_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.vpc[0].id

    access_config {
      nat_ip = google_compute_address.vm_ip[0].address
    }
  }

  # La VM nace vacía; todo lo instala el startup script leyendo estos metadatos.
  # replace(...) quita los saltos de línea de Windows (CRLF) que romperían el script en Linux.
  metadata = merge(
    {
      startup-script = replace(file("${path.module}/scripts/install_mysql.sh"), "\r\n", "\n")
      db-name        = var.db_name
      db-user        = var.db_user
      db-password    = var.db_password
    },
    var.load_schema ? { db-schema = replace(file("${path.module}/schema.sql"), "\r\n", "\n") } : {}
  )

  depends_on = [google_project_service.compute]
}