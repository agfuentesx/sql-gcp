# ===========================================================================
# MODO "vm": VM Ubuntu vacía + startup script que instala MySQL
# ===========================================================================
locals {
  vm_enabled = var.deployment_mode == "vm"
  vm_tag     = "${var.name_prefix}-vm"
}

resource "google_project_service" "compute" {
  count              = local.vm_enabled ? 1 : 0
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vm" {
  count                   = local.vm_enabled ? 1 : 0
  name                    = "${var.name_prefix}-network"
  auto_create_subnetworks = true
  depends_on              = [google_project_service.compute]
}

resource "google_compute_firewall" "mysql" {
  count         = local.vm_enabled ? 1 : 0
  name          = "${var.name_prefix}-allow-mysql"
  network       = google_compute_network.vm[0].name
  source_ranges = var.authorized_cidrs
  target_tags   = [local.vm_tag]

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
}

# SSH: rango de IAP de Google + IPs autorizadas
resource "google_compute_firewall" "ssh" {
  count         = local.vm_enabled ? 1 : 0
  name          = "${var.name_prefix}-allow-ssh"
  network       = google_compute_network.vm[0].name
  source_ranges = concat(["35.235.240.0/20"], var.authorized_cidrs)
  target_tags   = [local.vm_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_address" "vm" {
  count      = local.vm_enabled ? 1 : 0
  name       = "${var.name_prefix}-ip"
  region     = var.region
  depends_on = [google_project_service.compute]
}

resource "google_compute_instance" "vm" {
  count        = local.vm_enabled ? 1 : 0
  name         = "${var.name_prefix}-vm"
  machine_type = var.vm.machine_type
  zone         = var.zone
  tags         = [local.vm_tag]

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts" # trae MySQL 8.0 en sus repos
      size  = var.vm.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = google_compute_network.vm[0].id

    access_config {
      nat_ip = google_compute_address.vm[0].address
    }
  }

  # La VM nace vacía; el startup script lee estos metadatos e instala MySQL.
  # replace(...) quita los saltos de línea de Windows (CRLF) que romperían el script en Linux.
  metadata = merge(
    {
      startup-script = replace(file("${path.module}/install_mysql.sh"), "\r\n", "\n")
      db-name        = var.db_name
      db-user        = var.db_user
      db-password    = var.db_password
    },
    var.schema_path != null ? { db-schema = replace(file(var.schema_path), "\r\n", "\n") } : {}
  )

  depends_on = [google_project_service.compute]
}