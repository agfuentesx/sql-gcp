# SQL-GCP

Este proyecto despliega una base de datos MySQL en Google Cloud Platform y deja lista una base de datos con un usuario administrador, capaz de conectarse y de crear bases de datos y tablas, lo hace de dos maneras, se puede elegir cuál usar con una sola variable:

| `deployment_mode` | Qué se crea | Cuándo conviene |
|---|---|---|
| `vm` | Una VM Ubuntu vacía en Compute Engine. Un startup script instala y configura MySQL 8.0. | Se controla el servidor, para ver cómo se instala MySQL por dentro. |
| `cloudsql` | Una instancia de Cloud SQL (MySQL administrado por Google, ya instalado). | El usuario no administra el sistema operativo, los parches ni la instalación. |

En ambos modos el resultado es el mismo para quien se conecta: una IP pública, un usuario, una contraseña y una base de datos con el esquema de `schema/schema.sql` ya cargado.

## Estructura

```
.
├── main.tf              # Configura el provider y llama al módulo modes
├── variables.tf         # Declaración de todas las variables, con sus validaciones
├── outputs.tf           # IP y comandos de conexión
├── config/
│   └── terraform.tfvars # Definir IP y usuario de BD
├── modes/               # Los dos modos de instalación, juntos
│   ├── vm.tf            # VM, red, firewall e IP fija
│   ├── cloudsql.tf      # Instancia Cloud SQL, base de datos, usuario y carga del esquema
│   ├── install_mysql.sh # Startup script que instala MySQL en la VM
│   ├── variables.tf
│   └── outputs.tf
└── schema/
    └── schema.sql       # Tablas, datos de ejemplo y una vista
```

`modes/` es un único módulo que contiene los dos modos. Cada recurso tiene un `count` que depende de `deployment_mode`, así que solo se crea lo del modo elegido.

## Requisitos

- Terraform 1.5 o superior.
- Google Cloud CLI (`gcloud`) instalado y con credenciales para Terraform:
  ```bash
  gcloud auth application-default login
  ```
- Un proyecto de GCP con facturación activa, y un usuario con permisos para habilitar APIs y crear recursos de Compute Engine y Cloud SQL (en un entorno de pruebas basta el rol Editor o Propietario).
- El cliente `mysql` instalado en tu máquina. Siempre se necesita para conectar, y en modo `cloudsql` también lo usa Terraform para cargar el esquema.

## Configuración

Edita `config/terraform.tfvars`:

```hcl
deployment_mode  = "vm"                      # "vm" o "cloudsql"
gcp_project_id   = "<tu-id-de-proyecto-gcp>"   # el ID del proyecto, no el nombre
db_name          = "company_db"
db_user          = "admin"
authorized_cidrs = ["80.80.80.80/32"]       # tu IP pública
```

Para saber la IP pública, ir https://ifconfig.me. Con prefijo /32 para ser único host.

La contraseña no va en el archivo. Se pasa como variable de entorno:
```bash
# Linux o macOS
export TF_VAR_db_password='Password'
```

```powershell
# Windows PowerShell
$env:TF_VAR_db_password = 'Password'
```

### Variables

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `deployment_mode` | (obligatoria) | `vm` o `cloudsql`. |
| `gcp_project_id` | (obligatoria) | ID del proyecto de GCP. |
| `gcp_region` / `gcp_zone` | `us-central1` / `us-central1-a` | Ubicación de los recursos. |
| `name_prefix` | `devops-mysql` | Prefijo para nombrar los recursos. |
| `db_name` | `company_db` | Base de datos que se crea. |
| `db_user` | `admin` | Usuario administrador. No puede llamarse `root`. |
| `db_password` | (obligatoria) | Contraseña del usuario, mínimo 8 caracteres. Se marca como sensible. |
| `authorized_cidrs` | (obligatoria) | Lista de IPs o rangos CIDR con acceso al puerto 3306. |
| `load_schema` | `true` | Si es `false`, no se carga `schema/schema.sql`. |
| `vm` | `e2-small`, 20 GB | Objeto con `machine_type` y `disk_size_gb` (solo modo `vm`). |
| `cloudsql` | ver abajo | Objeto con las opciones de Cloud SQL (solo modo `cloudsql`). |

Valores por defecto del objeto `cloudsql`: `tier = "db-f1-micro"`, `mysql_version = "MYSQL_8_0"`, `disk_size_gb = 10`, `require_tls = false`, `deletion_protection = false`.

Para cambiarlos, descomentar y ajustar las líneas de ejemplo en `config/terraform.tfvars`:

```hcl
vm       = { machine_type = "e2-medium", disk_size_gb = 30 }
cloudsql = { tier = "db-g1-small", mysql_version = "MYSQL_8_4" }
```

Antes de elegir una versión de MySQL para Cloud SQL, confirmar en la documentación de Google cuáles tienen soporte vigente.

## Despliegue

Todos los comandos se ejecutan desde la raíz del proyecto.

```bash
terraform init
terraform plan  -var-file=config/terraform.tfvars
terraform apply -var-file=config/terraform.tfvars
```

`plan` te muestra qué se va a crear sin tocar nada. `apply` lo crea y te pide confirmación escribiendo `yes`.

Para elegir el modo sin editar el archivo, puedes sobrescribirlo en la línea de comandos:

```bash
terraform apply -var-file=config/terraform.tfvars -var deployment_mode=cloudsql
```

### Tiempos esperados

- **Modo `vm`:** `apply` termina en un par de minutos, pero MySQL todavía se está instalando dentro de la VM. Tarda entre 1 y 3 minutos más.
- **Modo `cloudsql`:** `apply` espera a que la instancia esté lista, lo que suele tomar entre 5 y 10 minutos.

## Conectarse

Al terminar, Terraform muestra los outputs. También se puede consultar:

```bash
terraform output db_host
terraform output -raw mysql_connection_command
```

El segundo imprime el comando completo, con la forma `mysql -h <IP> -P 3306 -u admin -p company_db`. Al ejecutar, escribir la contraseña cuando la pida. Sirve igual con DBeaver, DataGrip o cualquier cliente: usa la IP, el puerto 3306, el usuario y la contraseña.

### Comprobar que todo funciona

Una vez dentro de MySQL:

```sql
SELECT * FROM v_employees_by_company;
```

Debe devolver tres filas, ordenadas por nombre: Alice Johnson (DevOpsInc), Jane Smith (TechCorp) y John Doe (TechCorp).

Para comprobar que el usuario puede crear bases de datos y tablas:

```sql
CREATE DATABASE prueba;
USE prueba;
CREATE TABLE t (id INT PRIMARY KEY);
DROP DATABASE prueba;
```

### Seguir la instalación en modo `vm`

Si la conexión falla justo después del `apply`, lo más probable es que MySQL aún se esté instalando. El log del proceso se consulta con:

```bash
terraform output -raw vm_bootstrap_log_command
```

Copiar y ejecutar el comando que imprime. La instalación terminó cuando el log termina con "MySQL instalado y configurado correctamente". Para entrar a la VM por SSH, usar `terraform output -raw vm_ssh_command`.

## Qué hace cada modo y por qué

### Modo `vm`

Crea una red VPC, dos reglas de firewall, una IP pública fija y una VM Ubuntu 22.04 que nace sin nada instalado. Todo lo demás lo hace `modes/install_mysql.sh`, que Google ejecuta al arrancar la VM. El script instala MySQL 8.0, abre el acceso remoto, crea la base de datos y el usuario, y carga el esquema.

Decisiones que conviene conocer:

- **Ubuntu 22.04 y no Debian.** Los repositorios de Debian 12 traen MariaDB en lugar de MySQL. Ubuntu 22.04 trae MySQL 8.0 directamente.
- **IP fija.** Así la dirección no cambia.
- **Firewall restringido.** El puerto 3306 solo se abre a las IPs de `authorized_cidrs`. El SSH se permite desde esas mismas IPs y desde el rango de IAP de Google (35.235.240.0/20), que permite entrar con `gcloud compute ssh --tunnel-through-iap`.
- **Configuración por metadatos.** El script lee el nombre de la base de datos, el usuario, la contraseña y el esquema desde los metadatos de la VM, en lugar de tenerlos escritos dentro del script. Así el mismo script sirve para cualquier configuración.
- **El script corre una sola vez.** Al terminar deja un marcador en `/var/lib/mysql-bootstrap.done`. En reinicios posteriores detecta el marcador y no hace nada. Si cambias el script o los metadatos, la VM no los reaplica por sí sola.
- **Permisos del usuario.** Recibe `ALL PRIVILEGES` sobre todo (`*.*`) con `GRANT OPTION`, lo que le permite crear bases de datos y tablas. Es algo más amplio que el administrador de Cloud SQL, que no tiene `SUPER` ni `FILE`.
- **Saltos de línea.** Terraform convierte los saltos de línea de Windows (CRLF) a los de Linux antes de enviar el script. Sin esto, un script guardado desde Windows falla al ejecutarse en la VM.

### Modo `cloudsql`

Crea una instancia de Cloud SQL con MySQL, la base de datos y el usuario. Después carga `schema/schema.sql` ejecutando el cliente `mysql` desde la máquina que se corre.

Decisiones que conviene conocer:

- **Nombre con sufijo aleatorio.** Cloud SQL no permite reutilizar el nombre de una instancia que se acaba de borrar durante un tiempo. El sufijo evita que un `destroy` seguido de un `apply` falle por eso.
- **Edición Enterprise.** El tamaño `db-f1-micro` solo existe en esa edición, por eso se fija de forma explícita.
- **Carga del esquema desde tu máquina.** Requiere el cliente `mysql` instalado y que la IP esté en `authorized_cidrs`. _Si no se puede cumplir, poner `load_schema = false` y carga el esquema a mano_. El esquema se vuelve a cargar solo si cambia `schema.sql` o se recrea la instancia.
- **TLS opcional.** Con `require_tls = true`, Cloud SQL rechaza las conexiones sin cifrar. El cliente tendrá que usar SSL.

### El esquema

`schema/schema.sql` crea las tablas `companies` y `employees`, inserta datos de ejemplo y define la vista `v_employees_by_company`. Está escrito para poder ejecutarse varias veces sin duplicar datos: usa `CREATE TABLE IF NOT EXISTS`, `INSERT IGNORE` con claves únicas y `CREATE OR REPLACE VIEW`. No selecciona una base de datos, esa la indica quien lo ejecuta, y por eso funciona con cualquier valor de `db_name`.

## Cambiar de modo

Cambiar `deployment_mode` sobre un despliegue existente destruye los recursos del modo anterior y crea los del nuevo. Terraform lo mostrará en el `plan`. Si se quiere conservar ambos al mismo tiempo, usar carpetas o workspaces separados.

## Eliminar todo

```bash
terraform destroy -var-file=config/terraform.tfvars
```

Hacerlo cuando se termine de probar: la VM o la instancia de Cloud SQL generan costo mientras existan, y Cloud SQL no tiene capa gratuita permanente. Si se activó `deletion_protection = true`, primero ponerlo en `false` y ejecutar `apply`, o el `destroy` fallará.

## Seguridad

- **No se recomienda usar `0.0.0.0/0` en `authorized_cidrs`.** Dejaría MySQL abierto a todo internet, es más seguro usar la IP con `/32`. Si la IP cambia, actualiza el valor y volver a aplicar.
- **El estado de Terraform contiene la contraseña en texto plano.** El archivo `terraform.tfstate` no debe subirse a un repositorio. El `.gitignore` incluido ya lo excluye, para trabajarlo en equipo, usar un backend remoto con acceso controlado.
- **En modo `vm`, la contraseña viaja por los metadatos de la instancia.** Cualquiera con permiso de lectura sobre la VM en el proyecto puede verla. Es aceptable para pruebas, para producción conviene usar Secret manager.
- **Esta configuración es para pruebas y aprendizaje.** Una instalación de producción debería usar IP privada, copias de seguridad y alta disponibilidad.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `apply` falla diciendo que una API no está habilitada | La API se acaba de habilitar y aún no se propaga | Esperar un minuto y ejecutar `apply` de nuevo. |
| `mysql: command not found` durante el `apply` (modo `cloudsql`) | No está el cliente `mysql` instalado | Instalarlo, o usar `load_schema = false`. |
| La conexión expira o es rechazada | La IP no está en `authorized_cidrs`, o cambió | Actualizar `authorized_cidrs` y volver a aplicar. |
| La conexión falla justo después del `apply` en modo `vm` | MySQL aún se está instalando | Consulta el log con `vm_bootstrap_log_command` y esperar a que termine. |
| `Access denied for user` | Contraseña distinta a la usada en el despliegue | Verificar `TF_VAR_db_password` en la terminal, si se cambia, ejecutar `apply` de nuevo. |
| `Error: No value for required variable` | Falta `-var-file` o la variable de entorno | Revisar que se está usando `-var-file=config/terraform.tfvars` y que `TF_VAR_db_password` está definida en esa terminal. |