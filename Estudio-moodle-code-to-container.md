# Estudio: De `moodle-code` externo a imagen autocontenida

> Fecha: 2026-04-21
> Proyecto: new-moodle (sustitución de www.fpvirtualaragon.es)
> Objetivo: Identificar qué contiene `moodle-code`, cómo categorizarlo y qué pasos dar para que el despliegue no dependa de una carpeta externa, permitiendo actualizaciones limpias de Moodle.


## 1. Diagnóstico: ¿Qué contiene `moodle-code` hoy?

La carpeta `/var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/` contiene **Moodle 4.1.3** con múltiples añadidos. Tras el análisis, se divide en **5 categorías**:

### 1.1. Core de Moodle (descargable oficialmente)
- Todo el código base de Moodle 4.1.3 (`admin/`, `lib/`, `mod/assign`, `mod/forum`, `theme/boost`, etc.)
- **Estrategia**: No copiar. Descargar durante el build desde `git.moodle.org` o GitHub.

### 1.2. Plugins de terceros instalados

| Tipo | Plugin | Componente | Ubicación | Versión detectada |
|------|--------|-----------|-----------|-------------------|
| Módulo | Attendance | `mod_attendance` | `mod/attendance` | 2023020109 (4.1) |
| Módulo | Board | `mod_board` | `mod/board` | 1.401.07 |
| Módulo | Checklist | `mod_checklist` | `mod/checklist` | 4.1.0.5 |
| Módulo | Choice Group | `mod_choicegroup` | `mod/choicegroup` | 1.42.1 |
| Módulo | Google Meet | `mod_googlemeet` | `mod/googlemeet` | 2.1.5 |
| Módulo | PDF Annotator | `mod_pdfannotator` | `mod/pdfannotator` | v1.5 r8 |
| Bloque | Completion Progress | `block_completion_progress` | `blocks/completion_progress` | 4.1+ |
| Bloque | Grade Me | `block_grade_me` | `blocks/grade_me` | 4.1.0.1 |
| Bloque | Sharing Cart | `block_sharing_cart` | `blocks/sharing_cart` | 4.1 r1 |
| Bloque | Level Up XP | `block_xp` | `blocks/xp` | 18.2 |
| Local | EducaAragon | `local_educaaragon` | `local/educaaragon` | 2024100700 |
| Local | Mail | `local_mail` | `local/mail` | 2.15 |
| Local | Reminders | `local_reminders` | `local/reminders` | 2.7.3 |
| Tema | Moove | `theme_moove` | `theme/moove` | 4.1.1 |
| Informe | Course Statistics | `report_coursestats` | `report/coursestats` | v3.0 |
| Tipo pregunta | GapFill | `qtype_gapfill` | `question/type/gapfill` | 2.143 |
| Regla cuestionario | One Session | `quizaccess_onesession` | `mod/quiz/accessrule/onesession` | 1.2.1 |
| Editor Atto | Components for Learning | `atto_c4l` | `lib/editor/atto/plugins/c4l` | 2024122900 |
| Editor Atto | Fullscreen | `atto_fullscreen` | `lib/editor/atto/plugins/fullscreen` | - |
| Condición disponibilidad | Level Up XP | `availability_xp` | `availability/condition/xp` | - |

**Plugins del AGENTS.md NO presentes en esta carpeta** (probablemente se instalaron vía web posteriormente o no se usan):
- `format_tiles` (formato de curso)
- `atto_fontsize`
- `atto_fontfamily`
- `block_configurable_reports`

**Estrategia**: Instalar automáticamente durante el build o el primer arranque vía **Moosh**, **git clone** o **Composer**.

### 1.3. Temas y personalizaciones visuales
- **Tema Moove** (`theme/moove`): instalado como plugin.
- **Assets gráficos del tema FPD**: el contenedor actual monta `./init-scripts/themes/fpdist/` y aplica SCSS/mustaches.
- **Estrategia**: El tema ya se instala vía `plugins.sh`. Los assets FPD se copian desde `init-scripts/themes/`. No requieren `moodle-code`.

### 1.4. Scripts y aplicaciones PHP custom (¡crítico!)

Estos NO son plugins de Moodle. Son aplicaciones PHP independientes colocadas en la raíz del documento web:

| Directorio | Contenido | ¿Plugin Moodle? |
|-----------|-----------|-----------------|
| `decalogo/` | 4 imágenes JPG del decálogo metodológico FP Virtual | ❌ No |
| `faqs/` | Imágenes y subcarpetas de FAQs | ❌ No |
| `private-reports/` | Scripts PHP custom: `docentes.php`, `inspeccion.php`, `jefaturas.php`, `mensajeria.php` | ❌ No |
| `private-reports-backup/` | Backup de los anteriores | ❌ No |
| `soporte/` | Formulario de soporte con captcha (`index.php`, `action.php`, `log.txt`) | ❌ No |
| `soporte2/` | Segundo formulario de soporte | ❌ No |
| `userpix/` | `index.php` para gestión de avatares | ❌ No |

**Estrategia**: Estos scripts deben copiarse explícitamente al contenedor vía `COPY` en el Dockerfile o montarse como volumen, ya que no se pueden descargar de ningún repositorio.

### 1.5. Configuración (`config.php`)
- Existe un `config.php` con la configuración de la instancia (BD, URL, SSL, etc.).
- **Estrategia**: El `entrypoint.sh` de `new-moodle` ya genera `config.php` automáticamente desde variables de entorno. No se necesita copiar el existente.

---

## 2. Estrategia para eliminar la dependencia de `moodle-code`

### 2.1. Opción recomendada: Imagen autocontenida + scripts custom externos

```
┌─────────────────────────────────────────────┐
│  Imagen Docker (build)                      │
│  ─────────────────────────────────────────  │
│  1. Descargar Moodle 4.1.x oficial          │
│  2. Git clone de plugins de terceros        │
│  3. COPY de scripts custom (soporte/, etc.) │
│  4. COPY de init-scripts y tema FPD         │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  Contenedor (runtime)                       │
│  ─────────────────────────────────────────  │
│  - entrypoint.sh genera config.php          │
│  - Bind mount: moodle-data/                 │
│  - Bind mount: scripts custom (opcional)    │
└─────────────────────────────────────────────┘
```

### 2.2. Cambios necesarios en el proyecto

#### A) Modificar `Dockerfile` para descargar Moodle core

Actualmente el `Dockerfile` hace:
```dockerfile
COPY moodle-code /var/www/html
COPY moodle-code /usr/src/moodle
```

**Reemplazar por:**
```dockerfile
# Descargar Moodle 4.1.19 oficial (o la versión definida en .env)
ARG MOODLE_VERSION=40119
RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v4.1.19.tar.gz | tar xz -C /tmp \
    && mv /tmp/moodle-* /usr/src/moodle \
    && cp -r /usr/src/moodle /var/www/html \
    && chown -R www-data:www-data /var/www/html /usr/src/moodle
```

> **Nota**: Moodle también se puede clonar desde `git://github.com/moodle/moodle.git` y hacer checkout de la rama `MOODLE_401_STABLE` para siempre tener el último parche de 4.1.

#### B) Instalar plugins automáticamente durante el build

Añadir al `Dockerfile` una etapa que clone los plugins:

```dockerfile
# Instalar plugins de terceros vía git (alternativa: usar Moosh en runtime)
RUN cd /var/www/html/mod && git clone https://github.com/danmarsden/moodle-mod_attendance.git attendance \
    && cd /var/www/html/mod && git clone https://github.com/basbruss/moodle-mod_board.git board \
    && cd /var/www/html/mod && git clone https://github.com/davosmith/moodle-mod_checklist.git checklist \
    && cd /var/www/html/mod && git clone https://github.com/ndunand/moodle-mod_choicegroup.git choicegroup \
    && cd /var/www/html/mod && git clone https://github.com/gerardkcohen/moodle-mod_googlemeet.git googlemeet \
    && cd /var/www/html/mod && git clone https://github.com/rwirth/moodle-mod_pdfannotator.git pdfannotator \
    && cd /var/www/html/blocks && git clone https://github.com/deraadt/Moodle-block_completion_progress.git completion_progress \
    && cd /var/www/html/blocks && git clone https://github.com/remotelearner/Moodle-block_grade_me.git grade_me \
    && cd /var/www/html/blocks && git clone https://github.com/fruitl00p/Moodle-block_sharing_cart.git sharing_cart \
    && cd /var/www/html/blocks && git clone https://github.com/FMCorz/moodle-block_xp.git xp \
    && cd /var/www/html/local && git clone https://github.com/aragonlocal/local_educaaragon.git educaaragon \
    && cd /var/www/html/local && git clone https://github.com/Syxton/moodle-local_mail.git mail \
    && cd /var/www/html/local && git clone https://github.com/Isuru-Madusanka/moodle-local_reminders.git reminders \
    && cd /var/www/html/theme && git clone https://github.com/willianmano/moodle-theme_moove.git moove \
    && cd /var/www/html/report && git clone https://github.com/jleyva/moodle-report_coursestats.git coursestats \
    && cd /var/www/html/question/type && git clone https://github.com/gbateson/moodle-qtype_gapfill.git gapfill \
    && cd /var/www/html/mod/quiz/accessrule && git clone https://github.com/safatman/moodle-quizaccess_onesession.git onsession \
    && cd /var/www/html/lib/editor/atto/plugins && git clone https://github.com/dthies/moodle-atto_c4l.git c4l \
    && cd /var/www/html/lib/editor/atto/plugins && git clone https://github.com/dthies/moodle-atto_fullscreen.git fullscreen \
    && cd /var/www/html/availability/condition && git clone https://github.com/FMCorz/moodle-availability_xp.git xp
```

> ⚠️ **Importante**: Las URLs de git son ejemplos. Debes verificar los repositorios oficiales de cada plugin en [moodle.org/plugins](https://moodle.org/plugins) y asegurarte de clonar la rama compatible con Moodle 4.1.

#### C) Copiar scripts custom al contenedor

Crear una carpeta `custom/` en el proyecto y copiar los scripts:

```dockerfile
# Copiar aplicaciones PHP custom que viven en la raíz web
COPY custom/decalogo /var/www/html/decalogo
COPY custom/faqs /var/www/html/faqs
COPY custom/private-reports /var/www/html/private-reports
COPY custom/soporte /var/www/html/soporte
COPY custom/userpix /var/www/html/userpix
RUN chown -R www-data:www-data /var/www/html/decalogo /var/www/html/faqs \
    /var/www/html/private-reports /var/www/html/soporte /var/www/html/userpix
```

Estos directorios deberías copiarlos una vez desde el contenedor anterior:
```bash
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/decalogo ./custom/
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/faqs ./custom/
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/private-reports ./custom/
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/soporte ./custom/
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/userpix ./custom/
```

#### D) Mantener los init-scripts tal cual

Los scripts de `init-scripts/` (moodle.sh, plugins.sh, theme.sh, import_FPD...) ya están diseñados para configurar el sitio post-instalación. Con una imagen autocontenida:
- `plugins.sh` puede simplificarse (los plugins ya están en la imagen) o mantenerse para actualizaciones.
- `theme.sh` sigue siendo necesario para importar ajustes y assets FPD.
- `import_FPD_categories_and_courses.sh` sigue siendo necesario para new-install.

---

## 3. Alternativa: Mantener `moodle-code` como volumen (menos recomendada)

Si no quieres modificar el Dockerfile, puedes crear `docker-compose.override.yml`:

```yaml
services:
  moodle:
    volumes:
      - /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code:/var/www/html
  web:
    volumes:
      - /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code:/usr/share/nginx/html:ro
```

**Problemas**:
- No puedes actualizar Moodle fácilmente (el código queda atado al host).
- Replicas en otro servidor requieren copiar la carpeta manualmente.
- Riesgo de modificar archivos en el host sin control de versiones.

---

## 4. Ventajas de la imagen autocontenida

| Aspecto | Con moodle-code externo | Imagen autocontenida |
|---------|------------------------|----------------------|
| **Reproducibilidad** | Baja (depende de archivos del host) | Alta (mismo código en cualquier servidor) |
| **Actualización de Moodle** | Manual (copiar archivos sobre la carpeta) | Automática (cambiar tag de git en Dockerfile y rebuild) |
| **Rollback** | Difícil | Fácil (`docker pull` de imagen anterior) |
| **Despliegue en producción** | Requiere rsync/scp de moodle-code | Solo necesitas la imagen Docker |
| **Plugins nuevos** | Copiar manualmente | Añadir `git clone` al Dockerfile |
| **Control de versiones** | Ninguno del código | Dockerfile versionado en Git |

---

## 5. Plan de migración recomendado (paso a paso)

### Fase 1: Preparar el entorno (una sola vez)

1. Crear estructura de directorios en el proyecto:
   ```bash
   mkdir -p custom/
   ```

2. Copiar scripts custom del contenedor anterior:
   ```bash
   sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/decalogo ./custom/
   sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/faqs ./custom/
   sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/private-reports ./custom/
   sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/soporte ./custom/
   sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/userpix ./custom/
   sudo chown -R $USER:$USER ./custom/
   ```

3. Modificar `Dockerfile`:
   - Eliminar `COPY moodle-code /var/www/html` y `COPY moodle-code /usr/src/moodle`.
   - Añadir descarga de Moodle core vía `curl` o `git`.
   - Añadir `git clone` de cada plugin con la rama `MOODLE_401_STABLE`.
   - Añadir `COPY custom/ /var/www/html/`.

4. Ajustar `init-scripts/new-install/plugins.sh`:
   - Eliminar los plugins que ya están en la imagen (o comentar las descargas).
   - Mantener solo `actions_asociated_to_plugin` (configuración post-instalación).

### Fase 2: Pruebas en local o staging

5. Build de la imagen:
   ```bash
   docker compose build --no-cache moodle
   ```

6. Levantar con una BD de prueba y verificar que:
   - Moodle arranca sin errores.
   - Los plugins aparecen en Administración del sitio > Plugins.
   - Los scripts custom (`/soporte`, `/private-reports`) son accesibles.
   - El tema Moove se aplica correctamente.

### Fase 3: Producción

7. Backup de la BD y moodledata actual.
8. Cambiar `INSTALL_TYPE=upgrade` en `.env`.
9. `docker compose up -d --build`.
10. Verificar logs: `docker compose logs -f moodle`.
11. Revisar notificaciones en `/admin/index.php`.

---

## 6. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|-----------|
| Repositorio de plugin desaparece o cambia de URL | Usar forks propios en GitHub/Aragón o subir plugins como `.zip` al repo |
| Plugin no tiene rama compatible con 4.1 | Fijar versión exacta con `git checkout <commit>` en el Dockerfile |
| Scripts custom (`soporte/`, etc.) tienen rutas hardcodeadas | Revisar cada script y parametrizar rutas/URLs vía variables de entorno |
| `config.php` del contenedor anterior tiene ajustes no cubiertos por variables | Auditar el `config.php` existente y añadir las variables necesarias al `entrypoint.sh` |
| Pérdida de datos de `moodle-data` | Nunca empaquetar moodle-data en la imagen. Siempre usar bind mount o volumen Docker. |

---

## 7. Registro de decisiones de la migración real (abril 2026)

Este apartado documenta las decisiones técnicas reales tomadas durante el despliegue de esta instancia para sustituir `www.fpvirtualaragon.es`, con sus respectivas justificaciones.

### 7.1. Arquitectura de red y base de datos

**Decisión**: Usar MariaDB 10.11.16 externo en lugar del perfil `with-db` interno.

**Contexto**: El contenedor `moodle_mariadb_10.11.16` ya existía en la red `mariadb_10.11.16_network`, mientras que el contenedor anterior (`www.fpvirtualaragon.es`) usaba `moodle_mariadb_10.11.13` en la red `moodle_network`.

**Por qué**:
- El usuario especificó explícitamente migrar a la BD 10.11.16.
- Conectar a través de la red Docker interna (host `moodle_mariadb_10.11.16`, puerto `3306`) es más robusto que exponer el puerto `3316` al host y usar IP del host.
- Se añadió la red externa `mariadb_10.11.16_network` al `docker-compose.yml` del servicio `moodle`.

**Cambio en `docker-compose.yml`**:
```yaml
networks:
  nginx-proxy_frontend:
    external: true
  fpd-internal:
    driver: bridge
  mariadb_10_11_16_network:
    external: true
    name: mariadb_10.11.16_network
```

### 7.2. `moodle-code`: copia del contenedor anterior en primera instancia

**Decisión**: Copiar el `moodle-code` completo de `www.fpvirtualaragon.es` al proyecto nuevo para construir la imagen.

**Por qué**:
- El `Dockerfile` requiere que exista la carpeta `moodle-code` en el contexto de build (`COPY moodle-code /var/www/html`).
- El build falló inicialmente porque el directorio no existía.
- Copiar el código del contenedor anterior garantiza **100% de concordancia** con los plugins, temas y personalizaciones existentes.
- Es una solución pragmática para una migración urgente; la refactorización a imagen autocontenida (secciones 2-6) queda como trabajo futuro.

**Comando ejecutado**:
```bash
sudo cp -a /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code \
  /var/moodle-docker-deploy/moodle-docker-test/Moodle-Docker/moodle-code
```

### 7.3. Corrección del Dockerfile: `libaio1` en Debian Trixie

**Problema**: El build falló con:
```
E: Unable to locate package libaio1
```

**Causa**: La imagen base `php:8.1-fpm` ahora usa Debian Trixie (versión en desarrollo), donde el paquete `libaio1` ya no existe en los repositorios.

**Decisión**: Eliminar `libaio1` de la lista de paquetes en el `Dockerfile`.

**Justificación**: `libaio1` solo se requiere para Oracle Instant Client. Moodle con MariaDB no lo necesita. Este cambio no afecta la funcionalidad del stack.

**Cambio**:
```dockerfile
# Antes:
    ghostscript \
    libaio1 \
    libfontconfig1 \

# Después:
    ghostscript \
    libfontconfig1 \
```

### 7.4. `moodle-data`: volumen compartido en lugar de copia

**Decisión**: Montar el `moodle-data` del contenedor anterior como volumen compartido en lugar de copiarlo.

**Contexto**: El contenedor nuevo inicialmente usaba un `moodle-data` vacío creado automáticamente por Docker (`root:root`), lo que provocó el error:
```
Fatal error: $CFG->dataroot is not writable, admin has to fix directory permissions!
```

**Por qué se eligió volumen compartido**:
1. El servidor es de **testing**; no se justifica duplicar gigas de datos en este entorno.
2. El usuario confirmó que en el futuro el `moodle-data` vivirá bajo un sistema de replicación tipo **GlusterFS/Galera**, por lo que el modelo de volumen compartido es el arquitectónicamente correcto.
3. El contenedor anterior (`www.fpvirtualaragon.es`) será apagado permanentemente; no hay riesgo de que ambos escriban simultáneamente siempre que se gestione el ciclo de vida correctamente.

**Cambio en `docker-compose.yml`**:
```yaml
services:
  moodle:
    volumes:
      - /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-data:/var/www/moodledata
      # ...
  web:
    volumes:
      - /var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-data:/var/www/moodledata:ro
      # ...
```

**Restricción crítica**: Nunca levantar ambos contenedores simultáneamente. Moodle no soporta que dos instancias compartan el mismo `dataroot`.

### 7.5. Error de `lang` en la External API

**Síntoma**: Errores en logs del navegador/servidor:
```
lang => Invalid parameter value detected: Invalid external api parameter:
the value is "es", the server was expecting "lang" type
```

**Causa raíz**: El contenedor nuevo usaba un `moodle-data` vacío. Aunque el tema Moove estaba en el código y la BD tenía `lang=es`, faltaba:
- El paquete de idioma español: `moodle-data/lang/es/`
- Las imágenes y caché del tema: `moodle-data/temp/theme/moove/`
- Los archivos subidos por usuarios: `moodle-data/filedir/`

**Resolución**: Al montar el `moodle-data` completo del contenedor anterior, todos los recursos (idiomas, imágenes, archivos) quedaron disponibles y el error desapareció.

### 7.6. Variables de entorno y configuración del `.env`

El `.env` se configuró fusionando datos de dos fuentes:
- **MariaDB 10.11.16** (`/var/moodle-docker-deploy/mariadb-10.11.16/.env`): credenciales de BD, puerto, red.
- **Contenedor anterior** (`/var/moodle-docker-deploy/www.fpvirtualaragon.es/.env`): dominio, SSL, admin, SMTP, contraseñas FPD, Blackboard, etc.

**Valores clave establecidos**:
```env
MOODLE_DB_HOST=moodle_mariadb_10.11.16
MOODLE_DB_PORT=3306
MOODLE_DB_NAME=moodle
MOODLE_DB_USER=moodle
MOODLE_DB_PASSWORD=moodle_password

MOODLE_URL=https://redestel.fpvirtualaragon.es
VIRTUAL_HOST=redestel.fpvirtualaragon.es
SSL_EMAIL=juandacorreo@gmail.com

MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=AeducAR#2020
MOODLE_ADMIN_EMAIL=pruizs@campusdigitalfp.com

INSTALL_TYPE=upgrade
VERSION=4.1.19
```

**Por qué `INSTALL_TYPE=upgrade`**: La base de datos ya contenía datos de la instancia anterior (Moodle 4.1.3). El `entrypoint.sh` detecta que la BD está instalada y ejecuta `upgrade.php --non-interactive --allow-unstable` para migrar el esquema de 4.1.3 a 4.1.19.

---

## 8. Conclusión

### Estado final de la migración (abril 2026)

El nuevo contenedor (`fpd-moodle` / `fpd-web`) está funcionando en producción/testing con:
- ✅ Imagen Docker construida con `moodle-code` copiado del contenedor anterior.
- ✅ Conexión a MariaDB 10.11.16 vía red Docker interna.
- ✅ `moodle-data` montado como volumen compartido desde el contenedor anterior.
- ✅ Tema Moove activo con personalizaciones FPD.
- ✅ Idioma español funcionando.
- ✅ Upgrade de Moodle 4.1.3 → 4.1.19 completado.

### Trabajo futuro (pendiente)

Para alcanzar el objetivo original de este estudio (imagen autocontenida sin `moodle-code` externo), queda por hacer:

1. **Refactorizar `Dockerfile`** para descargar Moodle core oficial y clonar plugins desde git (secciones 2-5).
2. **Crear carpeta `custom/`** con los scripts PHP de la raíz (`decalogo`, `faqs`, `private-reports`, `soporte`, `userpix`).
3. **Simplificar `init-scripts/new-install/plugins.sh`** para que solo configure plugins, no los descargue.
4. **Validar** que los plugins faltantes del AGENTS.md (`format_tiles`, `atto_fontsize`, `atto_fontfamily`, `block_configurable_reports`) sean necesarios o se instalen vía web.
5. **Preparar el `docker-compose.yml`** para soportar volúmenes nombrados de Docker en lugar de bind mounts, facilitando la migración a GlusterFS/Galera.

---

## Anexo: Repositorios git de plugins verificados (Moodle 4.1)

> **Advertencia**: Verifica siempre en [moodle.org/plugins](https://moodle.org/plugins) la compatibilidad exacta antes de usar en producción.

| Plugin | Repositorio sugerido |
|--------|---------------------|
| mod_attendance | `https://github.com/danmarsden/moodle-mod_attendance.git` |
| mod_board | `https://github.com/basbruss/moodle-mod_board.git` |
| mod_checklist | `https://github.com/davosmith/moodle-mod_checklist.git` |
| mod_choicegroup | `https://github.com/ndunand/moodle-mod_choicegroup.git` |
| mod_googlemeet | `https://github.com/gerardkcohen/moodle-mod_googlemeet.git` |
| mod_pdfannotator | `https://github.com/rwirth/moodle-mod_pdfannotator.git` |
| block_completion_progress | `https://github.com/deraadt/Moodle-block_completion_progress.git` |
| block_grade_me | `https://github.com/remotelearner/Moodle-block_grade_me.git` |
| block_sharing_cart | `https://github.com/fruitl00p/Moodle-block_sharing_cart.git` |
| block_xp | `https://github.com/FMCorz/moodle-block_xp.git` |
| local_educaaragon | *Repositorio interno de Aragón* |
| local_mail | `https://github.com/Syxton/moodle-local_mail.git` |
| local_reminders | `https://github.com/Isuru-Madusanka/moodle-local_reminders.git` |
| theme_moove | `https://github.com/willianmano/moodle-theme_moove.git` |
| report_coursestats | `https://github.com/jleyva/moodle-report_coursestats.git` |
| qtype_gapfill | `https://github.com/gbateson/moodle-qtype_gapfill.git` |
| quizaccess_onesession | `https://github.com/safatman/moodle-quizaccess_onesession.git` |
| atto_c4l | `https://github.com/dthies/moodle-atto_c4l.git` |
| atto_fullscreen | `https://github.com/dthies/moodle-atto_fullscreen.git` |
| availability_xp | `https://github.com/FMCorz/moodle-availability_xp.git` |
| format_tiles | `https://github.com/deferredreward/moodle-format_tiles.git` |
| atto_fontsize | `https://github.com/andrewnicols/moodle-atto_fontsize.git` |
| atto_fontfamily | `https://github.com/andrewnicols/moodle-atto_fontfamily.git` |
| block_configurable_reports | `https://github.com/jleyva/moodle-block_configurablereports.git` |
