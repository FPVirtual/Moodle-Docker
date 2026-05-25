## 1. Análisis del proyecto y arquitectura actual

> Fecha de actualización: 2026-05-25
> Rama: `apache-moodle`
> Este documento refleja el estado del proyecto `new-moodle` tras la migración a **Apache + mod_php**, **Moodle 4.5.11** y **PHP 8.2**.

### 1.1. Arquitectura general

El proyecto es un despliegue **Docker Compose** de Moodle 4.5.11, preparado para la Formación Profesional a Distancia de Aragón (FPD). Se compone de:

| Componente | Descripción | Decisión clave |
|------------|-------------|----------------|
| **Servicios Docker** | `redis` (caché/sesiones) y `moodle` (imagen propia basada en `php:8.2-apache`). | Se eliminó el contenedor `web` (nginx) y PHP-FPM. Apache con mod_php simplifica el stack y reduce latencia. |
| **Código fuente** | Moodle core descargado desde GitHub releases durante el build. Plugins clonados dinámicamente desde `plugins.json`. | Ya no se copia `moodle-code/` del host. La imagen es 100% autocontenida. |
| **Datos de Moodle** | Carpeta `./moodle-data/` montada como volumen. | Generación propia para nuevas instalaciones. En migraciones puede montarse datos existentes. |
| **Datos de inicialización** | Carpeta `./init-data/` montada como volumen de solo lectura. | Contiene `data/` (CSV de usuarios, cursos, categorías, cohortes, jefaturas) y `mbzs/` (backups `.mbz` para restauración de cursos). Externaliza ~2,9 GB de la imagen Docker. |
| **Base de datos** | **MariaDB externa** (10.11.16 o superior), conectada vía red Docker `moodle_network`. | No se usa el perfil `with-db` en producción. Para desarrollo/testing se puede levantar con `--profile with-db`. |
| **Proxy inverso** | Red externa `moodle_network`, gestionada por proxy inverso externo (nginx-proxy, Traefik, etc.). | El contenedor `moodle` expone puerto `8080:80` en el host. |
| **Configuraciones** | `./apache-conf/000-default.conf`, `./php-conf/` (opcache, uploads, desactivación de APCu). | Se eliminó `nginx/` y `fpm-conf/`. Apache gestiona PHP directamente vía mod_php. |
| **Inicialización** | `./init-scripts/` con lógica de primer arranque (`new-install`) y actualizaciones (`upgrade`). | `plugins.json` + variables `PLUGIN_*` controlan qué plugins se instalan. Todos los comandos `moosh` usan flag `-n` para evitar warnings de propietario. |
| **Gestión de usuarios** | CSV en `./init-data/data/usuarios.csv` + `load_usuarios.sh`. | Reemplaza la creación hardcodeada de usuarios en `moodle.sh` e `import_FPVirtual_categories_and_courses.sh`. Los CSV se montan como volumen, no se copian en la imagen. |

### 1.2. Diagrama de red

```
┌─────────────────────────────────────────────────────────────┐
│  Servidor host                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  ┌──────────────────┐      ┌─────────────────────────────┐ │
│  │ Proxy inverso    │      │  Moodle-Docker (apache)     │ │
│  │ (HTTPS/SSL)      │◄────►│  ┌───────────────────────┐  │ │
│  └──────────────────┘      │  │ moodle (php:8.2-apache)│  │ │
│         ▲                  │  │   Apache + mod_php     │  │ │
│         │                  │  │   Puerto 8080:80       │  │ │
│  Usuarios finales          │  └───────────────────────┘  │ │
│                            │              │              │ │
│                            │      ┌──────┴──────┐       │ │
│                            │      │             │       │ │
│  ┌──────────────────┐      │  ┌───▼───┐   ┌────▼────┐  │ │
│  │ MariaDB (externa)│◄─────┘  │ redis │   │moodle-data│ │ │
│  │ (red Docker)     │         └───────┘   └─────────┘  │ │
│  └──────────────────┘                                   │ │
│                                                         │ │
│  (moodle-data generado localmente o montado)            │ │
│  (código 100% empaquetado en la imagen Docker)          │ │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Decisiones técnicas y porqué se tomaron

### 2.1. Migración de nginx+php-fpm a Apache+mod_php

**Decisión**: Eliminar el contenedor `web` (nginx) y cambiar la imagen base de `php:8.1-fpm` a `php:8.2-apache`.

**Por qué**:
- **Simplificación del stack**: De 3 contenedores (nginx, php-fpm, redis) a 2 (apache+php, redis).
- **Menor latencia**: mod_php evita el overhead de FastCGI/socket UNIX entre nginx y PHP-FPM.
- **Mantenimiento reducido**: Una sola imagen que incluye servidor web + PHP.
- **Compatibilidad**: Moodle 4.5 soporta PHP 8.1-8.3. PHP 8.2 es la versión recomendada para instalaciones nuevas.

**Cambios realizados**:
- `Dockerfile`: `FROM php:8.2-apache`, `a2enmod rewrite`, `EXPOSE 80`, `CMD ["apache2-foreground"]`.
- `docker-compose.yml`: Eliminado servicio `web` y volumen `phpsocket`. Añadido `ports: ["8080:80"]` al servicio `moodle`.
- Nuevo `apache-conf/000-default.conf`: VirtualHost con `DocumentRoot /var/www/html`, `AllowOverride All`.
- Eliminados directorios `nginx/` y `fpm-conf/`.

### 2.2. Plugin catalog (`plugins.json`) como fuente única de verdad

**Decisión**: Centralizar metadatos de todos los plugins en `plugins.json` y clonarlos en build-time con `docker-clone-plugins.sh`.

**Por qué**:
- **Single source of truth**: Un solo archivo JSON define nombre, repositorio, rama, ruta de instalación, habilitación por defecto y advertencias.
- **Verificación automática**: Las URLs se pueden validar programáticamente (curl) antes del build.
- **Flexibilidad runtime**: Variables `PLUGIN_<NOMBRE>` en `.env` permiten habilitar/deshabilitar plugins sin reconstruir la imagen (aunque el código ya está en la imagen, las acciones post-instalación se ejecutan condicionalmente).

**Archivos involucrados**:
- `plugins.json`: Catálogo maestro (22 plugins).
- `init-scripts/lib/docker-clone-plugins.sh`: Clona plugins durante el build.
- `init-scripts/lib/plugins-lib.sh`: Helpers bash para leer JSON en runtime.
- `init-scripts/new-install/plugins.sh`: Instala/configura plugins habilitados.

### 2.3. Eliminación de `moodle-code/` como bind mount

**Decisión**: Moodle core se descarga desde GitHub releases en el Dockerfile. Los plugins se clonan desde git.

**Por qué**:
- La imagen es 100% reproducible en cualquier servidor.
- No se requiere copiar gigas de código del host.
- Rollback es trivial: `docker pull` de imagen anterior.
- El `docker-compose.override.yml.example` aún permite montar código externo para desarrollo.

### 2.4. Actualización a Moodle 4.5.11

**Decisión**: Subir desde Moodle 4.1.19 a 4.5.11 (salto de una versión mayor: 4.1 → 4.2 → 4.3 → 4.4 → 4.5 no es necesario cuando se hace instalación limpia; para upgrade de BD existente sí requeriría pasos intermedios).

**Por qué**:
- Moodle 4.5 es la versión LTS actual con soporte extendido.
- PHP 8.2 es el recomendado para 4.5.
- Los plugins se actualizaron a ramas `MOODLE_405_STABLE` donde estaban disponibles.

### 2.5. Carga de usuarios desde CSV

**Decisión**: Extraer usuarios hardcodeados de `moodle.sh` e `import_FPVirtual_categories_and_courses.sh` a un CSV.

**Por qué**:
- Facilita la modificación de usuarios sin tocar código.
- Permite gestionar contraseñas desde variables de entorno.
- Separa datos de lógica.

---

## 3. Problemas encontrados y resoluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| `ProxyTimeout` invalid en Apache | Directiva `ProxyTimeout` requiere `mod_proxy` | Eliminada de `000-default.conf` |
| URLs de plugins rotas (404) | Repositorios movidos o eliminados | Verificadas y corregidas 13 URLs en `plugins.json` y Dockerfile |
| `block_configurable_reports` obsoleto | Open LMS retira soporte julio 2026; además genera errores TLS en build | **Eliminado de `plugins.json`** (antes estaba deshabilitado por defecto) |
| `mod_googlemeet` repo eliminado | Plugin obsoleto | Eliminado del catálogo |
| Editor Atto deprecado en Moodle moderno | Moodle migra a TinyMCE | Añadidas advertencias en plugins `atto_*` |
| `plugins.sh` falla silenciosamente | Imagen `php:8.2-apache` no incluye `python3`; `plugins-lib.sh` depende de él | Añadido `python3` al `Dockerfile` |
| Warnings de Moosh por propietario | Scripts de init corren como `root` pero `moodledata` es de `www-data` | Añadido flag `-n` a todos los comandos `moosh` en scripts de inicialización |
| Puerto host hardcodeado a `8087` | Dificultaba cambiar el puerto sin editar `docker-compose.yml` | Parametrizado con `${MOODLE_HOST_PORT:-8080}:80` y variable en `.env` |
| Duplicados en creación de cursos | `course-create` fallaba con `shortnametaken` y el parsing de ID con grep era frágil | Se elimina extracción de IDs con regex; se usa SQL directo por `shortname`. Si existe, se busca el curso existente |
| Matriculación de jefaturas con ID inválido | `moosh user-create` devolvía mensajes de error (no numéricos) que se pasaban a `course-enrol` | Se valida que el ID sea numérico antes de matricular; si `user-create` falla, se busca ID por `username` vía SQL |
| Healthcheck MariaDB con `mysqladmin ping` | Generaba warnings `Access denied` cada 10s al no tener contraseña root | Se usa `healthcheck.sh --connect --innodb_initialized` nativo de la imagen |
| Tema assets faltantes en instalación limpia | `moodle-data/filedir/` vacío | Extraídos 19 hashes de theme files del contenedor anterior y colocados en `moodle-data/filedir/` |

---

## 4. Flujo de los scripts de inicialización (estado actual)

El `entrypoint.sh` ejecuta el siguiente flujo en cada arranque:

1. **Restaurar código si bind mount vacío**: si `/var/www/html/config.php` no existe pero existe `/usr/src/moodle/config-dist.php`, copia el código empaquetado en la imagen.
2. **Generar `config.php` automáticamente**: si no existe, se crea desde variables de entorno (`MOODLE_DB_HOST`, `MOODLE_URL`, etc.).
3. **Asegurar permisos de `moodle-data`**: `chown -R www-data:www-data /var/www/moodledata`.
4. **Esperar a la base de datos**: bucle hasta que la BD responda.
5. **Comprobar si Moodle ya está instalado**: consulta si existe la tabla `mdl_config`.
6. **Si no está instalado**:
   - Ejecuta `admin/cli/install_database.php`.
   - Si `INSTALL_TYPE=new-install`, ejecuta `/init-scripts/init.sh`:
     1. `new-install/moodle.sh` (configuración sitio, SMTP, idioma `es`, usuarios CSV)
     2. `new-install/plugins.sh` (instala/configura plugins habilitados según `plugins.json` + `PLUGIN_*`)
     3. `new-install/import_FPVirtual_categories_and_courses.sh` (categorías, cursos, roles, cohortes)
     4. `new-install/theme.sh` (tema Moove + assets FPD)
   - Crea el flag `/var/www/moodledata/.moodle-installed`.
7. **Si ya está instalado y `INSTALL_TYPE=upgrade`**:
   - Ejecuta `admin/cli/upgrade.php --non-interactive --allow-unstable`.
   - Ejecuta `/init-scripts/init.sh` con scripts de `upgrade/`.
8. **Purgar cachés** y arrancar `apache2-foreground`.

---

## 5. Inventario de plugins y componentes no estándar

### Plugins de terceros (gestionados por `plugins.json`)

Ver `plugins.json` para el listado completo con URLs, ramas y estado de habilitación.

Plugins habilitados por defecto:
`theme_moove`, `format_tiles`, `block_xp`, `availability_xp`, `local_mail`, `mod_board`, `mod_pdfannotator`, `block_grade_me`, `block_completion_progress`, `atto_fontsize`, `atto_fontfamily`, `atto_fullscreen`, `qtype_gapfill`, `mod_attendance`, `mod_checklist`, `quizaccess_onesession`, `mod_choicegroup`.

Plugins deshabilitados por defecto (requieren `PLUGIN_*=true`):
`report_coursestats_v2` (obsoleto), `mod_jitsi`, `block_sharing_cart`, `local_reminders`, `atto_c4l`.

### Scripts/aplicaciones PHP custom (no plugins)

Copiados al contenedor vía `COPY custom/ /var/www/html/` en el Dockerfile:

- `custom/decalogo/` — Imágenes del decálogo metodológico FP Virtual.
- `custom/faqs/` — Imágenes y recursos de preguntas frecuentes.
- `custom/private-reports/` — Scripts PHP internos (`docentes.php`, `inspeccion.php`, `jefaturas.php`, `mensajeria.php`).
- `custom/soporte/` — Formularios de soporte con captcha.
- `custom/userpix/` — Gestión de avatares.

---

## 6. Pasos para replicar este despliegue en otro servidor

1. **Clonar el repositorio** y checkout de la rama `apache-moodle`.
2. **Configurar `.env`** con credenciales de BD externa, dominio y variables `PLUGIN_*`.
3. **Crear red externa** si es necesario:
   ```bash
   docker network create moodle_network
   ```
4. **Asegurar `moodle-data/` vacío y con permisos correctos**:
   ```bash
   mkdir -p moodle-data
   sudo chown -R 33:33 moodle-data
   ```
5. **Build y despliegue**:
   ```bash
   docker compose up -d --build
   ```
6. **Seguir logs**:
   ```bash
   docker compose logs -f moodle
   ```

---

## 7. Estado operativo actual

```bash
# Contenedores activos
fpvirtual-moodle    Up  (Apache 80, mapeado a host:8080)
fpvirtual-redis     Up  (redis 6379, healthy)

# Base de datos
MariaDB externa     Up  (3306/tcp, red Docker moodle_network)

# Acceso web
http://localhost:8080  (o via proxy inverso HTTPS)
```

> **Última verificación (2026-05-25)**: Build exitoso, Apache arranca sin errores, config.php se genera automáticamente, plugins se clonan correctamente desde `plugins.json`, tema Moove se aplica. Scripts de inicialización robustos ante duplicados de cursos y usuarios jefatura. Healthcheck de MariaDB usa script nativo.
