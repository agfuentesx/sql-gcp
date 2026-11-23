# ---------------------------------------------------------------------------
# Selector principal
# ---------------------------------------------------------------------------
variable "deployment_mode" {
  description = "Tipo de instalación: \"vm\" = VM vacía + startup script que instala MySQL | \"cloudsql\" = Cloud SQL (MySQL administrado)."
  type        = string

  validation {
    condition     = contains(["vm", "cloudsql"], var.deployment_mode)
    error_message = "deployment_mode debe ser \"vm\" o \"cloudsql\"."
  }
}

# ---------------------------------------------------------------------------
# GCP
# ---------------------------------------------------------------------------
variable "gcp_project_id" {
  description = "ID del proyecto de GCP (no el nombre, el ID)."
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
    error_message = "name_prefix: minúsculas, números y guiones, empezando con letra (máx. 32 caracteres)."
  }
}

# ---------------------------------------------------------------------------
# Configuración de base de datos (idéntica para ambos modos)
# ---------------------------------------------------------------------------
variable "db_name" {
  description = "Nombre de la base de datos que se crea."
  type        = string
  default     = "company_db"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.db_name))
    error_message = "db_name: solo letras, números y guion bajo, empezando con letra."
  }
}

variable "db_user" {
  description = "Usuario administrador de MySQL."
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,31}$", var.db_user)) && lower(var.db_user) != "root"
    error_message = "db_user: solo letras, números y guion bajo (máx. 32), y no puede ser \"root\"."
  }
}

variable "db_password" {
  description = "Contraseña del usuario. Recomendado pasarla con: export TF_VAR_db_password='...'"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password debe tener al menos 8 caracteres."
  }
}

variable "authorized_cidrs" {
  description = "Lista de IPs/CIDR con acceso al puerto 3306. Ej: [\"203.0.113.10/32\"]. Evita 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = length(var.authorized_cidrs) > 0 && alltrue([for c in var.authorized_cidrs : can(cidrnetmask(c))])
    error_message = "authorized_cidrs debe tener al menos un CIDR IPv4 válido (ej. \"203.0.113.10/32\")."
  }
}

variable "load_schema" {
  description = "Si es true, carga schema.sql en la base de datos (ambos modos)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Opciones modo "vm"
# ---------------------------------------------------------------------------
variable "vm_machine_type" {
  description = "Tipo de máquina de la VM (e2-micro tiene solo 1 GB RAM; e2-small es más cómodo para MySQL)."
  type        = string
  default     = "e2-small"
}

variable "vm_disk_size_gb" {
  type    = number
  default = 20
}

# ---------------------------------------------------------------------------
# Opciones modo "cloudsql"
# ---------------------------------------------------------------------------
variable "cloudsql_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "cloudsql_mysql_version" {
  description = "Versión de MySQL en Cloud SQL (ej. MYSQL_8_0, MYSQL_8_4). Verifica en la documentación de Cloud SQL cuál tiene soporte vigente."
  type        = string
  default     = "MYSQL_8_0"
}

variable "cloudsql_disk_size_gb" {
  type    = number
  default = 10
}

variable "cloudsql_require_tls" {
  description = "Si es true, Cloud SQL solo acepta conexiones cifradas (tu cliente debe usar SSL)."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protección contra borrado de la instancia Cloud SQL. En false permite terraform destroy."
  type        = bool
  default     = false
}