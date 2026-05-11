## 1. Análisis del proyecto y arquitectura actual

> Fecha de actualización: 2026-04-21
> Este documento refleja el estado del proyecto `new-moodle` tras la migración que sustituye al contenedor `www.fpvirtualaragon.es`.

### 1.1. Arquitectura general

El proyecto es un despliegue **Docker Compose** de Moodle 4.1.19, preparado para la Formación Profesional a Distancia de Aragón (FPD). Se compone de:

| Componente | Descripción | Decisión clave |
|------------|-------------|----------------|
| **Servicios Docker** | `redis` (caché/sesiones), `web` (nginx:latest) y `moodle` (imagen propia basada en `php:8.1-fpm`). | Imagen propia en lugar de imagen externa `cateduac/moodle`, para tener control total del build y del código empaquetado. |
| **Código fuente** | Carpeta `./moodle-code/` copiada **dentro de la imagen** en tiempo de build (`COPY moodle-code /var/www/html`). | En esta migración se copió el `moodle-code` del contenedor anterior para garantizar concordancia total de plugins y temas. En el futuro se refactorizará para descargar core + plugins desde git. |
| **Datos de Moodle** | Carpeta `./moodle-data/` montada como volumen. En esta migración, apunta al `moodle-data` del contenedor anterior. | Se eligió montaje compartido porque (a) es un servidor de testing, (b) en producción se migrará a un sistema de replicación tipo GlusterFS/Galera. |
| **Base de datos** | **MariaDB 10.11.16 externa**, conectada vía red Docker `mariadb_10.11.16_network`. | No se usa el perfil `with-db` (BD interna). Se reutiliza el contenedor de BD existente para evitar duplicar infraestructura y garantizar persistencia de datos. |
| **Proxy inverso** | Red externa `nginx-proxy_frontend`, gestionada por `nginx-proxy` + Let's Encrypt. | Se mantiene el mismo proxy ya configurado para el contenedor anterior. |
| **Configuraciones** | `./nginx/default.conf`, `./fpm-conf/`, `./php-conf/` (opcache, uploads, desactivación de APCu). | Sin cambios respecto al diseño original del proyecto. |
| **Inicialización** | `./init-scripts/` con lógica de primer arranque (`new-install`) y actualizaciones (`upgrade`). | Se usó `INSTALL_TYPE=upgrade` porque la BD ya contenía datos del Moodle 4.1.3 anterior. |

### 1.2. Diagrama de red

```
┌─────────────────────────────────────────────────────────────┐
│  Servidor host                                              │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  ┌──────────────────┐      ┌─────────────────────────────┐ │
│  │ nginx-proxy      │      │  Moodle-Docker (nuevo)      │ │
│  │ (HTTPS/SSL)      │◄────►│  ┌───────┐  ┌───────────┐   │ │
│  └──────────────────┘      │  │  web  │  │  moodle   │   │ │
│         ▲                  │  │nginx  │  │php-fpm    │   │ │
│         │                  │  └───┬───┘  └─────┬─────┘   │ │
│         │                  │      │            │         │ │
│  Usuarios finales          │  phpsocket    moodle-data  │ │
│                            │      │            │         │ │
│  ┌──────────────────┐      │  ┌───▼────────────▼───┐     │ │
│  │ mariadb_10.11.16 │◄─────┘  │   redis:7-alpine   │     │ │
│  │ (red Docker)     │         └────────────────────┘     │ │
│  └──────────────────┘                                       │
│                                                             │
│  (moodle-data montado desde contenedor anterior)            │
│  (moodle-code empaquetado en la imagen Docker)              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Decisiones técnicas y porqué se tomaron

### 2.1. Uso de base de datos externa (MariaDB 10.11.16)

**Decisión**: No usar el perfil `with-db` y conectar a un contenedor MariaDB ya existente.

**Por qué**:
- La infraestructura de BD ya estaba desplegada (`moodle_mariadb_10.11.16`).
- Replicar la BD en un nuevo contenedor habría implicado migrar datos y duplicar recursos.
- El acceso por red Docker interna (nombre de contenedor + puerto 3306) es más seguro y robusto que exponer puertos al host.

**Implementación**:
- `MOODLE_DB_HOST=moodle_mariadb_10.11.16` en `.env`.
- Red externa `mariadb_10.11.16_network` añadida al servicio `moodle` en `docker-compose.yml`.
- El `Dockerfile` no instala cliente MariaDB innecesario; solo las extensiones PHP (`mysqli`, `pdo_mysql`).

### 2.2. `moodle-code` empaquetado en la imagen

**Decisión**: Copiar el `moodle-code` completo del contenedor anterior al contexto de build y luego hacer `COPY` en el `Dockerfile`.

**Por qué**:
- El build de la imagen requiere que exista `moodle-code` en el contexto (líneas 72-77 del `Dockerfile`).
- Copiarlo del contenedor anterior garantiza que todos los plugins de terceros, el tema Moove, los scripts custom (`decalogo/`, `soporte/`, etc.) y cualquier parche estén presentes.
- Es una solución pragmática para una migración urgente. El estudio `Estudio-moodle-code-to-container.md` detalla cómo refactorizar esto a una imagen 100% autocontenida en el futuro.

**Riesgo mitigado**: Si se hubiera usado un `moodle-code` vacío o genérico, faltarían plugins y el sitio no funcionaría con la BD existente.

### 2.3. `moodle-data` como volumen compartido (no copiado)

**Decisión**: Montar el `moodle-data` del contenedor anterior en `/var/www/moodledata` en lugar de copiarlo al directorio del proyecto.

**Por qué**:
- El usuario confirmó que el servidor es de **testing**.
- En producción, el `moodle-data` residirá en un sistema de replicación tipo **GlusterFS/Galera**, por lo que el modelo de volumen compartido es arquitectónicamente coherente.
- Evita duplicar ~10-20 GB de archivos subidos, caché e idiomas.

**Restricción crítica**: Nunca levantar el contenedor anterior y el nuevo simultáneamente. Moodle no soporta que dos instancias compartan el mismo `dataroot`.

### 2.4. Corrección de `libaio1` en el Dockerfile

**Decisión**: Eliminar el paquete `libaio1` de la instalación de dependencias del sistema.

**Por qué**:
- La imagen base `php:8.1-fpm` actual usa Debian Trixie (rama en desarrollo), donde el paquete `libaio1` ha desaparecido de los repositorios.
- Moodle con MariaDB no requiere `libaio1` (es exclusivo de Oracle DB).
- El build fallaba con `exit code 100` por este paquete.

### 2.5. `INSTALL_TYPE=upgrade`

**Decisión**: Usar `upgrade` en lugar de `new-install`.

**Por qué**:
- La base de datos `moodle` en MariaDB 10.11.16 ya contenía datos de la instancia anterior (Moodle 4.1.3).
- El `entrypoint.sh` detecta la tabla `mdl_config`, ejecuta `upgrade.php --non-interactive --allow-unstable` y luego los scripts de `init-scripts/upgrade/`.
- Usar `new-install` habría intentado crear tablas duplicadas y fallado.

---

## 3. Problemas encontrados y resoluciones

| Problema | Causa | Solución |
|----------|-------|----------|
| `failed to compute cache key: "/moodle-code": not found` | El directorio `moodle-code` no existía en el contexto de build. | Copiar `moodle-code` del contenedor anterior al proyecto. |
| `E: Unable to locate package libaio1` | Debian Trixie ya no tiene este paquete. | Eliminar `libaio1` del `Dockerfile`. |
| `$CFG->dataroot is not writable` | El `moodle-data` local creado por Docker pertenecía a `root:root`. | Cambiar a montar el `moodle-data` del contenedor anterior (`www-data:www-data`). |
| Tema Moove no se veía / idioma español fallaba | El `moodle-data` nuevo estaba vacío; faltaban `lang/es/`, `temp/theme/moove/` y `filedir/`. | Montar el `moodle-data` completo del contenedor anterior, que incluye todos los recursos. |
| Error `lang` en External API (`Invalid external api parameter`) | El cliente JS enviaba `lang=es` pero el servidor no encontraba el paquete de idioma en el filesystem. | Resuelto al usar el `moodle-data` correcto con `lang/es/` presente. |

---

## 4. Flujo de los scripts de inicialización (estado actual)

El `entrypoint.sh` ejecuta el siguiente flujo en cada arranque:

1. **Restaurar código si bind mount vacío**: si `/var/www/html/config.php` no existe pero existe `/usr/src/moodle/config-dist.php`, copia el código empaquetado en la imagen.
2. **Esperar a la base de datos**: bucle hasta que `moodle_mariadb_10.11.16:3306` responda.
3. **Comprobar si Moodle ya está instalado**: consulta si existe la tabla `mdl_config`.
4. **Si ya está instalado y `INSTALL_TYPE=upgrade`**:
   - Ejecuta `admin/cli/upgrade.php --non-interactive --allow-unstable`.
   - Ejecuta `/init-scripts/init.sh`, que lanza secuencialmente:
     1. `upgrade/moodle.sh` (expect + ajustes post-upgrade)
     2. `upgrade/plugins.sh` (reinstalación de plugins)
     3. `upgrade/theme.sh` (reaplicación de tema Moove + SCSS custom)
5. **Purgar cachés** y arrancar `php-fpm`.

> **Nota**: Los scripts de `new-install/` (`moodle.sh`, `plugins.sh`, `import_FPD_categories_and_courses.sh`, `theme.sh`) **no se ejecutan** en este despliegue porque `INSTALL_TYPE=upgrade`. Quedan disponibles para futuras instalaciones limpias.

---

## 5. Inventario de plugins y componentes no estándar

### Plugins de terceros empaquetados en la imagen (detectados en moodle-code)

| Tipo | Plugin | Componente |
|------|--------|-----------|
| Módulo | Attendance | `mod_attendance` |
| Módulo | Board | `mod_board` |
| Módulo | Checklist | `mod_checklist` |
| Módulo | Choice Group | `mod_choicegroup` |
| Módulo | Google Meet | `mod_googlemeet` |
| Módulo | PDF Annotator | `mod_pdfannotator` |
| Bloque | Completion Progress | `block_completion_progress` |
| Bloque | Grade Me | `block_grade_me` |
| Bloque | Sharing Cart | `block_sharing_cart` |
| Bloque | Level Up XP | `block_xp` |
| Local | EducaAragon | `local_educaaragon` |
| Local | Mail | `local_mail` |
| Local | Reminders | `local_reminders` |
| Tema | Moove | `theme_moove` |
| Informe | Course Statistics | `report_coursestats` |
| Tipo pregunta | GapFill | `qtype_gapfill` |
| Regla cuestionario | One Session | `quizaccess_onesession` |
| Editor Atto | Components for Learning | `atto_c4l` |
| Editor Atto | Fullscreen | `atto_fullscreen` |
| Condición disponibilidad | Level Up XP | `availability_xp` |

### Scripts/aplicaciones PHP custom (no plugins)

Estos directorios residen en la raíz del documento web (`/var/www/html/`) y deben gestionarse manualmente en futuras refactorizaciones:

- `decalogo/` — Imágenes del decálogo metodológico FP Virtual.
- `faqs/` — Imágenes y recursos de preguntas frecuentes.
- `private-reports/` — Scripts PHP internos (`docentes.php`, `inspeccion.php`, `jefaturas.php`, `mensajeria.php`).
- `soporte/` y `soporte2/` — Formularios de soporte con captcha.
- `userpix/` — Gestión de avatares.

---

## 6. Pasos para replicar este despliegue en otro servidor

Si fuera necesario levantar esta misma instancia en otro host (p. ej. con GlusterFS):

1. **Clonar el repositorio** `new-moodle`.
2. **Copiar el `moodle-code`** del backup o del contenedor anterior al directorio del proyecto.
3. **Configurar `.env`** con las credenciales de la BD externa y el dominio correspondiente.
4. **Modificar `docker-compose.yml`**:
   - Ajustar la ruta del volumen `moodle-data` al punto de montaje de GlusterFS.
   - Asegurar que la red externa de la BD (`mariadb_10.11.16_network` o equivalente) esté definida.
5. **Build y despliegue**:
   ```bash
   docker compose up -d --build
   ```
6. **Verificar logs**:
   ```bash
   docker compose logs -f moodle
   ```

---

## 7. Notas para el paso a producción con GlusterFS/Galera

### `moodle-data`
- **Actual**: bind mount a directorio local del host (`/var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-data`).
- **Futuro**: volumen Docker nombrado o bind mount a un filesystem GlusterFS replicado.
- **Requisito**: El filesystem debe soportar bloqueos de archivo (file locking) para que la caché de Moodle (`muc/`, `cache/`) funcione correctamente.

### Base de datos
- **Actual**: MariaDB 10.11.16 en contenedor Docker individual.
- **Futuro**: Clúster Galera (multi-master) o replicación master-slave.
- **Consideración**: Moodle requiere que las tablas usen `InnoDB` (ya es el default en MariaDB 10.11).

### Imagen Docker
- **Actual**: build local con `moodle-code` copiado manualmente.
- **Futuro**: build automatizado en CI/CD que descargue Moodle core + plugins desde git y empaquete los scripts custom.

### Proxy y SSL
- El proxy inverso (`nginx-proxy`) gestiona automáticamente los certificados Let's Encrypt.
- Al migrar a otro servidor, solo hay que asegurar que la red `nginx-proxy_frontend` exista y que el nuevo contenedor `web` se conecte a ella.

---

## 8. Resumen de archivos modificados en esta migración

| Archivo | Cambio realizado |
|---------|-----------------|
| `.env` | Creado desde `.env.example` fusionando datos del contenedor anterior (dominio, admin, SMTP, contraseñas FPD/Blackboard) y de MariaDB 10.11.16 (host, credenciales). `INSTALL_TYPE=upgrade`, `VERSION=4.1.19`. |
| `docker-compose.yml` | `MOODLE_DB_HOST` y `MOODLE_DB_PORT` pasan a leer variables de entorno (antes hardcodeados a `db` y `3306`). Añadida red externa `mariadb_10.11.16_network`. Volumen `moodle-data` apunta al directorio del contenedor anterior. |
| `Dockerfile` | Eliminado paquete `libaio1` de la lista de dependencias del sistema. |
| `moodle-code/` | Copiado completamente desde `/var/moodle-docker-deploy/www.fpvirtualaragon.es/moodle-code/` para garantizar concordancia de plugins y temas. |
| `Estudio-moodle-code-to-container.md` | Documento creado con análisis de plugins y estrategia de refactorización futura. |

---

## 9. Estado operativo actual

```bash
# Contenedores activos
fpd-moodle    Up  (php-fpm 9000)
fpd-web       Up  (nginx 80)
fpd-redis     Up  (redis 6379, healthy)

# Base de datos
moodle_mariadb_10.11.16    Up  (3306/tcp, healthy)

# Proxy
nginx-proxy                Up
nginx-proxy-lets-encrypt   Up

# Acceso web
https://redestel.fpvirtualaragon.es
```

> **Última verificación**: Tema Moove activo, idioma español (`es`) funcionando, login operativo, y upgrade de esquema de BD completado sin errores.
