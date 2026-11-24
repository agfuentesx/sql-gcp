variable "deployment_mode" { type = string }
variable "name_prefix" { type = string }
variable "region" { type = string }
variable "zone" { type = string }
variable "db_name" { type = string }
variable "db_user" { type = string }
variable "authorized_cidrs" { type = list(string) }

variable "db_password" {
  type      = string
  sensitive = true
}

variable "schema_path" {
  description = "Ruta al .sql a cargar; null = no cargar."
  type        = string
  default     = null
}

variable "vm" {
  type = object({
    machine_type = string
    disk_size_gb = number
  })
}

variable "cloudsql" {
  type = object({
    tier                = string
    mysql_version       = string
    disk_size_gb        = number
    require_tls         = bool
    deletion_protection = bool
  })
}