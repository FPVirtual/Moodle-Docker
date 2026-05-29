# Compatibilidad de scripts init-scripts con Red Hat Enterprise Linux (RHEL)

> Análisis realizado el 2026-05-27 sobre la rama `apache-moodle`.
> Scripts revisados: `init-scripts/init.sh`, `init-scripts/new-install/*.sh`, `init-scripts/upgrade/*.sh`, `init-scripts/lib/*.sh` y `entrypoint.sh`.

---

## 1. Shell / Bash: Compatible en general

Los scripts del proyecto usan constructos estándar de **bash 4+** que funcionan sin problemas en RHEL 7, 8 y 9.

| Característica | ¿Funciona en RHEL? | Notas |
|---|---|---|
| `#!/bin/bash` | ✅ Sí | RHEL mantiene `/bin/bash` por compatibilidad. |
| `declare -A` (arrays asociativos) | ✅ Sí | Requiere bash 4+. RHEL 7 tiene 4.2, RHEL 8+ tiene 4.4/5.x. |
| `grep -oP '\d+'` | ⚠️ Casi siempre | `-P` (PCRE) está en `grep` de RHEL 7+, pero **no es POSIX**. En imágenes mínimas (UBI) podría faltar. |
| `grep -qE '^[0-9]+$'` | ✅ Sí | POSIX extended regex, 100 % portable. |
| `awk '/\[id\] =>/ {print $3}'` | ✅ Sí | `gawk` en RHEL es compatible. |
| `source` vs `.` | ✅ Sí | Ambos funcionan. |
| `$(...)` | ✅ Sí | Requiere bash; todos los scripts usan `#!/bin/bash`. |
| `${!variable}` (indirecta) | ✅ Sí | Bash 4.2+. RHEL 7 lo soporta. |
| `while IFS=$'\t' read -r ...` | ✅ Sí | Compatible. |
| `done < <(...)` | ✅ Sí | Process substitution, requiere bash. |
| `set -e` / `set +x` | ✅ Sí | Compatible. |
| `cp -R`, `cp -a`, `mkdir -p`, `chmod`, `chown` | ✅ Sí | Comandos POSIX/GNU estándar. |
| `cut`, `tr`, `sort`, `seq`, `wc` | ✅ Sí | Comandos coreutils estándar. |

---

## 2. Problemas de dependencias (los reales)

Los scripts **no son autocontenidos**. Dependen de herramientas que en RHEL **no vienen por defecto** o necesitan repositorios adicionales (EPEL, Remi, AppStream).

| Dependencia | ¿En RHEL por defecto? | ¿Quién la usa? | Impacto |
|---|---|---|---|
| **`moosh`** | ❌ No | Todos los scripts de inicialización | Es la herramienta principal. Se instala vía `git clone` + `composer`. |
| **`php` (con mysqli, intl, xml, zip, curl, etc.)** | ⚠️ Parcial | `entrypoint.sh`, `moosh`, `api_service_setup.php` | En RHEL requiere repo **Remi** o **AppStream**. Las extensiones necesarias para Moodle no están todas por defecto. |
| **`python3`** | ⚠️ RHEL 8+: sí / RHEL 7: no | `plugins-lib.sh` | En RHEL 7 hay que instalarlo explícitamente (`yum install python3`). |
| **`jq`** | ❌ No | `docker-clone-plugins.sh` | Está en **EPEL**, no en los repos base de RHEL. |
| **`expect`** | ❌ No | `upgrade/moodle.sh` | Disponible en repos base (`yum install expect`), pero no instalado por defecto. |
| **`git`** | ⚠️ No en UBI mínimo | `docker-clone-plugins.sh` | Necesario para clonar plugins durante el build. |
| **`composer`** | ❌ No | Instalación de `moosh` | Requerido para instalar dependencias de moosh. |
| **`openssl`** | ✅ Sí (base) | `api_config.sh` | Disponible por defecto. |

### 2.1 Nota sobre `grep -P` (PCRE)

Dos scripts usan `grep -oP '\d+'` para extraer IDs numéricos de la salida de `moosh`:

- `init-scripts/new-install/import_FPVirtual_categories_and_courses.sh` (línea 132)
- `init-scripts/new-install/api_config.sh` (línea 137)

En RHEL 7+ funciona porque `grep` se compila con PCRE, pero **no es portable** a sistemas UNIX genéricos ni a imágenes mínimas sin PCRE.

**Alternativa portable:**
```bash
# ANTES (no portable)
grep -oP '\d+' | tail -1

# DESPUÉS (portable)
grep -oE '[0-9]+' | tail -1
```

---

## 3. Problemas de sistema / usuario (fuera del contenedor)

Si se pretende ejecutar el stack en un servidor RHEL nativo (sin Docker), aparecen problemas adicionales:

| Problema | Archivo(s) afectado(s) | Detalle |
|---|---|---|
| **Usuario `www-data` no existe** | `entrypoint.sh` (líneas 8, 13, 55) | En RHEL el usuario de Apache es **`apache`**, no `www-data`. Los `chown -R www-data:www-data` fallarán. |
| **Rutas hardcodeadas** | Todo el proyecto | `/var/www/html`, `/init-scripts/`, `/init-data/`, `/usr/src/moodle`… Están pensadas para el layout de Debian dentro del contenedor. |
| **SELinux** | Todo | RHEL tiene SELinux activo por defecto. Las operaciones de `cp`, `mv` o ejecución de scripts en `/var/www/html` pueden ser bloqueadas por contextos de seguridad incorrectos. |
| **Servicios externos** | `docker-compose.yml` | En RHEL se necesitaría instalar MariaDB/MySQL y Redis por separado, o apuntar a instancias externas. |
| **Redes Docker** | `docker-compose.yml` | El stack asume redes Docker (`nginx-proxy_frontend`, `fpvirtual-internal`). En RHEL nativo estas no existen. |

---

## 4. Tabla de scripts individuales

| Script | `set -e` | ¿Dependencias críticas? | Riesgo en RHEL |
|---|---|---|---|
| `init-scripts/init.sh` | ❌ No | Ninguna propia (orquesta otros) | Bajo (si los demás funcionan) |
| `new-install/moodle.sh` | ❌ No | `moosh` | Medio (si `moosh` y PHP están OK) |
| `new-install/plugins.sh` | ❌ No (`set +x`) | `moosh`, `python3` | Medio (precarga `plugin-list`, mejor que upgrade) |
| `new-install/load_usuarios.sh` | ✅ Sí | `moosh` | Medio |
| `new-install/import_FPVirtual_categories_and_courses.sh` | ❌ No | `moosh`, `php` (read_csv.php) | Medio-Alto (`grep -oP`, `declare -A`, arrays) |
| `new-install/theme.sh` | ❌ No | `moosh`, `cp` | Bajo |
| `new-install/api_config.sh` | ✅ Sí | `moosh`, `php` (api_service_setup.php), `openssl` | Medio (`grep -oP`) |
| `new-install/api_service_setup.php` | N/A (PHP) | `php` con clases de Moodle | Medio (requiere Moodle cargado) |
| `upgrade/moodle.sh` | ❌ No | `moosh`, `expect` | Medio (falta `expect` por defecto) |
| `upgrade/plugins.sh` | ❌ No | `moosh`, `python3` | Medio |
| `upgrade/theme.sh` | ❌ No | `moosh`, `cp` | Bajo |
| `lib/docker-clone-plugins.sh` | ✅ Sí | `git`, `jq` | Alto (falta `jq` en repos base) |
| `lib/plugins-lib.sh` | ❌ No | `python3` | Medio (falta `python3` en RHEL 7) |
| `lib/mbz-preprocess.php` | N/A (PHP) | `php` | Bajo |
| `entrypoint.sh` | ✅ Sí | `php` (mysqli), `chown` | Alto (`www-data` no existe en RHEL) |

---

## 5. Recomendaciones para portar a RHEL

### 5.1 Cambios mínimos en scripts (portabilidad)

1. **Reemplazar `grep -oP '\d+'` por `grep -oE '[0-9]+'`** en:
   - `import_FPVirtual_categories_and_courses.sh`
   - `api_config.sh`

2. **Añadir `check_dependencies()`** al inicio de `init.sh`:
   ```bash
   for cmd in moosh php python3 jq expect git; do
       if ! command -v "$cmd" &>/dev/null; then
           echo >&2 "WARNING: $cmd no está instalado."
       fi
   done
   ```

3. **Detectar usuario de Apache dinámicamente** en `entrypoint.sh`:
   ```bash
   APACHE_USER=$(ps aux | grep -E '[a]pache|[h]ttpd' | head -1 | awk '{print $1}')
   APACHE_USER=${APACHE_USER:-www-data}
   chown -R ${APACHE_USER}:${APACHE_USER} /var/www/html
   ```

### 5.2 Dependencias a instalar en RHEL

Para un contenedor o host RHEL/UBI 8/9:

```bash
# Repos necesarios
subscription-manager repos --enable rhel-9-for-x86_64-appstream-rpms
# o en CentOS/Rocky/Alma:
dnf install -y epel-release

# Dependencias del sistema
dnf install -y bash git expect curl wget unzip tar gzip which

# PHP y extensiones (usando Remi o AppStream)
dnf module reset php
dnf module enable php:8.2
dnf install -y php php-mysqli php-intl php-xml php-zip php-curl php-soap php-opcache php-ldap php-gd php-mbstring php-exif

# Python3 y jq
dnf install -y python3 jq

# Composer (para instalar moosh)
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Moosh (clonar e instalar)
git clone https://github.com/tmuras/moosh.git /opt/moosh
cd /opt/moosh && composer install --no-dev
ln -s /opt/moosh/moosh.php /usr/local/bin/moosh
```

### 5.3 Consideraciones de SELinux

Si se ejecuta en RHEL nativo con SELinux en modo enforcing:

```bash
# Aplicar contextos correctos a Moodle
restorecon -Rv /var/www/html
restorecon -Rv /var/www/moodledata

# O desactivar SELinux temporalmente (no recomendado en producción)
setenforce 0
```

---

## 6. Conclusión

| Escenario | ¿Funcionará? | Esfuerzo requerido |
|---|---|---|
| **Dentro del contenedor actual** (Debian Bookworm) | ✅ Sí | Ninguno. Ya está probado y funcionando. |
| **Dentro de un contenedor RHEL/UBI** | ⚠️ Con trabajo | Medio. Hay que instalar todas las dependencias y adaptar `entrypoint.sh`. |
| **En un servidor RHEL nativo** | 🔴 No directamente | Alto. Requiere adaptar rutas, usuario, SELinux, pila LAMP completa y redes. |

---

*Documento generado automáticamente a partir del análisis de código.*
