terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 5.30.0, < 6.0.0" }
    null   = { source = "hashicorp/null", version = "~> 3.2" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Ambos modos de instalación viven en ./modes; deployment_mode decide cuál se crea.
module "modes" {
  source = "./modes"

  deployment_mode  = var.deployment_mode
  name_prefix      = var.name_prefix
  region           = var.gcp_region
  zone             = var.gcp_zone
  db_name          = var.db_name
  db_user          = var.db_user
  db_password      = var.db_password
  authorized_cidrs = var.authorized_cidrs
  schema_path      = var.load_schema ? "${path.root}/schema/schema.sql" : null
  vm               = var.vm
  cloudsql         = var.cloudsql
}