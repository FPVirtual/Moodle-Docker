# Estudio: De `moodle-code` externo a imagen autocontenida

> Fecha: 2026-05-15
> Rama: `apache-moodle`
> Proyecto: new-moodle (migración a Apache + Moodle 4.5.11)
> Objetivo: Documentar la arquitectura actual donde el código de Moodle y plugins se gestionan 100% dentro de la imagen Docker, sin dependencias de carpetas externas.

---

## 1. Estado actual: imagen 100% autocontenida

El objetivo original de este estudio (eliminar la dependencia de `moodle-code/` copiado del host) **ha sido alcanzado** en la rama `apache-moodle`. La imagen Docker ahora:

1. Descarga Moodle core desde GitHub releases durante el build.
2. Clona plugins desde repositorios git usando `plugins.json` como catálogo maestro.
3. Copia scripts PHP custom desde `custom/`.
4. Genera `config.php` automáticamente en runtime desde variables de entorno.

---

## 2. Arquitectura de build

```
┌─────────────────────────────────────────────────────────────┐
│  Imagen Docker (build)                                      │
│  ─────────────────────────────────────────────────────────  │
│  1. Descargar Moodle 4.5.11 desde GitHub releases           │
│  2. Leer plugins.json → clonar plugins con                 │
│     docker-clone-plugins.sh                                 │
│  3. COPY custom/ → /var/www/html/ (scripts PHP propios)     │
│  4. COPY init-scripts/ → /init-scripts/                     │
│  5. COPY apache-conf/ → /etc/apache2/sites-available/       │
│  6. COPY php-conf/ → /usr/local/etc/php/conf.d/             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Contenedor (runtime)                                       │
│  ─────────────────────────────────────────────────────────  │
│  1. entrypoint.sh genera config.php desde env vars          │
│  2. Espera a BD, instala Moodle si es necesario             │
│  3. init.sh ejecuta scripts según INSTALL_TYPE              │
│  4. apache2-foreground arranca el servidor                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Sistema de gestión de plugins (`plugins.json`)

### 3.1. Estructura del catálogo

El archivo `plugins.json` (raíz del proyecto, copiado a `/init-scripts/plugins.json` en la imagen) contiene metadatos de cada plugin:

```json
{
  "name": "theme_moove",
  "component": "theme_moove",
  "description": "Tema moderno basado en Boost...",
  "category": "theme",
  "moodle_path": "theme/moove",
  "install_method": "moosh",
  "git_url": "https://github.com/willianmano/moodle-theme_moove.git",
  "git_branch": "MOODLE_405_STABLE",
  "default_enabled": true,
  "has_postinstall_actions": true
}
```

Campos clave:
- `name`: Identificador único (usado para variables `PLUGIN_*`).
- `git_url`, `git_branch`: Origen del código para build-time clone.
- `moodle_path`: Ruta relativa dentro de `/var/www/html/` donde se instala.
- `default_enabled`: `true` o `false`. Puede sobrescribirse con `PLUGIN_<NOMBRE>=true|false` en `.env`.
- `has_postinstall_actions`: Indica si `plugins.sh` tiene configuración específica post-instalación.
- `warning`: Advertencias de deprecación u obsolescencia.

### 3.2. Build-time: `docker-clone-plugins.sh`

Ejecutado durante el build del Dockerfile:

```dockerfile
COPY plugins.json /init-scripts/plugins.json
COPY init-scripts/lib/docker-clone-plugins.sh /init-scripts/lib/docker-clone-plugins.sh
RUN /init-scripts/lib/docker-clone-plugins.sh
```

El script:
1. Lee `plugins.json` con `jq`.
2. Para cada plugin con `git_url`, ejecuta `git clone --depth 1 --branch <rama> <url>` en `moodle_path`.
3. Si el directorio destino ya existe (ej. parte de core), lo omite.
4. Falla el build si un clone devuelve error (garantiza integridad).

### 3.3. Runtime: `plugins-lib.sh` + `new-install/plugins.sh`

En runtime, los scripts usan helpers de `init-scripts/lib/plugins-lib.sh`:

- `plugins_show_summary()`: Muestra resumen de plugins habilitados/deshabilitados.
- `plugins_list_enabled()`: Lista solo los plugins cuyo `default_enabled` o variable `PLUGIN_*` indique habilitación.
- `plugin_is_enabled <name>`: Devuelve 0 si el plugin está habilitado.

`new-install/plugins.sh`:
1. Carga `plugins-lib.sh`.
2. Muestra resumen.
3. Para cada plugin habilitado:
   - Intenta instalar vía `moosh plugin-install` (si está en el repositorio de moodle.org para la versión actual).
   - Ejecuta `actions_asociated_to_plugin()` para configuración post-instalación.

### 3.4. Variables de entorno `PLUGIN_*`

En `.env` (y `.env.example`):

```env
PLUGIN_THEME_MOOVE=true
PLUGIN_FORMAT_TILES=true
PLUGIN_BLOCK_CONFIGURABLE_REPORTS=false
# PLUGIN_MOD_JITSI=false
```

- `true`: El plugin se configura en runtime (instalación + acciones post-instalación).
- `false` o línea comentada: Se omite.
- Si la variable no existe, se usa `default_enabled` del JSON.

---

## 4. Comparativa: antes vs. ahora

| Aspecto | Antes (rama main, abril 2026) | Ahora (rama apache-moodle) |
|---------|------------------------------|---------------------------|
| **Imagen PHP** | `php:8.1-fpm` | `php:8.2-apache` |
| **Servidor web** | nginx (contenedor separado `web`) | Apache + mod_php (mismo contenedor) |
| **Moodle core** | Copiado desde `moodle-code/` del host | Descargado desde GitHub releases en build |
| **Plugins** | Hardcoded en Dockerfile (`RUN git clone ...`) o copiados desde host | Centralizados en `plugins.json`, clonados por `docker-clone-plugins.sh` |
| **Control de plugins** | Editar Dockerfile y scripts | Editar `plugins.json` y/o variables `PLUGIN_*` en `.env` |
| **Verificación URLs** | Manual | Automatizable (curl a cada `git_url`) |
| **Código custom** | En `moodle-code/` mezclado con core | En `custom/`, copiado explícitamente vía `COPY` |
| **Usuarios** | Hardcodeados en shell scripts | CSV `usuarios.csv` + `load_usuarios.sh` |
| **Reproducibilidad** | Media (dependía de archivos host) | Alta (imagen 100% autocontenida) |

---

## 5. Ventajas de la arquitectura actual

| Aspecto | Beneficio |
|---------|-----------|
| **Reproducibilidad** | Mismo build en cualquier servidor. Solo hace falta `.env` y `docker compose up -d --build`. |
| **Rollback** | Fácil: etiquetar imágenes Docker y hacer `docker pull` de versión anterior. |
| **Gestión de plugins** | URLs y ramas centralizadas en JSON. Validación automatizada posible. |
| **Simplificación stack** | Apache+mod_php elimina nginx, socket UNIX y sincronización entre contenedores. |
| **Seguridad** | El código no puede modificarse desde el host (salvo override de desarrollo). |
| **CI/CD friendly** | Build automatizable en pipeline. No requiere moodle-code/ en el runner. |

---

## 6. Riesgos y mitigaciones actuales

| Riesgo | Mitigación |
|--------|-----------|
| Repositorio de plugin desaparece o cambia de URL | Verificación periódica de URLs (script curl). Usar forks propios si es crítico. |
| Plugin no tiene rama compatible con Moodle 4.5 | Usar `master`/`main` si no hay `MOODLE_405_STABLE`. Fijar commit si es necesario. |
| Build lento por ~20 clones git | `--depth 1` reduce tamaño. Cache de Docker layer ayuda en rebuilds. |
| Scripts custom (`soporte/`, etc.) tienen rutas hardcodeadas | Auditar y parametrizar vía variables de entorno cuando sea posible. |
| Plugins con `default_enabled: false` no se configuran | Si se habilitan posteriormente, requieren `INSTALL_TYPE=upgrade` o ejecución manual. |

---

## 7. Anexo: Plugins en `plugins.json` (Moodle 4.5)

> Ver `plugins.json` para la información canónica y actualizada. Esta tabla es orientativa.

| Plugin | Repositorio | Rama (aprox.) | Estado default |
|--------|-------------|---------------|----------------|
| theme_moove | `willianmano/moodle-theme_moove` | `MOODLE_405_STABLE` | ✅ habilitado |
| format_tiles | `learnweb/moodle-format_tiles` | `main` | ✅ habilitado |
| block_xp | `FMCorz/moodle-block_xp` | `master` | ✅ habilitado |
| availability_xp | `FMCorz/moodle-availability_xp` | `master` | ✅ habilitado |
| local_mail | `IOC/moodle-local_mail` | `master` | ✅ habilitado |
| mod_board | `brickfield/moodle-mod_board` | `MOODLE_405_STABLE` | ✅ habilitado |
| mod_pdfannotator | `rwthmoodle/moodle-mod_pdfannotator` | `main` | ✅ habilitado |
| block_grade_me | `remotelearner/Moodle-block_grade_me` | `MOODLE_405_STABLE` | ✅ habilitado |
| block_completion_progress | `deraadt/moodle-block_completion_progress` | `master` | ✅ habilitado |
| atto_fontsize | `andrewnicols/moodle-atto_fontsize` | `main` | ✅ habilitado |
| atto_fontfamily | `projectestac/moodle-atto_fontfamily` | `master` | ✅ habilitado |
| atto_fullscreen | `dthies/moodle-atto_fullscreen` | `master` | ✅ habilitado |
| qtype_gapfill | `marcusgreen/moodle-qtype_gapfill` | `main` | ✅ habilitado |
| mod_attendance | `danmarsden/moodle-mod_attendance` | `MOODLE_405_STABLE` | ✅ habilitado |
| mod_checklist | `davosmith/moodle-checklist` | `master` | ✅ habilitado |
| quizaccess_onesession | `vadimonus/moodle-quizaccess_onesession` | `master` | ✅ habilitado |
| mod_choicegroup | `ndunand/moodle-mod_choicegroup` | `master` | ✅ habilitado |
| block_configurable_reports | `jleyva/moodle-block_configurablereports` | `MOODLE_4x_STABLE` | ❌ deshabilitado (deprecado) |
| report_coursestats | `dired-ufla/moodle-report_coursestats_v2` | `main` | ❌ deshabilitado (obsoleto) |
| mod_jitsi | `SergioComeron/moodle-mod_jitsi` | `master` | ❌ deshabilitado |
| block_sharing_cart | `donhinkelman/moodle-block_sharing_cart` | `master` | ❌ deshabilitado |
| local_reminders | `isuru89/moodle-local_reminders` | `master` | ❌ deshabilitado |
| atto_c4l | `rogersegu/moodle-atto_c4l` | `main` | ❌ deshabilitado |
