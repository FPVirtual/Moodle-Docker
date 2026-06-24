# AGENTS.md — Guía para agentes de código (AI)

> Este documento describe la arquitectura, convenciones y procesos del proyecto `new-moodle` (despliegue contenerizado de Moodle para FP Virtual Aragón — FPD). Está escrito en español porque todo el código, comentarios, documentación y scripts del proyecto usan español como idioma principal.

---

## Visión general del proyecto

`new-moodle` es un despliegue **Docker Compose** de **Moodle 4.5.x** orientado a la **Formación Profesional a Distancia de Aragón (FPD)**. A diferencia de despliegues genéricos de Moodle, este proyecto incluye scripts de inicialización específicos que crean categorías, cursos, roles, usuarios y configuraciones propias de los centros educativos de FP a distancia de Aragón.

> **Estado actual (mayo 2026)**: La rama activa es `apache-moodle`. El stack ha sido migrado de **nginx + php-fpm** a **Apache + mod_php**, Moodle actualizado a **4.5.11** y PHP a **8.2**. Los plugins se gestionan mediante el catálogo `plugins.json`. Ver `Analisis-sistema.md`, `Estudio-moodle-code-to-container.md` y `RAMA-apache-moodle.md` para el detalle completo de decisiones.

El stack está diseñado para ser:
- **Reproducible**: el código de Moodle y los scripts de inicialización se empaquetan dentro de la imagen Docker.
- **Flexible**: permite usar una base de datos interna (perfil `with-db`) o externa, y permite montar el código de Moodle desde el host mediante `docker-compose.override.yml`.

---

## Stack tecnológico

| Componente | Tecnología | Versión / Imagen |
|------------|-----------|------------------|
| Contenedorización | Docker + Docker Compose | Compose v3.8 |
| Aplicación | Moodle (PHP) | 4.5.x |
| Procesador PHP | mod_php (Apache) | `php:8.2-apache` (oficial) |
| Servidor web | Apache | Incluido en `php:8.2-apache` |
| Base de datos | MariaDB | Externa (actualmente `mariadb:10.11.16` en red Docker). El perfil `with-db` (`mariadb:10.6`) sigue disponible pero no se usa en este despliegue. |
| Caché / Sesiones | Redis | `redis:7-alpine` |
| Gestión CLI de Moodle | Moosh | instalado vía Composer + Git |
| Dependencias PHP | Composer | copiado desde imagen oficial |

Extensiones PHP instaladas en el Dockerfile:
`gd`, `mysqli`, `pdo_mysql`, `intl`, `mbstring`, `xml`, `zip`, `curl`, `exif`, `soap`, `opcache`, `ldap`, `redis` (vía pecl).

---

## Estructura de directorios

```
.
├── Dockerfile                          # Imagen propia basada en php:8.2-apache
├── docker-compose.yml                  # Stack: db (opcional) + redis + moodle
├── docker-compose.override.yml.example # Override para montar código Moodle externo
├── .env.example                        # Plantilla de variables de entorno
├── entrypoint.sh                       # Entrypoint del contenedor moodle
├── README.md                           # Documentación general (español)
├── UPGRADE.md                          # Guía detallada de actualización de Moodle
├── Analisis-sistema.md                 # Análisis técnico del sistema (legacy/mixto)
│
├── apache-conf/
│   └── 000-default.conf                # Configuración de Apache VirtualHost + mod_php
│
├── php-conf/
│   ├── opcache.ini                     # Configuración de OPcache para Moodle
│   ├── uploads.ini                     # Límites de subida (192M), memoria (2G), etc.
│   └── zzz-disable-apcu.ini            # Desactiva APCu por estabilidad
│
├── init-scripts/
│   ├── init.sh                         # Orquestador: lanza scripts de new-install
│   ├── lib/
│   │   ├── docker-clone-plugins.sh    # Clona plugins en build-time desde init-data/plugins.json
│   │   └── plugins-lib.sh             # Helpers bash para leer init-data/plugins.json en runtime
│   ├── new-install/
│   │   ├── moodle.sh                         # Configuración específica FPVirtual del sitio
│   │   ├── plugins.sh                        # Instalación y configuración de plugins
│   │   ├── api_config.sh                     # Configura webservice REST y token API
│   │   ├── import_FPVirtual_categories_and_courses.sh  # Crea categorías, cursos, roles, cohortes
│   │   ├── load_usuarios.sh                  # Carga usuarios desde CSV
│   │   ├── test_data.sh                      # Datos de test condicionales (ver ENABLE_TEST_DATA)
│   │   ├── api_service_setup.php             # Script PHP auxiliar para crear servicio/token API
│   │   └── data/
│   │       ├── usuarios.csv                  # Usuarios iniciales (prod + estudiantes)
│   │       └── usuarios_test.csv             # Usuarios exclusivos de test (prof_cd_daw, demoapp, etc.)
│   └── themes/
│       ├── fpdist/                     # Assets del tema FPD (imágenes, SCSS, mustaches, roles, informes)
│       └── frontpage.mustache          # Plantilla personalizada de portada
│
├── custom/                             # Scripts PHP custom (copiados a /var/www/html)
│   ├── decalogo/
│   ├── faqs/
│   ├── private-reports/
│   ├── soporte/
│   └── userpix/
│
├── scripts/
│   └── backup.sh                       # Backup coordinado: BD + moodle-data
│
├── init-data/plugins.json              # Catálogo maestro de plugins de terceros (editable en runtime)
└── moodle-data/                        # Datos de Moodle (bind mount, persistencia local)
```

---

## Flujo de arranque (entrypoint)

El `entrypoint.sh` del contenedor `moodle` ejecuta el siguiente flujo en cada arranque:

1. **Restaurar código si el bind mount está vacío**: si `/var/www/html/config.php` no existe pero existe `/usr/src/moodle/config-dist.php`, copia el código empaquetado en la imagen a `/var/www/html`.
2. **Esperar a la base de datos**: bucle hasta que la BD responda.
3. **Comprobar si Moodle ya está instalado**: consulta si existe la tabla `mdl_config`.
4. **Si no está instalado**:
   - Ejecuta `admin/cli/install_database.php` (instalación no interactiva).
   - Ejecuta `/init-scripts/init.sh`.
   - Crea el flag `/var/www/moodledata/.moodle-installed`.
5. **Si ya está instalado**:
   - No se ejecutan scripts de personalización (cada instancia es una nueva instalación).
6. **Purgar cachés** y arrancar `apache2-foreground`.

---

## Scripts de inicialización (`init-scripts/`)

### Orquestador (`init.sh`)
Ejecuta secuencialmente los scripts ubicados en `/init-scripts/new-install/`:
1. `moodle.sh`
2. `plugins.sh`
3. `api_config.sh`
4. `import_FPVirtual_categories_and_courses.sh`
5. `theme.sh`
6. `test_data.sh` (solo `new-install`, condicional a `ENABLE_TEST_DATA=true`)

Un script solo se ejecuta si tiene permiso de ejecución (`-x`). Si un script falla, el bucle continúa con el siguiente.

### `new-install/moodle.sh`
Configura el sitio Moodle mediante **Moosh**:
- Zona horaria, idioma (es), país (ES).
- SMTP, webservices, app móvil, notificaciones push (Airnotifier).
- Usuarios desde CSV (`load_usuarios.sh` + `data/usuarios.csv`).
- Roles y permisos específicos (bloquear edición de nombres, evitar desmatriculaciones para profesores, etc.).
- Configuraciones de calificación, políticas de privacidad, analytics desactivado.

### `new-install/plugins.sh`
Instala y configura plugins de terceros leyendo el catálogo desde **`/init-data/plugins.json`** (o, como fallback en build-time, `/init-scripts/plugins.json`) y filtrando por las variables de entorno **`PLUGIN_*`** definidas en `.env`.

Incluye la configuración automática del plugin `local_educaaragon`: mediante el script `educaaragon_setup.php` se crea (si no existe) un repositorio filesystem apuntando a `moodledata/repository/recursos-editables` y se configura el plugin para utilizarlo.

Plugins disponibles (habilitados por defecto según `default_enabled` del JSON):
`theme_moove`, `format_tiles`, `block_xp`, `availability_xp`, `local_mail`, `mod_board`, `mod_pdfannotator`, `block_grade_me`, `block_completion_progress`, `atto_fontsize`, `atto_fontfamily`, `atto_fullscreen`, `qtype_gapfill`, `mod_attendance`, `mod_checklist`, `quizaccess_onesession`, `mod_choicegroup`.

Plugins opcionales / deshabilitados por defecto:
`block_configurable_reports`, `report_coursestats`, `mod_jitsi`, `block_sharing_cart`, `local_reminders`, `atto_c4l`, `mod_googlemeet`.

Incluye una función `actions_asociated_to_plugin` que configura cada plugin tras su instalación. Los helpers para leer el JSON están en `init-scripts/lib/plugins-lib.sh`.

### `new-install/theme.sh`
- Activa el tema **Moove**.
- Importa los ajustes del tema desde un archivo `.tar.gz` empaquetado en la imagen.
- Copia estilos SCSS, mustaches personalizadas (`footer.mustache`, `frontpage.mustache`) y assets gráficos.
- Inyecta SCSS personalizado para ocultar elementos de la interfaz (CC, madeby, contact, etc.).

### `new-install/import_FPVirtual_categories_and_courses.sh`
**Archivo crítico y altamente específico de FPVirtual.** Crea:
- Roles personalizados: `inspeccion`, `jefatura-estudios` (con permisos importados desde XML).
- **Categorías fijas** para ~20 centros educativos (IES, CPIFP) con ciclos formativos.
- **Cohortes** por centro y ciclo.
- **Cursos** (~750 líneas en array `COURSES`): cada curso tiene `category*shortname*fullname*visible`.
  - Si existe un archivo `.mbz` en `/var/www/moodledata/repository/mbzs_curso_anterior/`, lo restaura.
  - Si no existe, crea un curso vacío.
- Matriculaciones automáticas de cohortes y jefaturas de estudios (vía array asociativo `JEFATURA_USER_IDS`).

Los usuarios de jefatura de estudios y el usuario `profinspector` se crean ahora en `load_usuarios.sh` (CSV `usuarios.csv`). Los usuarios de test (`prof_cd_daw`, `demoapp`, `profesor1`) se han movido a `test_data.sh`.

> **⚠️ Convención estricta**: los IDs de categorías y cursos deben mantenerse invariables entre despliegues. Si un curso desaparece, se cambia el `1` del final por `0`; los nuevos cursos se añaden al final del array, nunca en medio.

### `new-install/api_config.sh`
Configura la API REST de Moodle para integración externa (app móvil, sistemas de gestión):
- Activa webservices y protocolo REST (`moosh config-set`).
- Crea el rol `integracion_api` con capacidades mínimas requeridas (`moosh role-create`, `role-update-capability`).
- Asigna el rol al usuario `moodle-api` (`moosh user-assign-system-role`).
- Delega la creación del servicio externo, funciones y token al script PHP `api_service_setup.php` (evita bug de `moosh sql-run` con parámetros con dos puntos).

### `new-install/test_data.sh`
Script condicional que solo se ejecuta si `ENABLE_TEST_DATA=true` (nunca en producción). Carga:
- Usuarios desde `usuarios_test.csv` (`prof_cd_daw`, `demoapp`, `profesor1`, etc.).
- Matriculaciones de test desde `matriculaciones_test.csv`.
- Matricula `prof_cd_daw` automáticamente en todos los cursos de la categoría `cd_daw`.
- Crea usuarios `demoapp` y `profesor1` para el curso de marketplaces si está habilitado.

---

## Configuración y variables de entorno

Toda la configuración sensible y de entorno se define en **`.env`** (a partir de `.env.example`). Las variables más importantes:

| Variable | Propósito |
|----------|-----------|
| `MOODLE_DB_HOST` | Host de la BD (`db` si se usa el perfil `with-db`, o IP/hostname externo) |
| `MOODLE_DB_NAME`, `MOODLE_DB_USER`, `MOODLE_DB_PASSWORD` | Credenciales de la base de datos |
| `MYSQL_ROOT_PASSWORD` | Contraseña root de MariaDB (solo para perfil `with-db`; actualmente se usa BD externa) |
| `MOODLE_URL`, `VIRTUAL_HOST` | URL pública y dominio para el proxy inverso |
| `MOODLE_ADMIN_USER`, `MOODLE_ADMIN_PASSWORD`, `MOODLE_ADMIN_EMAIL` | Cuenta admin inicial |
| `MOODLE_LANG`, `MOODLE_SITE_NAME`, `MOODLE_SITE_FULLNAME` | Idioma y nombre del sitio |
| `SSL_PROXY`, `SSL_EMAIL` | Proxy SSL (Let's Encrypt) |
| `SMTP_HOSTS`, `SMTP_USER`, `SMTP_PASSWORD`, `NO_REPLY_ADDRESS` | Configuración de correo |
| `MOODLE_VERSION` | Versión de Moodle (ej. `4.5.11`), usada para descargar el código y filtrar plugins |
| `MOODLE_DB_PORT` | Puerto de la base de datos (ej. `3306` para red Docker, o `3316` si se expone al host) |
| `PLUGIN_<NAME>` | Habilita (`true`) o deshabilita (`false`) un plugin del catálogo. Ver `.env.example` |

---

## Catálogo de plugins (`init-data/plugins.json`)

El archivo `init-data/plugins.json` (copiado a `/init-scripts/plugins.json` en la imagen durante el build, pero sobreescribible en runtime mediante el bind mount de `init-data`) define:
- Nombre del componente (`name`, `component`).
- Categoría y descripción.
- Ruta de instalación en Moodle (`moodle_path`).
- URL del repositorio git (`git_url`, `git_branch`).
- Valor por defecto de habilitación (`default_enabled`).
- Si requiere acciones post-instalación (`has_postinstall_actions`).
- Advertencias de deprecación u obsolescencia (`warning`).

Las variables de entorno `PLUGIN_<NOMBRE_EN_MAYUSCULAS>` en `.env` sobreescriben `default_enabled`. Si una variable no está definida, se usa el valor del JSON. Comentar una línea en `.env` equivale a dejar que el JSON decida.

| `FPD_PASSWORD`, `FPD_EMAIL`, `MANAGER_PASSWORD` | Credenciales específicas de usuarios FPVirtual |
| `APP_PASSWORD`, `APP_TEACHER_PASSWORD` | Credenciales para la app móvil de demo |
| `API_USER_PASSWORD` | Contraseña del usuario `moodle-api` para integración REST |
| `ENABLE_TEST_DATA` | `true` para cargar datos de test (`test_data.sh`). **Nunca en producción.** |

---

## Comandos de build y despliegue

### Despliegue actual (BD externa + código en imagen)
```bash
# 1. Preparar entorno
cp .env.example .env
# Editar .env con los valores reales (ver .env del despliegue actual como referencia)

# 2. Crear red externa del proxy (requerida)
docker network create nginx-proxy_frontend

# 3. Construir y levantar (sin perfil with-db)
docker compose up -d --build

# 5. Seguir logs
docker compose logs -f moodle
```

### Con base de datos interna (perfil `with-db` — no usado actualmente)
```bash
docker compose --profile with-db up -d
```

### Con código Moodle externo (desarrollo)
```bash
# En .env:
# MOODLE_CODE_PATH=./moodle-code

cp docker-compose.override.yml.example docker-compose.override.yml
docker compose up -d
```

> Nota: si el directorio de `MOODLE_CODE_PATH` está vacío, el contenedor copia automáticamente el código de la imagen al volumen montado.

---

## Backup y restauración

### Backup coordinado
```bash
chmod +x scripts/backup.sh
./scripts/backup.sh [ruta_destino]
```

Genera en `./backups/` (o la ruta indicada):
- `backup_db_YYYYMMDD_HHMMSS.sql`
- `backup_moodledata_YYYYMMDD_HHMMSS.tar.gz`

El script:
1. Activa modo mantenimiento con `moosh`.
2. Vuelca la base de datos con `mysqldump`.
3. Comprime `moodle-data/`.
4. Desactiva modo mantenimiento.

### Restauración (rollback)
Ver `UPGRADE.md` para el procedimiento completo. En resumen:
1. Modo mantenimiento on.
2. Restaurar dump SQL en la BD.
3. Descomprimir `backup_moodledata_*.tar.gz` sobre `moodle-data/`.
4. (Opcional) Restaurar código anterior en `moodle-code/`.
5. Reconstruir imagen y reiniciar.
6. Quitar modo mantenimiento.

---

## Proceso de upgrade de Moodle

Como cada instancia es una nueva instalación, el upgrade no se hace in-place sobre un contenedor existente. En su lugar:

1. **Hacer backup** con `scripts/backup.sh`.
2. Actualizar `MOODLE_VERSION` en el `Dockerfile` y `.env`.
3. Verificar compatibilidad de plugins en `init-data/plugins.json`.
4. Reconstruir la imagen y desplegar una **nueva instancia** sobre una BD limpia o restaurada.
5. Seguir logs: `docker compose logs -f moodle`.

> **Regla de oro**: nunca saltar más de una versión mayor de Moodle a la vez (ej. 4.1 → 4.2 → 4.3).

---

## Convenciones de código y estilo

- **Idioma**: todos los scripts, comentarios, nombres de variables descriptivas y documentación están en **español**.
- **Shell scripts**: usan `#!/bin/bash` con `set -e` (o `set -euo pipefail` en `backup.sh`).
- **Indentación**: mezcla de tabs y espacios en scripts legacy; se prefiere consistencia local dentro de cada archivo.
- **Moosh**: es la herramienta estándar para cualquier modificación de configuración, instalación de plugins, creación de usuarios/cursos/categorías.
- **Variables de entorno**: se propagan desde `.env` → `docker-compose.yml` → contenedor `moodle`.
- **Permisos**: los scripts deben tener permiso de ejecución (`chmod +x`) para que el orquestador `init.sh` los ejecute.

---

## Consideraciones de seguridad

- **APCu desactivado** (`zzz-disable-apcu.ini`) por inestabilidad en Moodle.
- **No se usa ionCube Loader** (omitido en Dockerfile para mantener la imagen limpia).
- **Credenciales**: nunca commitear el archivo `.env` (está en `.gitignore`). Usar siempre `.env.example` como plantilla.
- **SSL**: el tráfico HTTPS lo gestiona un proxy inverso externo (p. ej. `nginx-proxy`) conectado a la red `nginx-proxy_frontend`.
- **Bind mounts**: `moodle-data/` se mantiene como volumen para persistencia. En el despliegue actual apunta al directorio del contenedor anterior (`/var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-data`). **Nunca levantar dos contenedores simultáneamente sobre el mismo `moodle-data`**; Moodle no soporta dataroot compartido entre instancias activas. El código puede ir dentro de la imagen (más seguro/reproducible) o montarse desde host (menos seguro, solo para desarrollo).
- **Plugin local_educaaragon**: el directorio `recursos-editables/` del host se monta dentro del contenedor en `/var/www/moodledata/repository/recursos-editables` (vía variable `EDUCAARAGON_RESOURCES_PATH`). El script `educaaragon_setup.php` crea automáticamente el repositorio filesystem y configura el plugin durante la inicialización.
  > **⚠️ Importante**: no crear enlaces simbólicos absolutos dentro de `moodle-data/repository/`. Docker monta symlinks tal cual; una ruta absoluta del host no existirá dentro del contenedor. Usar siempre el bind mount del `docker-compose.yml`.
- **Backups**: el script de backup requiere que las variables `MYSQL_ROOT_PASSWORD` y `MOODLE_DB_NAME` estén disponibles en el entorno desde el que se ejecuta.

---

## Testing y verificación

No hay suite de tests unitarios/integración automatizados. Las verificaciones manuales recomendadas son:

- Tras una instalación nueva, acceder a `https://<VIRTUAL_HOST>/admin/index.php` y revisar notificaciones.
- Tras una instalación nueva, ejecutar:
  ```bash
  docker compose exec moodle php /var/www/html/admin/cli/check_database_schema.php
  docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php
  ```
- Revisar que los plugins críticos funcionen: `format_tiles`, `theme_moove`, `local_mail`, `mod_board`.

---

## Notas para el mantenimiento

- **IDs inmutables**: en `import_FPVirtual_categories_and_courses.sh`, los IDs de categorías y cursos son críticos para la app móvil y automatizaciones. No reordenar el array `COURSES`.
- **Moosh plugin-list**: los scripts de `new-install` filtran plugins por `VERSION_MINOR` extraída de `MOODLE_VERSION`. Si Moodle se actualiza a una nueva versión menor (ej. 4.1 → 4.2), asegurarse de que todos los plugins tengan versión compatible antes de desplegar.
- **Plugins JSON**: al añadir un plugin nuevo, incluirlo en `init-data/plugins.json` y en `.env.example`. Reconstruir la imagen para que el JSON se copie a `/init-scripts/`; si solo se modifican habilitaciones/deshabilitaciones en runtime, basta con editar `init-data/plugins.json` y reiniciar el contenedor.

- **Volumen compartido moodle-data**: en despliegues de migración el `moodle-data` puede compartirse temporalmente con el contenedor anterior. Asegurarse siempre de que el contenedor anterior esté apagado antes de levantar el nuevo. Moodle no soporta dataroot compartido entre instancias activas.
- **Override file**: `docker-compose.override.yml` se carga automáticamente. Para volver al código empaquetado en la imagen, basta con eliminar o renombrar este archivo.
- **Imagen base**: `php:8.2-apache` usa Debian Bookworm. El paquete `libaio1` fue eliminado del `Dockerfile` porque no es necesario para MariaDB.
- **Plugins en imagen**: los plugins se clonan desde git durante el build usando `init-data/plugins.json` y `docker-clone-plugins.sh`. No requieren `moodle-code/` en el host.
