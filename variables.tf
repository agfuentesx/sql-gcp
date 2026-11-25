# --- Selector ---------------------------------------------------------------
variable "deployment_mode" {
  description = "\"vm\" = VM vacía + startup script que instala MySQL | \"cloudsql\" = Cloud SQL administrado."
  type        = string

  validation {
    condition     = contains(["vm", "cloudsql"], var.deployment_mode)
    error_message = "deployment_mode debe ser \"vm\" o \"cloudsql\"."
  }
}

# --- Proyecto GCP -----------------------------------------------------------
variable "gcp_project_id" {
  description = "<id-del-proyecto>"
  type        = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
}

variable "name_prefix" {
  description = "Prefijo para nombrar los recursos."
  type        = string
  default     = "devops-mysql"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,30}[a-z0-9])?$", var.name_prefix))
    error_message = "name_prefix: minúsculas, números y guiones, empezando con letra."
  }
}

# --- Base de datos (igual en ambos modos) ----------------------------------
variable "db_name" {
  type    = string
  default = "company_db"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.db_name))
    error_message = "db_name: solo letras, números y guion bajo."
  }
}

variable "db_user" {
  type    = string
  default = "admin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,31}$", var.db_user)) && lower(var.db_user) != "root"
    error_message = "db_user: solo letras, números y guion bajo, y no puede ser \"root\"."
  }
}

variable "db_password" {
  description = "Pásala con: export TF_VAR_db_password='...'"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password debe tener al menos 8 caracteres."
  }
}

variable "load_schema" {
  description = "Cargar schema/schema.sql en la base de datos."
  type        = bool
  default     = true
}

# --- Red --------------------------------------------------------------------
variable "authorized_cidrs" {
  description = "IPs/CIDR con acceso al puerto 3306, por ejemplo: [\"80.80.80.80/32\"]."
  type        = list(string)

  validation {
    condition     = length(var.authorized_cidrs) > 0 && alltrue([for c in var.authorized_cidrs : can(cidrnetmask(c))])
    error_message = "authorized_cidrs debe tener al menos un CIDR IPv4 válido."
  }
}

# --- Opciones por modo ------------------------------------------------------
variable "vm" {
  description = "Opciones del modo vm."
  type = object({
    machine_type = optional(string, "e2-small")
    disk_size_gb = optional(number, 20)
  })
  default = {}
}

variable "cloudsql" {
  description = "Opciones del modo cloudsql."
  type = object({
    tier                = optional(string, "db-f1-micro")
    mysql_version       = optional(string, "MYSQL_8_0")
    disk_size_gb        = optional(number, 10)
    require_tls         = optional(bool, false)
    deletion_protection = optional(bool, false)
  })
  default = {}
}