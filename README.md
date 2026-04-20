# new-moodle - Despliegue contenerizado de FP Virtual / Distancia (FPD)

Este proyecto es una versión modernizada y autocontenida del despliegue de Moodle para **FP Virtual Aragón (FPD)**, utilizando **imágenes oficiales de Docker** (`php:8.1-fpm`, `nginx`, `mariadb`, `redis`).

## Diferencias clave respecto al proyecto anterior

| Aspecto | Proyecto anterior | `new-moodle` |
|---------|-------------------|--------------|
| Imagen Moodle | `cateduac/moodle:4.1.3-nginx-fpm-unoconv` (personalizada) | `php:8.1-fpm` oficial + Dockerfile propio |
| Base de datos | Externa (no definida en compose) | MariaDB 10.6 **opcional** en `docker-compose.yml` (perfil `with-db`) o **externa** configurable |
| Código Moodle | Bind mount (`./moodle-code`) | Empaquetado dentro de la imagen Docker o **bind mount externo** configurable |
| Datos (`moodle-data`) | Bind mount | **Mantiene bind mount** para facilitar backups |
| Scripts init | Genéricos para varios tipos de centro | **Específicos para FPD** (simplificados) |

## Estructura

```
new-moodle/
├── Dockerfile                          # Imagen propia basada en php:8.1-fpm
├── docker-compose.yml                  # Stack completo: db + redis + moodle + nginx
├── .env                                # Variables de entorno (ejemplo para FPD)
├── entrypoint.sh                       # Entrypoint que instala/configura Moodle
├── moodle-code/                        # Código fuente de Moodle 4.1.19
├── moodle-data/                        # Carpeta vacía para datos (bind mount)
├── nginx/
│   └── default.conf                    # Configuración de Nginx
├── php-conf/                           # Configuraciones PHP (uploads, opcache...)
├── fpm-conf/                           # Configuraciones PHP-FPM
├── init-scripts/
│   ├── init.sh                         # Orquestador
│   ├── new-install/
│   │   ├── moodle.sh                   # Configuración específica FPD
│   │   ├── plugins.sh                  # Instalación de plugins FPD
│   │   ├── theme.sh                    # Tema Moove personalizado FPD
│   │   └── import_FPD_categories_and_courses.sh
│   └── upgrade/
│       ├── moodle.sh
│       ├── plugins.sh
│       └── theme.sh
├── themes/fpdist/                      # Assets del tema FPD
└── scripts/
    └── backup.sh                       # Backup coordinado BD + moodle-data
```

## Requisitos previos

1. Docker y Docker Compose instalados.
2. Red externa del proxy creada:
   ```bash
   docker network create nginx-proxy_frontend
   ```
3. Copiar y personalizar el archivo de entorno:
   ```bash
   cp .env.example .env
   # Edita .env con los valores reales (dominio, contraseñas, etc.)
   ```

## Puesta en marcha

### Stack completo (DB interna + código en imagen)

```bash
cd new-moodle

# 1. Construir la imagen
docker compose build

# 2. Levantar el entorno con base de datos interna
docker compose --profile with-db up -d

# 3. Seguir los logs (la instalación inicial puede tardar varios minutos)
docker compose logs -f moodle
```

### Con base de datos externa

Si ya tienes un contenedor MariaDB en el servidor (u otra instancia de MariaDB/MySQL):

1. En `.env`, configura las variables de conexión a la DB externa:
   ```env
   MOODLE_DB_HOST=IP_O_NOMBRE_DEL_CONTENEDOR_DB
   MOODLE_DB_PORT=3306
   MOODLE_DB_NAME=moodle
   MOODLE_DB_USER=moodle
   MOODLE_DB_PASSWORD=xxxxxxxx
   ```
2. Levanta el stack **sin** el perfil `with-db`:
   ```bash
   docker compose up -d
   ```

### Con código Moodle externo

Si prefieres montar el código de Moodle desde el host (útil para desarrollo o para gestionar el código fuera del contenedor):

1. En `.env`, define la ruta al código:
   ```env
   MOODLE_CODE_PATH=./moodle-code
   # o una ruta absoluta:
   # MOODLE_CODE_PATH=/opt/moodle-code
   ```
2. Activa el override de Docker Compose:
   ```bash
   cp docker-compose.override.yml.example docker-compose.override.yml
   ```
3. Asegúrate de que el directorio contenga el código de Moodle (por ejemplo, descargado desde [download.moodle.org](https://download.moodle.org)).
4. Levanta el stack (con o sin perfil `with-db` según tu configuración de DB):
   ```bash
   docker compose --profile with-db up -d
   # o sin DB interna:
   # docker compose up -d
   ```

> **Nota:** si el directorio indicado en `MOODLE_CODE_PATH` está vacío, el contenedor copiará automáticamente el código incluido en la imagen Docker al volumen montado.
>
> Para volver a usar el código empaquetado en la imagen, elimina o renombra `docker-compose.override.yml`.

La primera vez que arranca:
1. El `entrypoint.sh` instala Moodle automáticamente (`admin/cli/install.php`).
2. Luego ejecuta `init-scripts/init.sh`, que a su vez lanza `moodle.sh`, `plugins.sh`, `theme.sh` y `import_FPD_categories_and_courses.sh`.
3. Se crea el archivo `/var/www/moodledata/.moodle-installed` para no repetir la instalación en reinicios.

## Backups

```bash
chmod +x scripts/backup.sh
./scripts/backup.sh
```

Genera en `./backups/`:
- `backup_db_YYYYMMDD_HHMMSS.sql`
- `backup_moodledata_YYYYMMDD_HHMMSS.tar.gz`

## Actualizaciones (upgrade)

1. Actualiza el código en `moodle-code/`.
2. Cambia en `.env`:
   ```env
   INSTALL_TYPE=upgrade
   VERSION=4.1.x
   ```
3. Reconstruye y reinicia:
   ```bash
   docker compose up -d --build
   ```
4. Vuelve a poner `INSTALL_TYPE=new-install` cuando termine.

## Notas

- `moodle-data` se mantiene como **carpeta local** para facilitar backups y acceso directo.
- El código de Moodle puede ir **dentro de la imagen Docker** (despliegue reproducible) o montarse **desde el host** mediante la variable `MOODLE_CODE_PATH`.
- La base de datos puede ser el contenedor **MariaDB incluido** (perfil `with-db`) o una instancia **externa** ya existente.
- Los scripts de inicialización van dentro de la imagen para garantizar reproducibilidad.
