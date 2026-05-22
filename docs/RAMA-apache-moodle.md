# Rama `apache-moodle` — Documento de trabajo

> Fecha de creación: 2026-05-15
> Estado: En desarrollo / Testing
> Rama Git: `apache-moodle` (creada desde `creacion_moodle-data_propio`)

---

## 1. Objetivo

Migrar el stack Docker de **nginx + php-fpm** a **Apache + mod_php**, actualizar Moodle a **4.5.11** y consolidar la gestión de plugins mediante un catálogo JSON (`plugins.json`).

Esta rama evoluciona el trabajo de `creacion_moodle-data_propio` (imagen autocontenida) añadiendo:
- Simplificación del stack (elimina contenedor nginx).
- Actualización de Moodle core y plugins a versiones 4.5 compatibles.
- Sistema de gestión de plugins centralizado en `plugins.json`.
- Carga de usuarios desde CSV.

---

## 2. ¿Qué problema resuelve?

### Situación anterior (rama `creacion_moodle-data_propio`)
- Stack con nginx + PHP-FPM (2 contenedores para servir PHP).
- Moodle 4.1.19 (versión anterior).
- Plugins clonados con `git clone` hardcoded en el Dockerfile.
- Usuarios hardcodeados en scripts de shell.

### Situación deseada (esta rama)
- **Apache + mod_php**: un solo contenedor para servidor web y PHP.
- **Moodle 4.5.11**: versión LTS actual.
- **PHP 8.2**: versión recomendada para Moodle 4.5.
- **`plugins.json`**: catálogo maestro de plugins con metadatos y control vía variables de entorno.
- **CSV de usuarios**: datos separados de la lógica de scripts.

---

## 3. Arquitectura

```
┌──────────────────────────────────────────────────────────────┐
│  Imagen Docker (build)                                       │
│  ──────────────────────────────────────────────────────────  │
│  • Moodle 4.5.11 (descargado desde GitHub releases)          │
│  • 23 plugins de terceros (clonados desde git vía            │
│    plugins.json + docker-clone-plugins.sh)                   │
│  • Scripts PHP custom (custom/decalogo, faqs, etc.)          │
│  • init-scripts (new-install + upgrade)                      │
│  • Tema FPD (assets, SCSS, mustaches)                        │
│  • Apache 2.4 + mod_php (php:8.2-apache)                     │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│  Contenedor (runtime) — INSTALL_TYPE=new-install             │
│  ──────────────────────────────────────────────────────────  │
│  1. entrypoint.sh genera config.php desde env vars           │
│  2. install_database.php crea tablas en BD vacía             │
│  3. init.sh ejecuta:                                         │
│     • moodle.sh     → configura sitio, SMTP, idioma es       │
│     • plugins.sh    → configura plugins habilitados          │
│     • import_FPD... → crea categorías, cursos, usuarios      │
│     • theme.sh      → aplica tema Moove + assets FPD         │
│  4. load_usuarios.sh → carga usuarios desde CSV              │
│  5. moodle-data/ se genera automáticamente                   │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Cambios realizados en esta rama

### 4.1. `Dockerfile`

| Antes (rama creacion_moodle-data_propio) | Ahora (esta rama) |
|-------------------|-------------------|
| `FROM php:8.1-fpm` | `FROM php:8.2-apache` |
| nginx servía PHP vía FastCGI socket | Apache con mod_php directamente |
| `COPY moodle-code /var/www/html` | Descarga Moodle 4.5.11 desde GitHub |
| Plugins: ~20 `git clone` hardcoded en Dockerfile | Plugins: `docker-clone-plugins.sh` lee `plugins.json` |

**Instrucciones clave añadidas/cambiadas**:
```dockerfile
FROM php:8.2-apache
ARG MOODLE_VERSION=4.5.11
RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz | tar xz -C /tmp \
    && mv /tmp/moodle-* /usr/src/moodle \
    && cp -r /usr/src/moodle/* /var/www/html/

COPY plugins.json /init-scripts/plugins.json
COPY init-scripts/lib/docker-clone-plugins.sh /init-scripts/lib/docker-clone-plugins.sh
RUN /init-scripts/lib/docker-clone-plugins.sh

RUN a2enmod rewrite
COPY apache-conf/000-default.conf /etc/apache2/sites-available/000-default.conf
CMD ["apache2-foreground"]
```

### 4.2. Eliminación de nginx

- Eliminado servicio `web` de `docker-compose.yml`.
- Eliminados directorios `nginx/` y `fpm-conf/`.
- El servicio `moodle` expone directamente `8080:80`.
- Creado `apache-conf/000-default.conf` con VirtualHost para Moodle.

### 4.3. `plugins.json` (nuevo archivo)

Catálogo maestro de 23 plugins con:
- `name`, `component`, `description`, `category`
- `git_url`, `git_branch`, `moodle_path`
- `default_enabled` (true/false)
- `has_postinstall_actions`
- `warning` (advertencias de deprecación)

### 4.4. `init-scripts/lib/docker-clone-plugins.sh`

Script de build-time que:
1. Lee `plugins.json` con `jq`.
2. Clona cada plugin con `git clone --depth 1 --branch <rama>`.
3. Falla el build si un clone es incorrecto.

### 4.5. `init-scripts/lib/plugins-lib.sh`

Helpers en bash para runtime:
- `plugins_show_summary()`: resumen de habilitados/deshabilitados.
- `plugins_list_enabled()`: lista plugins a procesar.
- `plugin_is_enabled()`: comprueba si un plugin está habilitado.

### 4.6. `init-scripts/new-install/plugins.sh`

Refactorizado para:
- Cargar `plugins-lib.sh`.
- Iterar sobre plugins habilitados (de `plugins.json` + variables `PLUGIN_*`).
- Ejecutar `actions_asociated_to_plugin()` para configuración post-instalación.

### 4.7. `init-scripts/new-install/load_usuarios.sh` y `data/usuarios.csv`

- Extraídos usuarios hardcodeados de `moodle.sh` e `import_FPD_categories_and_courses.sh`.
- CSV con columnas: `username,password_env,email,firstname,lastname,role`.
- Contraseñas resueltas desde variables de entorno.

### 4.8. `docker-compose.yml`

- Puerto parametrizado `${MOODLE_HOST_PORT:-8080}:80` en servicio `moodle` (antes era `8087:80` hardcodeado).
- Eliminado `web` y `phpsocket`.
- Red externa `moodle_network`.
- Añadida variable `MOODLE_HOST_PORT` a `.env.example` para controlar el puerto de publicación en el host.

---

## 5. Cómo probar esta rama

### 5.1. Prerequisitos

- Docker y Docker Compose instalados.
- Red externa `moodle_network` creada (o ajustar en `docker-compose.yml`).
- Base de datos MariaDB/MySQL vacía y accesible.
- Archivo `.env` configurado.

### 5.2. Pasos

```bash
# 1. Cambiar a esta rama
cd /var/moodle-docker-deploy/moodle-docker-test/Moodle-Docker
git checkout apache-moodle

# 2. Asegurar que moodle-data sea local y esté vacío
sudo rm -rf moodle-data
mkdir moodle-data
sudo chown -R 33:33 moodle-data
sudo chmod 755 moodle-data

# 3. Verificar .env (debe apuntar a una BD vacía y tener INSTALL_TYPE=new-install)
cat .env | grep INSTALL_TYPE
# → INSTALL_TYPE=new-install
cat .env | grep VERSION
# → VERSION=4.5.11

# 4. Build y despliegue
docker compose up -d --build

# 5. Seguir logs (el proceso puede tardar varios minutos)
docker compose logs -f moodle
```

### 5.3. Variables de entorno mínimas para prueba

```env
MOODLE_DB_HOST=moodle_mariadb
MOODLE_DB_PORT=3306
MOODLE_DB_NAME=moodle
MOODLE_DB_USER=moodle
MOODLE_DB_PASSWORD=moodle_password

MOODLE_URL=http://localhost:8080
VIRTUAL_HOST=localhost

MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=admin_password
MOODLE_ADMIN_EMAIL=admin@example.com

INSTALL_TYPE=new-install
VERSION=4.5.11

# Plugins principales
PLUGIN_THEME_MOOVE=true
PLUGIN_FORMAT_TILES=true
PLUGIN_BLOCK_XP=true
PLUGIN_LOCAL_MAIL=true
PLUGIN_MOD_BOARD=true
```

### 5.4. Verificaciones post-arranque

Una vez que el contenedor esté estable (`apache2-foreground` corriendo sin errores):

1. Acceder a `http://localhost:8080/login/index.php`.
2. Verificar que el tema Moove se carga correctamente.
3. Verificar que el idioma es español.
4. Revisar que los plugins estén instalados: `Administración del sitio > Plugins > Resumen de plugins`.
5. Verificar que existen las categorías y cursos FPD.

---

## 6. Cambios realizados durante la sesión de despliegue (2026-05-22)

### 6.1. `Dockerfile` — inclusión de `python3`

**Problema**: `plugins-lib.sh` usaba `python3` para leer `plugins.json`, pero la imagen base `php:8.2-apache` no lo incluye. Esto provocaba que `plugins.sh` fallara silenciosamente, por lo que **ningún plugin se instalaba** (incluyendo `theme_moove`), dejando Moodle con el tema `boost` por defecto.

**Solución**: Añadido `python3` a la lista de paquetes de `apt-get install` en el `Dockerfile`.

### 6.2. Scripts de inicialización — flag `-n` en `moosh`

**Problema**: Todos los scripts de `init-scripts/` ejecutan `moosh` como `root` (el entrypoint del contenedor corre como root), pero los directorios de `moodledata` pertenecen a `www-data`. Moosh lanzaba el warning:
> "One of your Moodle data directories is owned by different user (www-data) than the one that runs the script (root)."

**Solución**: Añadido el flag `-n` a **todos** los comandos `moosh` en los scripts de `new-install/` y `upgrade/` para saltar la comprobación de propietario.

### 6.3. Ruta de archivos `.mbz` para restauración de cursos

**Cambio**: En `import_FPVirtual_categories_and_courses.sh`, la ruta de búsqueda de backups `.mbz` cambió de:
```
/var/www/moodledata/repository/mbzs_curso_anterior/
```
a:
```
/init-scripts/mbz/
```

Esto permite versionar los `.mbz` junto al código de inicialización en lugar de depender de la carpeta de datos de Moodle.

### 6.4. Eliminación de plugin deprecado del catálogo

**Cambio**: Eliminado `block_configurable_reports` de `plugins.json`. Aunque ya estaba deshabilitado por defecto, su repositorio en GitHub generaba errores de TLS durante el build (`GnuTLS handshake failed`). Al eliminarlo del JSON, el build es más estable.

### 6.5. Puerto host parametrizado

**Cambio**: El puerto de publicación del host ya no está hardcodeado a `8087`. Ahora se controla mediante la variable `MOODLE_HOST_PORT` en `.env` (valor por defecto `8080`).

### 6.6. Centralización de datos de inicialización en `/init-data`

**Problema**: Los archivos CSV de usuarios/cursos y los backups `.mbz` (2,9 GB) estaban dentro de `init-scripts/`, por lo que se copiaban en la imagen Docker durante el build. Esto inflaba innecesariamente el tamaño de la imagen.

**Solución**: Se creó el directorio `./init-data/` en la raíz del proyecto con dos subdirectorios:
- `./init-data/data/` → CSV de usuarios, jefaturas, categorías, cohortes y cursos (`read_csv.php`).
- `./init-data/mbzs/` → Backups `.mbz` para restauración de cursos.

`docker-compose.yml` monta `./init-data:/init-data:ro` como volumen de solo lectura. Los scripts de inicialización leen desde `/init-data/data/` y `/init-data/mbzs/` en runtime, sin necesidad de empaquetarlos en la imagen.

---

## 7. Trabajo pendiente y riesgos conocidos

### 7.1. Plugin `local_educaaragon`

Plugin interno de Aragón sin repositorio público conocido. No está en `plugins.json`.
Si es necesario, copiar manualmente a `custom/local_educaaragon/` o añadir al Dockerfile.

### 7.2. Compatibilidad PHP 8.2

Moodle 4.5 soporta PHP 8.1-8.3. PHP 8.2 es el recomendado.
Algunos plugins más antiguos podrían emitir warnings de deprecación. Verificar logs de Apache.

### 7.3. Theme assets en instalación limpia

El `moodle-data/filedir/` contiene hashes de archivos del tema (logos, banners).
En instalación completamente limpia, estos archivos no existen.
Se extrajeron 19 hashes del contenedor anterior para preservar assets visuales.

### 7.4. Tiempo de build

Clonar ~23 repositorios git durante el build puede tardar 5-15 minutos.
Mitigación: `--depth 1`, cache de capas Docker.

### 7.5. Clean database setup

Para una instalación limpia con Moodle 4.5.11:
1. Asegurar que la BD esté vacía (drop/create database).
2. `INSTALL_TYPE=new-install`.
3. `VERSION=4.5.11`.
4. `MOODLE_URL=http://localhost:8080`.

---

## 8. Decisiones de diseño

| Decisión | Justificación |
|----------|---------------|
| `php:8.2-apache` en lugar de `php:8.1-fpm` | PHP 8.2 es el recomendado para Moodle 4.5. Apache+mod_php simplifica el stack. |
| `plugins.json` como catálogo maestro | Single source of truth. URLs verificables. Control runtime vía env vars. |
| `docker-clone-plugins.sh` en build | Centraliza clones. Falla el build si una URL está rota. |
| Eliminar nginx | Reduce complejidad: un solo contenedor, sin sockets UNIX, sin sincronización. |
| CSV para usuarios | Separa datos de lógica. Facilita modificaciones sin tocar código. |
| `moodle-data` local | Coherencia con objetivo de generación propia. |

---

## 9. Relación con otros documentos

| Documento | Rol |
|-----------|-----|
| `AGENTS.md` | Guía general del proyecto, convenciones y stack tecnológico actualizado. |
| `Analisis-sistema.md` | Estado actual del sistema tras migración a Apache + Moodle 4.5. |
| `Estudio-moodle-code-to-container.md` | Arquitectura de imagen autocontenida y sistema plugins.json. |
| `Inventario-y-estado-plugins.md` | Estado y riesgos de cada plugin para Moodle 4.5. |
| `UPGRADE.md` | Guía para actualizar Moodle (revisar para nueva arquitectura). |
| `README.md` | Documentación general para usuarios humanos. |

---

## 10. Contacto y mantenimiento

- Si se detecta que un plugin no clona o no es compatible, actualizar `plugins.json`.
- Para añadir un nuevo plugin: incluir en `plugins.json`, añadir `PLUGIN_<NOMBRE>` a `.env.example`, y añadir acciones post-instalación a `plugins.sh` si es necesario.
- Antes de mergear esta rama a `main`, probar: instalación limpia completa (`new-install` + BD vacía) y upgrade (`upgrade` + BD poblada).
