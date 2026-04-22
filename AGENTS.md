# AGENTS.md — Guía para agentes de código (AI)

> Este documento describe la arquitectura, convenciones y procesos del proyecto `new-moodle` (despliegue contenerizado de Moodle para FP Virtual Aragón — FPD). Está escrito en español porque todo el código, comentarios, documentación y scripts del proyecto usan español como idioma principal.

---

## Visión general del proyecto

`new-moodle` es un despliegue **Docker Compose** de **Moodle 4.1.x** orientado a la **Formación Profesional a Distancia de Aragón (FPD)**. A diferencia de despliegues genéricos de Moodle, este proyecto incluye scripts de inicialización específicos que crean categorías, cursos, roles, usuarios y configuraciones propias de los centros educativos de FP a distancia de Aragón.

El stack está diseñado para ser:
- **Reproducible**: el código de Moodle y los scripts de inicialización se empaquetan dentro de la imagen Docker.
- **Flexible**: permite usar una base de datos interna (perfil `with-db`) o externa, y permite montar el código de Moodle desde el host mediante `docker-compose.override.yml`.

---

## Stack tecnológico

| Componente | Tecnología | Versión / Imagen |
|------------|-----------|------------------|
| Contenedorización | Docker + Docker Compose | Compose v3.8 |
| Aplicación | Moodle (PHP) | 4.1.x |
| Procesador PHP | PHP-FPM | `php:8.1-fpm` (oficial) |
| Servidor web | Nginx | `nginx:latest` |
| Base de datos | MariaDB | `mariadb:10.6` (opcional, perfil `with-db`) |
| Caché / Sesiones | Redis | `redis:7-alpine` |
| Gestión CLI de Moodle | Moosh | instalado vía Composer + Git |
| Dependencias PHP | Composer | copiado desde imagen oficial |

Extensiones PHP instaladas en el Dockerfile:
`gd`, `mysqli`, `pdo_mysql`, `intl`, `mbstring`, `xml`, `zip`, `curl`, `exif`, `soap`, `opcache`, `ldap`, `redis` (vía pecl).

---

## Estructura de directorios

```
.
├── Dockerfile                          # Imagen propia basada en php:8.1-fpm
├── docker-compose.yml                  # Stack: db (opcional) + redis + moodle + nginx
├── docker-compose.override.yml.example # Override para montar código Moodle externo
├── .env.example                        # Plantilla de variables de entorno
├── entrypoint.sh                       # Entrypoint del contenedor moodle
├── README.md                           # Documentación general (español)
├── UPGRADE.md                          # Guía detallada de actualización de Moodle
├── Analisis-sistema.md                 # Análisis técnico del sistema (legacy/mixto)
│
├── nginx/
│   └── default.conf                    # Configuración de Nginx + PHP-FPM vía socket UNIX
│
├── php-conf/
│   ├── opcache.ini                     # Configuración de OPcache para Moodle
│   ├── uploads.ini                     # Límites de subida (192M), memoria (2G), etc.
│   └── zzz-disable-apcu.ini            # Desactiva APCu por estabilidad
│
├── fpm-conf/
│   ├── docker.conf                     # Ajustes de logging para Docker
│   ├── www.conf                        # Pool PHP-FPM (dynamic, max_children=100)
│   └── zz-docker.conf                  # Socket UNIX en /sock/docker.sock
│
├── init-scripts/
│   ├── init.sh                         # Orquestador: lanza scripts según INSTALL_TYPE
│   ├── new-install/
│   │   ├── moodle.sh                   # Configuración específica FPD del sitio
│   │   ├── plugins.sh                  # Instalación y configuración de plugins
│   │   ├── theme.sh                    # Tema Moove personalizado para FPD
│   │   └── import_FPD_categories_and_courses.sh  # Crea categorías, cursos, roles, cohortes
│   ├── upgrade/
│   │   ├── moodle.sh                   # Actualización de Moodle con expect
│   │   ├── plugins.sh                  # Reinstalación de plugins
│   │   └── theme.sh                    # Reaplicación del tema
│   └── themes/
│       ├── fpdist/                     # Assets del tema FPD (imágenes, SCSS, mustaches, roles, informes)
│       └── frontpage.mustache          # Plantilla personalizada de portada
│
├── scripts/
│   └── backup.sh                       # Backup coordinado: BD + moodle-data
│
├── moodle-code/                        # Código fuente de Moodle (se copia en la imagen)
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
   - Si `INSTALL_TYPE=new-install`, ejecuta `/init-scripts/init.sh`.
   - Crea el flag `/var/www/moodledata/.moodle-installed`.
5. **Si ya está instalado y `INSTALL_TYPE=upgrade`**:
   - Ejecuta `admin/cli/upgrade.php --non-interactive --allow-unstable`.
   - Ejecuta `/init-scripts/init.sh`.
6. **Purgar cachés** y arrancar `php-fpm`.

---

## Scripts de inicialización (`init-scripts/`)

### Orquestador (`init.sh`)
Ejecuta secuencialmente los scripts ubicados en `/init-scripts/${INSTALL_TYPE}/`:
1. `moodle.sh`
2. `plugins.sh`
3. `import_FPD_categories_and_courses.sh` (solo `new-install`)
4. `theme.sh`

Un script solo se ejecuta si tiene permiso de ejecución (`-x`). Si un script falla, el bucle continúa con el siguiente.

### `new-install/moodle.sh`
Configura el sitio Moodle mediante **Moosh**:
- Zona horaria, idioma (es), país (ES).
- SMTP, webservices, app móvil, notificaciones push (Airnotifier).
- Usuarios de prueba (`estudiante1`..`estudiante10`).
- Roles y permisos específicos (bloquear edición de nombres, evitar desmatriculaciones para profesores, etc.).
- Configuraciones de calificación, políticas de privacidad, analytics desactivado.

### `new-install/plugins.sh`
Descarga e instala plugins oficiales compatibles con la versión menor de Moodle (`VERSION_MINOR`):
`theme_moove`, `format_tiles`, `block_xp`, `availability_xp`, `local_mail`, `mod_board`, `mod_pdfannotator`, `block_grade_me`, `block_completion_progress`, `atto_fontsize`, `atto_fontfamily`, `atto_fullscreen`, `qtype_gapfill`, `mod_attendance`, `mod_checklist`, `block_configurable_reports`, `report_coursestats`, `quizaccess_onesession`, `mod_choicegroup`.

Incluye una función `actions_asociated_to_plugin` que configura cada plugin tras su instalación.

### `new-install/theme.sh`
- Activa el tema **Moove**.
- Importa los ajustes del tema desde un archivo `.tar.gz` empaquetado en la imagen.
- Copia estilos SCSS, mustaches personalizadas (`footer.mustache`, `frontpage.mustache`) y assets gráficos.
- Inyecta SCSS personalizado para ocultar elementos de la interfaz (CC, madeby, contact, etc.).

### `new-install/import_FPD_categories_and_courses.sh`
**Archivo crítico y altamente específico de FPD.** Crea:
- Usuarios: `admin2` (admin FPD), `profinspector` (rol inspección), múltiples usuarios de jefatura de estudios (`prof_je_*`).
- Roles personalizados: `inspeccion`, `jefatura-estudios` (con permisos importados desde XML).
- **Categorías fijas** para ~20 centros educativos (IES, CPIFP) con ciclos formativos.
- **Cohortes** por centro y ciclo.
- **Cursos** (~750 líneas en array `COURSES`): cada curso tiene `category*shortname*fullname*visible`.
  - Si existe un archivo `.mbz` en `/var/www/moodledata/repository/mbzs_curso_anterior/`, lo restaura.
  - Si no existe, crea un curso vacío.
- Matriculaciones automáticas de cohortes y jefaturas de estudios.

> **⚠️ Convención estricta**: los IDs de categorías y cursos deben mantenerse invariables entre despliegues. Si un curso desaparece, se cambia el `1` del final por `0`; los nuevos cursos se añaden al final del array, nunca en medio.

### `upgrade/`
Scripts simplificados para actualizaciones:
- `moodle.sh`: usa `expect` para automatizar la respuesta interactiva de `upgrade.php` y reaplica ajustes post-upgrade.
- `plugins.sh`: reinstala plugins (sin filtrado por versión).
- `theme.sh`: reaplica la configuración del tema Moove.

---

## Configuración y variables de entorno

Toda la configuración sensible y de entorno se define en **`.env`** (a partir de `.env.example`). Las variables más importantes:

| Variable | Propósito |
|----------|-----------|
| `MOODLE_DB_HOST` | Host de la BD (`db` si se usa el perfil `with-db`, o IP/hostname externo) |
| `MOODLE_DB_NAME`, `MOODLE_DB_USER`, `MOODLE_DB_PASSWORD` | Credenciales de la base de datos |
| `MYSQL_ROOT_PASSWORD` | Contraseña root de MariaDB (solo para perfil `with-db`) |
| `MOODLE_URL`, `VIRTUAL_HOST` | URL pública y dominio para el proxy inverso |
| `MOODLE_ADMIN_USER`, `MOODLE_ADMIN_PASSWORD`, `MOODLE_ADMIN_EMAIL` | Cuenta admin inicial |
| `MOODLE_LANG`, `MOODLE_SITE_NAME`, `MOODLE_SITE_FULLNAME` | Idioma y nombre del sitio |
| `SSL_PROXY`, `SSL_EMAIL` | Proxy SSL (Let's Encrypt) |
| `SMTP_HOSTS`, `SMTP_USER`, `SMTP_PASSWORD`, `NO_REPLY_ADDRESS` | Configuración de correo |
| `INSTALL_TYPE` | `new-install` o `upgrade` |
| `VERSION` | Versión de Moodle (ej. `4.1.19`), usada para filtrar plugins |
| `MOODLE_CODE_PATH` | Ruta al código Moodle en el host (para override) |
| `FPD_PASSWORD`, `FPD_EMAIL`, `MANAGER_PASSWORD` | Credenciales específicas de usuarios FPD |
| `APP_PASSWORD`, `APP_TEACHER_PASSWORD` | Credenciales para la app móvil de demo |
| `BLACKBOARD_URL`, `BLACKBOARD_KEY`, `BLACKBOARD_SECRET` | Integración con Blackboard |

---

## Comandos de build y despliegue

### Stack completo (BD interna + código en imagen)
```bash
# 1. Preparar entorno
cp .env.example .env
# Editar .env con los valores reales

# 2. Crear red externa del proxy (requerida)
docker network create nginx-proxy_frontend

# 3. Construir y levantar
docker compose build
docker compose --profile with-db up -d

# 4. Seguir logs
docker compose logs -f moodle
```

### Con base de datos externa (sin perfil `with-db`)
```bash
docker compose up -d
```

### Con código Moodle externo (desarrollo)
```bash
# En .env:
# MOODLE_CODE_PATH=./moodle-code

cp docker-compose.override.yml.example docker-compose.override.yml
docker compose --profile with-db up -d
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

Documentado detalladamente en `UPGRADE.md`. Pasos clave:

1. **Hacer backup** con `scripts/backup.sh`.
2. Poner Moodle en modo mantenimiento: `docker compose exec moodle moosh -n maintenance-on`.
3. Actualizar el código en `moodle-code/`.
4. Verificar compatibilidad de plugins y actualizar scripts de `init-scripts/upgrade/` si es necesario.
5. Actualizar `VERSION` en `.env`.
6. Cambiar `INSTALL_TYPE=upgrade` en `.env`.
7. Reconstruir y reiniciar: `docker compose up -d --build`.
8. Seguir logs: `docker compose logs -f moodle`.
9. Una vez estable, volver a `INSTALL_TYPE=new-install`.
10. Quitar modo mantenimiento y purgar cachés.

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
- **Bind mounts**: `moodle-data/` se mantiene como carpeta local para facilitar backups. El código puede ir dentro de la imagen (más seguro/reproducible) o montarse desde host (menos seguro, solo para desarrollo).
- **Backups**: el script de backup requiere que las variables `MYSQL_ROOT_PASSWORD` y `MOODLE_DB_NAME` estén disponibles en el entorno desde el que se ejecuta.

---

## Testing y verificación

No hay suite de tests unitarios/integración automatizados. Las verificaciones manuales recomendadas son:

- Tras una instalación nueva, acceder a `https://<VIRTUAL_HOST>/admin/index.php` y revisar notificaciones.
- Tras un upgrade, ejecutar:
  ```bash
  docker compose exec moodle php /var/www/html/admin/cli/check_database_schema.php
  docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php
  ```
- Revisar que los plugins críticos funcionen: `format_tiles`, `theme_moove`, `local_mail`, `mod_board`.

---

## Notas para el mantenimiento

- **IDs inmutables**: en `import_FPD_categories_and_courses.sh`, los IDs de categorías y cursos son críticos para la app móvil y automatizaciones. No reordenar el array `COURSES`.
- **Moosh plugin-list**: los scripts de `new-install` filtran plugins por `VERSION_MINOR`. Si Moodle se actualiza a una nueva versión menor (ej. 4.1 → 4.2), asegurarse de que todos los plugins tengan versión compatible antes de desplegar.
- **Expect en upgrade**: `upgrade/moodle.sh` usa `expect` para responder automáticamente al prompt de `upgrade.php`. Si el CLI de Moodle cambia su texto interactivo, el script de expect podría fallar.
- **Override file**: `docker-compose.override.yml` se carga automáticamente. Para volver al código empaquetado en la imagen, basta con eliminar o renombrar este archivo.
