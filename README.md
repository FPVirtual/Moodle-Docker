# new-moodle - Despliegue contenerizado de FP Virtual / Distancia (FPD)

Este proyecto es una versión modernizada y autocontenida del despliegue de Moodle para **FP Virtual Aragón (FPD)**, utilizando **imágenes oficiales de Docker** (`php:8.2-apache`, `mariadb`, `redis`).

## Diferencias clave respecto al proyecto anterior

| Aspecto | Proyecto anterior | `new-moodle` (rama apache-moodle) |
|---------|-------------------|-----------------------------------|
| Imagen Moodle | `php:8.1-fpm` + nginx separado | `php:8.2-apache` (mod_php integrado) |
| Base de datos | Externa (no definida en compose) | MariaDB **opcional** en `docker-compose.yml` (perfil `with-db`) o **externa** configurable |
| Código Moodle | Bind mount (`./moodle-code`) o copiado del host | Descargado desde GitHub releases durante el build |
| Plugins | Hardcoded en Dockerfile o copiados | Catálogo `plugins.json` + `docker-clone-plugins.sh` |
| Datos (`moodle-data`) | Bind mount | **Mantiene bind mount** para facilitar backups |
| Datos de inicialización | Dentro de `init-scripts/` (copiados en imagen) | Volumen `./init-data/` (CSV + backups `.mbz`) fuera de la imagen |
| Gestión usuarios | Hardcodeado en scripts | CSV en `./init-data/data/` + `load_usuarios.sh` |
| Scripts init | Genéricos para varios tipos de centro | **Específicos para FPD** (simplificados) |
| Puerto host | Hardcodeado a `8087` | Parametrizado via `MOODLE_HOST_PORT` (default `8080`) |

## Estructura

```
new-moodle/
├── Dockerfile                          # Imagen propia basada en php:8.2-apache
├── docker-compose.yml                  # Stack: db (opcional) + redis + moodle
├── docker-compose.override.yml.example # Override para montar código Moodle externo
├── .env.example                        # Plantilla de variables de entorno
├── entrypoint.sh                       # Entrypoint que instala/configura Moodle
├── plugins.json                        # Catálogo maestro de plugins de terceros
├── apache-conf/
│   └── 000-default.conf                # Configuración de Apache VirtualHost
├── php-conf/                           # Configuraciones PHP (uploads, opcache...)
├── init-scripts/
│   ├── init.sh                         # Orquestador
│   ├── lib/
│   │   ├── docker-clone-plugins.sh    # Clona plugins en build-time
│   │   └── plugins-lib.sh             # Helpers bash para leer plugins.json
│   ├── new-install/
│   │   ├── moodle.sh                   # Configuración específica FPD
│   │   ├── plugins.sh                  # Instalación de plugins desde plugins.json
│   │   ├── theme.sh                    # Tema Moove personalizado FPD
│   │   ├── import_FPD_categories_and_courses.sh
│   │   └── load_usuarios.sh            # Carga usuarios desde CSV
│   └── upgrade/
│       ├── moodle.sh
│       ├── plugins.sh
│       └── theme.sh
├── init-data/                          # Datos de inicialización (volumen montado)
│   ├── data/                           # CSV de usuarios, cursos, categorías, cohortes, jefaturas
│   └── mbzs/                           # Backups .mbz para restauración de cursos
├── custom/                             # Scripts PHP custom (copiados a /var/www/html)
│   ├── decalogo/
│   ├── faqs/
│   ├── private-reports/
│   ├── soporte/
│   └── userpix/
├── moodle-data/                        # Datos de Moodle (bind mount)
└── scripts/
    └── backup.sh                       # Backup coordinado BD + moodle-data
```

## Requisitos previos

1. Docker y Docker Compose instalados.
2. Red externa creada (si usas BD externa o proxy inverso):
   ```bash
   docker network create moodle_network
   ```
3. Copiar y personalizar el archivo de entorno:
   ```bash
   cp .env.example .env
   # Edita .env con los valores reales (dominio, contraseñas, plugins, etc.)
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

### Con código Moodle externo (desarrollo)

Si prefieres montar el código de Moodle desde el host (útil para desarrollo):

1. En `.env`, define la ruta al código:
   ```env
   MOODLE_CODE_PATH=./moodle-code
   ```
2. Activa el override de Docker Compose:
   ```bash
   cp docker-compose.override.yml.example docker-compose.override.yml
   ```
3. Asegúrate de que el directorio contenga el código de Moodle.
4. Levanta el stack:
   ```bash
   docker compose up -d
   ```

> **Nota:** si el directorio de `MOODLE_CODE_PATH` está vacío, el contenedor copia automáticamente el código de la imagen Docker al volumen montado.
>
> Para volver a usar el código empaquetado en la imagen, elimina o renombra `docker-compose.override.yml`.

La primera vez que arranca:
1. El `entrypoint.sh` genera `config.php` automáticamente desde variables de entorno.
2. Instala Moodle (`admin/cli/install_database.php`) si la BD está vacía.
3. Ejecuta `init-scripts/init.sh`, que lanza `moodle.sh`, `plugins.sh`, `theme.sh`, `import_FPD_categories_and_courses.sh` y `load_usuarios.sh`.
4. Se crea el archivo `/var/www/moodledata/.moodle-installed` para no repetir la instalación en reinicios.

> **Nota sobre `init-data/`**: Antes del primer arranque, asegúrate de que exista `./init-data/data/` (con los CSV) y, si tienes backups, `./init-data/mbzs/` (con los archivos `.mbz`). Estos directorios se montan como volumen de solo lectura; no se empaquetan en la imagen Docker.

## Plugins de terceros

Los plugins se definen en `plugins.json` y se clonan durante el build de la imagen.

Para habilitar/deshabilitar plugins en runtime, usa variables `PLUGIN_*` en `.env`:

```env
PLUGIN_THEME_MOOVE=true
PLUGIN_BLOCK_CONFIGURABLE_REPORTS=false
# PLUGIN_MOD_JITSI=false
```

Ver `plugins.json` para el listado completo con descripciones y advertencias.

## Backups

```bash
chmod +x scripts/backup.sh
./scripts/backup.sh
```

Genera en `./backups/`:
- `backup_db_YYYYMMDD_HHMMSS.sql`
- `backup_moodledata_YYYYMMDD_HHMMSS.tar.gz`

## Actualizaciones (upgrade)

1. Actualiza `MOODLE_VERSION` en el `Dockerfile`.
2. Actualiza ramas de plugins en `plugins.json` si es necesario.
3. Cambia en `.env`:
   ```env
   INSTALL_TYPE=upgrade
   VERSION=4.5.x
   ```
4. Reconstruye y reinicia:
   ```bash
   docker compose up -d --build
   ```
5. Vuelve a poner `INSTALL_TYPE=new-install` cuando termine.

> **Regla de oro**: nunca saltar más de una versión mayor de Moodle a la vez (ej. 4.5 → 4.6 → 4.7).

## Notas

- `moodle-data` se mantiene como **carpeta local** para facilitar backups y acceso directo.
- `init-data` también es una **carpeta local** montada como volumen; contiene CSV y backups `.mbz` (no se incluyen en la imagen).
- El código de Moodle va **dentro de la imagen Docker** (despliegue reproducible). Para desarrollo se puede montar desde el host.
- La base de datos puede ser el contenedor **MariaDB incluido** (perfil `with-db`) o una instancia **externa** ya existente.
- Los scripts de inicialización van dentro de la imagen para garantizar reproducibilidad.
- Apache escucha en el puerto 80 del contenedor. El puerto del host se define en `.env` mediante `MOODLE_HOST_PORT` (por defecto `8080`).
