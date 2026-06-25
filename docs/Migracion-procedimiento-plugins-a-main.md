# Migración del procedimiento automatizado de carga de plugins a `main`

> Análisis de diferencias entre las ramas `main` y `apache-moodle` y propuesta de cambios para llevar el procedimiento automatizado de carga de plugins a `main`.

---

## 1. Objetivo

El objetivo de este documento es analizar en qué se diferencian las ramas `main` y `apache-moodle` respecto al **procedimiento automatizado de carga de plugins**, y definir qué cambios hay que aplicar en `main` para que disponga de las mejoras desarrolladas en `apache-moodle`.

---

## 2. Resumen ejecutivo

- **`main` ya dispone del procedimiento base** de carga automatizada de plugins mediante `plugins.json` (ubicado en la raíz), `docker-clone-plugins.sh`, `plugins-lib.sh` y `plugins.sh`.
- En `apache-moodle` el catálogo se ha movido a **`init-data/plugins.json`** para permitir su edición en runtime sin reconstruir la imagen.
- La rama `apache-moodle` aporta **mejoras puntuales** sobre ese procedimiento:
  1. Configuración automática del plugin `local_educaaragon` (repositorio filesystem + montaje de `recursos-editables`).
  2. Corrección de la rama de `mod_googlemeet` (de `2.7.3` a `master`).
  3. Documentación y advertencias asociadas en `AGENTS.md`.
- Los cambios son **casi independientes del cambio de stack** (nginx + php-fpm → Apache + mod_php), aunque el montaje de `recursos-editables` en `docker-compose.yml` debe adaptarse si `main` conserva nginx/php-fpm.

---

## 3. Estado de las ramas

### Commit base común

```text
40be8df6 refactor(test-data): separa datos de test en script condicional
```

### Últimos commits relevantes

| Rama | Commit | Descripción |
|------|--------|-------------|
| `main` | `74ef9dc6` | `feat(plugins): añade local_educaaragon (Educa Aragon)` |
| `apache-moodle` | `50fe5179` | `docs(agents): añade advertencia sobre symlinks en moodledata/repository` |
| `apache-moodle` | `08cd6151` | `fix(educaaragon): corrige constante inexistente REPOSITORY_INSTANCE_VISIBLE` |
| `apache-moodle` | `cd0ca05f` | `feat(educaaragon): configura repositorio filesystem y monta recursos-editables` |

### Diferencia resumida (`git diff --stat main..apache-moodle`)

```text
 .env.example                                   |  18 +-
 .gitignore                                     |   1 +
 AGENTS.md                                      |   5 +
 Dockerfile                                     |  15 +-
 apache-conf/000-default.conf                   |  20 ++
 docker-compose.yml                             |  38 +--
 fpm-conf/docker.conf                           |  15 -
 fpm-conf/www.conf                              | 443 -------------------------
 fpm-conf/zz-docker.conf                        |   9 -
 init-scripts/new-install/educaaragon_setup.php |  66 ++++
 init-scripts/new-install/plugins.sh            |   4 +
 nginx/default.conf                             |  90 -----
 plugins.json                                   |   2 +-
 13 files changed, 127 insertions(+), 599 deletions(-)
```

> La gran mayoría de las diferencias (599 líneas eliminadas) corresponden a la migración del stack nginx/php-fpm a Apache, **no al procedimiento de plugins**.

---

## 4. Arquitectura del procedimiento automatizado de carga de plugins

El procedimiento consta de los siguientes componentes:

| Componente | Rol | ¿Está en `main`? |
|------------|-----|------------------|
| `init-data/plugins.json` | Catálogo maestro de plugins de terceros con `name`, `component`, `moodle_path`, `git_url`, `git_branch`, `default_enabled`, etc. | ✅ Sí (en raíz en `main`; en `init-data/` en `apache-moodle`) |
| `init-scripts/lib/docker-clone-plugins.sh` | Clona los plugins desde Git en build-time según el catálogo. | ✅ Sí |
| `init-scripts/lib/plugins-lib.sh` | Helpers para leer el catálogo y determinar qué plugins están habilitados según variables `PLUGIN_*` del `.env`. | ✅ Sí (con soporte a `/init-data/plugins.json` solo en `apache-moodle`) |
| `init-scripts/new-install/plugins.sh` | Orquesta la instalación con `moosh plugin-install` y ejecuta acciones post-instalación. | ✅ Sí, con diferencias |
| `init-scripts/new-install/educaaragon_setup.php` | Configura el plugin `local_educaaragon` creando un repositorio filesystem. | ❌ No (solo en `apache-moodle`) |
| `.env.example` | Define variables `PLUGIN_*` y, en `apache-moodle`, `EDUCAARAGON_RESOURCES_PATH`. | ✅ Parcialmente |
| `docker-compose.yml` | Monta el volumen de `recursos-editables` en `/var/www/moodledata/repository/recursos-editables`. | ❌ Solo en `apache-moodle` |
| `AGENTS.md` | Documenta el procedimiento y advertencias de seguridad. | ✅ Parcialmente |

---

## 5. Diferencias detalladas del procedimiento de plugins

### 5.1 `init-data/plugins.json` (antes `plugins.json` en raíz)

Cambios en el catálogo:

1. **Ubicación**: el archivo pasa de la raíz (`plugins.json`) a `init-data/plugins.json`, para que pueda editarse en runtime sin reconstruir la imagen.
2. **Rama de `mod_googlemeet`**:

```diff
       "git_url": "https://github.com/hyukudan/moodle-mod_googlemeet.git",
-      "git_branch": "2.7.3",
+      "git_branch": "master",
       "default_enabled": true,
```

**Impacto:** En `main` se pincha la etiqueta `2.7.3`; en `apache-moodle` se usa `master` y además el catálogo es editable en runtime. Si el fork `hyukudan` ha seguido desarrollando en `master`, `main` podría estar instalando una versión desactualizada o con errores corregidos en `master`.

### 5.2 `init-scripts/new-install/plugins.sh`

Se añade un caso en `actions_asociated_to_plugin()` para `local_educaaragon`:

```bash
"local_educaaragon")
    echo "Configuring local_educaaragon..."
    php /init-scripts/new-install/educaaragon_setup.php
    ;;
```

**Impacto:** Sin este cambio, el plugin `local_educaaragon` se instala pero no se configura automáticamente. El plugin queda inactivo hasta intervención manual.

### 5.3 `init-scripts/new-install/educaaragon_setup.php` (nuevo)

Script PHP que:

1. Activa el tipo de repositorio `filesystem` si no está activo.
2. Crea una instancia de repositorio apuntando a `recursos-editables`.
3. Configura el plugin `local_educaaragon`:
   - `activetask = 1`
   - `repository = <id_del_repositorio>`
   - `allcourses = 1`

**Dependencia:** requiere que el directorio `moodledata/repository/recursos-editables` exista y sea accesible.

### 5.4 `.env.example`

En `apache-moodle` se añade:

```ini
# =============================================================================
# Plugin local_educaaragon (Educa Aragon)
# =============================================================================
EDUCAARAGON_RESOURCES_PATH=./recursos-editables
```

También se reubica `MARIADB_IMAGE` en la sección de base de datos (cambio cosmético, no afecta al procedimiento de plugins).

### 5.5 `docker-compose.yml`

En `apache-moodle` se añade el montaje:

```yaml
volumes:
  - ./moodle-data:/var/www/moodledata
  - ${EDUCAARAGON_RESOURCES_PATH:-./recursos-editables}:/var/www/moodledata/repository/recursos-editables
```

**Impacto:** este volumen es imprescindible para que `educaaragon_setup.php` y el plugin `local_educaaragon` encuentren los recursos editables.

> Si `main` conserva nginx + php-fpm, este montaje debe añadirse al servicio `moodle` (php-fpm), no al servicio `web` (nginx), ya que el código PHP se ejecuta en el contenedor de PHP.

### 5.6 `.gitignore`

Se añade:

```gitignore
/recursos-editables/*
```

Esto evita que el contenido de los recursos editables se comitee accidentalmente.

### 5.7 `AGENTS.md`

Se documenta:

- La configuración automática de `local_educaaragon` en `plugins.sh`.
- La variable `EDUCAARAGON_RESOURCES_PATH`.
- La advertencia de no usar symlinks absolutos dentro de `moodle-data/repository/`.

---

## 6. Modificaciones necesarias en `main`

Para llevar a `main` el procedimiento automatizado de carga de plugins tal como está en `apache-moodle`, se deben aplicar los siguientes cambios **mínimos**:

### 6.1 Archivos imprescindibles

1. **`init-data/plugins.json`** (nueva ubicación)
   - Mover el archivo de la raíz a `init-data/plugins.json`.
   - Cambiar `"git_branch": "2.7.3"` por `"git_branch": "master"` en `mod_googlemeet`.
   - Actualizar `.gitignore` para no ignorar `init-data/plugins.json`.

2. **`init-scripts/new-install/plugins.sh`**
   - Añadir el caso `local_educaaragon` en `actions_asociated_to_plugin()`.

3. **`init-scripts/new-install/educaaragon_setup.php`**
   - Crear el archivo nuevo.

4. **`.env.example`**
   - Añadir la sección `EDUCAARAGON_RESOURCES_PATH`.

5. **`docker-compose.yml`**
   - Añadir el montaje de `recursos-editables` en el servicio `moodle`.

6. **`.gitignore`**
   - Añadir `/recursos-editables/*`.

7. **`AGENTS.md`**
   - Documentar la configuración de `local_educaaragon` y la advertencia de symlinks.

### 6.2 Adaptaciones según el stack de `main`

Si `main` mantiene **nginx + php-fpm**:

- El volumen de `recursos-editables` debe montarse en el servicio `moodle` (php-fpm), no en `web`.
- No es necesario copiar `apache-conf/000-default.conf` ni cambiar el `Dockerfile`.
- No es necesario eliminar `fpm-conf/` ni `nginx/`.

Si `main` adopta **Apache + mod_php**:

- Además de los cambios de plugins, habría que llevar todo el cambio de stack (`Dockerfile`, `apache-conf/`, `docker-compose.yml`, eliminación de `fpm-conf/` y `nginx/`). Esto ya no es solo "procedimiento de plugins", sino una migración de stack completa.

---

## 7. Procedimiento sugerido de merge

### Opción A: Merge mínimo (solo mejoras de plugins)

Aplicar solo los cambios listados en el apartado 6.1, respetando el stack actual de `main`.

Pasos:

```bash
# Desde la rama main
git checkout main
git pull origin main

# Aplicar cambios puntuales desde apache-moodle
git checkout apache-moodle -- init-scripts/new-install/educaaragon_setup.php
git checkout apache-moodle -- init-scripts/new-install/plugins.sh
git checkout apache-moodle -- init-data/plugins.json
# (también hay que asegurar que el Dockerfile de main copie desde init-data/plugins.json)
git checkout apache-moodle -- .env.example
git checkout apache-moodle -- .gitignore
git checkout apache-moodle -- AGENTS.md

# docker-compose.yml: revisar manualmente para adaptar al stack de main
# Editar docker-compose.yml y añadir solo el volumen de recursos-editables
# en el servicio moodle (php-fpm).
```

### Opción B: Merge completo de `apache-moodle` a `main`

Si se decide que `main` debe adoptar todo el stack Apache:

```bash
git checkout main
git merge apache-moodle
# Resolver conflictos, especialmente en docker-compose.yml, Dockerfile y .env.example
```

**Recomendación:** utilizar la **Opción A** si el objetivo es exclusivamente mejorar el procedimiento de carga de plugins, sin forzar la migración de stack.

---

## 8. Riesgos y consideraciones

| Riesgo | Descripción | Mitigación |
|--------|-------------|------------|
| Cambio de rama de `mod_googlemeet` | Pasar de `2.7.3` a `master` puede introducir cambios no probados. | Revisar el diff entre `2.7.3` y `master` en el fork `hyukudan`; probar en entorno de preproducción. |
| Plugin `local_educaaragon` sin repositorio | Si no se monta `recursos-editables`, `educaaragon_setup.php` creará el repositorio pero apuntará a un directorio vacío. | Asegurar que `EDUCAARAGON_RESOURCES_PATH` apunta a un directorio existente con contenido. |
| Symlinks absolutos en `moodle-data/repository/` | Docker no resuelve symlinks absolutos del host dentro del contenedor. | Usar siempre bind mounts relativos en `docker-compose.yml`; no crear symlinks absolutos. |
| Stack diferente | `main` usa php-fpm; el volumen debe ir en el contenedor correcto. | Revisar `docker-compose.yml` antes de desplegar. |
| Permisos de `moodle-data/repository/recursos-editables` | El usuario `www-data` del contenedor debe poder leer el directorio. | Verificar propietario y permisos del directorio en el host. |

---

## 9. Checklist de verificación

Tras aplicar los cambios en `main`:

- [ ] `init-data/plugins.json` existe y tiene `mod_googlemeet.git_branch = "master"`.
- [ ] El `Dockerfile` copia `init-data/plugins.json` a `/init-scripts/plugins.json`.
- [ ] `plugins-lib.sh` lee preferentemente `/init-data/plugins.json` en runtime.
- [ ] `plugins.sh` incluye el caso `local_educaaragon`.
- [ ] `educaaragon_setup.php` existe y es ejecutable por el contenedor.
- [ ] `.env.example` incluye `EDUCAARAGON_RESOURCES_PATH`.
- [ ] `docker-compose.yml` monta `recursos-editables` en el servicio `moodle`.
- [ ] `.gitignore` ignora el contenido de `/recursos-editables/*`.
- [ ] `AGENTS.md` documenta el plugin `local_educaaragon` y la advertencia de symlinks.
- [ ] El build de la imagen Docker completa sin errores.
- [ ] En una instalación nueva, `local_educaaragon` se instala y configura automáticamente.
- [ ] El repositorio filesystem "Recursos Editables" aparece en Moodle con la ruta `recursos-editables`.
- [ ] `mod_googlemeet` se clona desde la rama `master`.

---

## 10. Conclusión

El **procedimiento automatizado de carga de plugins ya existe en `main`**. Lo que aporta `apache-moodle` son mejoras concretas y de bajo riesgo:

1. Configuración automática de `local_educaaragon`.
2. Corrección de la rama de `mod_googlemeet`.
3. Documentación y advertencias operativas.

La migración recomendada es un **merge mínimo** (Opción A) que no altere el stack nginx + php-fpm de `main`, salvo que se decida explícitamente migrar también a Apache + mod_php.
