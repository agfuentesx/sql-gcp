#!/bin/bash
# =============================================================================
# Startup script: instala y configura MySQL 8.0 en Ubuntu 22.04.
# Lee la configuración desde los metadatos de la VM (los pone Terraform):
#   db-name, db-user, db-password, db-schema (opcional)
# Es idempotente: solo se ejecuta una vez (marcador en /var/lib).
# Log: /var/log/mysql-bootstrap.log
# =============================================================================
set -euo pipefail

exec > >(tee -a /var/log/mysql-bootstrap.log) 2>&1

MARKER=/var/lib/mysql-bootstrap.done
if [[ -f "$MARKER" ]]; then
  echo "[$(date -Is)] MySQL ya fue configurado. Nada que hacer."
  exit 0
fi

echo "[$(date -Is)] Iniciando instalación de MySQL..."

meta() {
  curl -sf -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1" || true
}

DB_NAME="$(meta db-name)"
DB_USER="$(meta db-user)"
DB_PASS="$(meta db-password)"

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
  echo "ERROR: faltan metadatos db-name, db-user o db-password."
  exit 1
fi

if [[ ! "$DB_NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ || ! "$DB_USER" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
  echo "ERROR: db-name o db-user contienen caracteres no permitidos."
  exit 1
fi

# Escapa \ y ' para usar la contraseña dentro de un literal SQL
ESC_PASS="${DB_PASS//\\/\\\\}"
ESC_PASS="${ESC_PASS//\'/\\\'}"

# --- Instalación ------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get -o DPkg::Lock::Timeout=300 update -y
apt-get -o DPkg::Lock::Timeout=300 install -y mysql-server mysql-client

# --- Permitir conexiones remotas -------------------------------------------
cat > /etc/mysql/mysql.conf.d/99-remote.cnf <<CNF
[mysqld]
bind-address = 0.0.0.0
mysqlx-bind-address = 127.0.0.1
CNF

systemctl enable mysql
systemctl restart mysql

for _ in $(seq 1 30); do
  mysqladmin -u root ping --silent && break
  sleep 2
done
mysqladmin -u root ping --silent

# --- Base de datos y usuario administrador ---------------------------------
# GRANT ALL en *.* permite crear bases de datos y tablas (equivalente al
# usuario admin de Cloud SQL).
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${ESC_PASS}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${ESC_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

# --- Esquema inicial (opcional) --------------------------------------------
SCHEMA="$(meta db-schema)"
if [[ -n "$SCHEMA" ]]; then
  echo "[$(date -Is)] Cargando schema.sql en ${DB_NAME}..."
  printf '%s\n' "$SCHEMA" | mysql -u root "$DB_NAME"
fi

touch "$MARKER"
echo "[$(date -Is)] MySQL instalado y configurado correctamente."