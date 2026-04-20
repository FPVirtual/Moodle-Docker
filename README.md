# new-moodle - Despliegue contenerizado de FP Virtual / Distancia (FPD)

Este proyecto es una versión modernizada y autocontenida del despliegue de Moodle para **FP Virtual Aragón (FPD)**, utilizando **imágenes oficiales de Docker** (`php:8.1-fpm`, `nginx`, `mariadb`, `redis`).

## Diferencias clave respecto al proyecto anterior

| Aspecto | Proyecto anterior | `new-moodle` |
|---------|-------------------|--------------|
| Imagen Moodle | `cateduac/moodle:4.1.3-nginx-fpm-unoconv` (personalizada) | `php:8.1-fpm` oficial + Dockerfile propio |
| Base de datos | Externa (no definida en compose) | MariaDB 10.6 incluida en `docker-compose.yml` |
| Código Moodle | Bind mount (`./moodle-code`) | Empaquetado dentro de la imagen Docker |
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
3. Personalizar el archivo `.env` con los valores reales (dominio, contraseñas, etc.).

## Puesta en marcha

```bash
cd new-moodle

# 1. Construir la imagen
docker compose build

# 2. Levantar el entorno
docker compose up -d

# 3. Seguir los logs (la instalación inicial puede tardar varios minutos)
docker compose logs -f moodle
```

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
- El código de Moodle y los scripts de inicialización van **dentro de la imagen Docker**, haciendo el despliegue reproducible en cualquier servidor.
