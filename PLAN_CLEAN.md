# PLAN_CLEAN — Plan de limpieza y refactor arquitectónico

> Auditoría realizada el 2026-09-08 sobre la rama `apache-moodle`.
> Marca las casas con `[x]` conforme avances. Cada fase es un commit (o varios) independiente.
> ⚠️ Antes de empezar: el repo está limpio según `git status`. Confirma que no hay trabajo sin commitear.

---

## FASE 0 — Seguridad e higiene del repositorio

Prioridad: **ALTA** (credenciales expuestas en git). Reversible y sin impacto en runtime.

### 0.1 Rotar credenciales expuestas

- [ ] **Redmine** (API key + usuario/contraseña de `custom/soporte/secret.php`)
- [ ] **Base de datos** (password de `MOODLE_DB_PASSWORD`, visible en `.env.save`)
- [ ] **Admin Moodle** (`MOODLE_ADMIN_PASSWORD`)
- [ ] **SMTP** (`SMTP_PASSWORD`) y **Airnotifier** (access key en claro en `init-scripts/new-install/moodle.sh:187`)
- [ ] Usuario `moodle-api` (`API_USER_PASSWORD`) y demás passwords de `.env.save`
- [ ] Decidir si el repo es/será público: si sí, purgar credenciales del historial (`git filter-repo` o BFG) — si es privado interno, basta con rotar

### 0.2 Quitar secretos y basura trackeada

- [ ] `git rm .env.save`
- [ ] `git rm custom/soporte/secret.php` y `git rm custom/soporte/log.txt` (12 MB de log)
- [ ] `git rm -r __pycache__` y `git rm Moodle-API-Test/__pycache__/*.pyc`
- [ ] `git rm php-conf/salida.txt` (vacío)
- [ ] `git rm init-scripts/themes/fpdist/roles/*.xml.old`
- [ ] Commit: `chore(seguridad): elimina credenciales y archivos basura trackeados`

### 0.3 Quitar diagnósticos one-shot de la raíz

- [ ] `git rm diagnose_hook.php diagnose_menu.php diagnose_menu2.php test_navigation.php test_navigation2.php fix_permissions.php test_jefaturas_refactor.sh`
- [ ] Commit: `chore: elimina scripts de diagnóstico one-shot`

### 0.4 Archivar planes ya consumidos

- [ ] Crear `docs/archivo/`
- [ ] `git mv PLAN_API_FIX.md docs/archivo/` (marcado como COMPLETADO)
- [ ] `git mv cambios-moodle-4.5.patch fix_idnumber_categories.sql docs/archivo/`
- [ ] `git mv docs/Analisis-merge-con-moodle-docker-deploy.md docs/archivo/`
- [ ] `git mv docs/Migracion-procedimiento-plugins-a-main.md docs/archivo/`
- [ ] `git mv docs/RAMA-apache-moodle.md docs/RAMA-creacion_moodle-data_propio.md docs/archivo/`
- [ ] `git mv docs/Compatibilidad-RHEL.md docs/Analisis-sistema.md docs/Estudio-moodle-code-to-container.md docs/archivo/`
- [ ] Revisar `docs/theme_fpd_files.tar.gz` (binario sin referencias): archivar o eliminar
- [ ] Commit: `docs: archiva análisis y planes históricos`

### 0.5 Blindar `.gitignore`

- [ ] Añadir: `__pycache__/`, `*.pyc`, `.env.*`, `*.log`, `custom/soporte/secret.php`, `Moodle-API-Test/backups_moodle/`
- [ ] Commit: `chore: refuerza .gitignore contra secretos y basura generada`

### 0.6 Unificar el formulario de soporte

- [ ] Decidir versión canónica: `custom/soporte/` vs `init-scripts/themes/fpdist/soporte/` (divergentes, URLs distintas)
- [ ] Eliminar la no canónica
- [ ] Corregir `init-scripts/new-install/theme.sh:29-34`: no crear directorios anidados (`/soporte/soporte/`), no sobrescribir `secret.php` con el sample
- [ ] Añadir `custom/soporte/secret.php` generado desde `secret-sample.php` + variable de entorno
- [ ] Commit: `fix(soporte): unifica formulario y corrige colisión en theme.sh`

---

## FASE 1 — Pipeline de instalación fiable

Hacer **antes del próximo upgrade de Moodle** o en una ventana de pruebas (cada install es nueva, se puede validar sin tocar prod).

### 1.1 Versionar los datos de inicialización

- [ ] Crear `init-data/data/` en el repo con CSV **sintéticos/de ejemplo** (categorías, cohortes, cursos, usuarios, usuarios_test, matriculaciones_test, jefaturas)
- [ ] Localizar el `read_csv.php` real (no está en el repo, requisito de 7 bucles) y versionarlo en `init-data/data/`
- [ ] Ajustar `.gitignore` para permitir `init-data/data/**` y seguir ignorando `init-data/mbzs/`
- [ ] En prod, los CSV reales se sobreescriben vía bind mount (ya montado en `docker-compose.yml:80`)
- [ ] Commit: `feat(init): versiona CSVs de ejemplo y read_csv.php`

### 1.2 Orquestador estricto

- [ ] Modificar `init-scripts/init.sh`: fallar (exit ≠ 0) si falla un script crítico (`moodle.sh`, `plugins.sh`, `load_usuarios.sh`, `import_...sh`); opcional continuar solo en `test_data.sh`
- [ ] Añadir chequeos previos: existencia de CSV, `read_csv.php`, conexión BD, moosh operativo
- [ ] Quitar el flag huérfano `.moodle-installed` de `entrypoint.sh:94` (el criterio real es `mdl_config`, líneas 68-76)
- [ ] Quitar `|| true` de `entrypoint.sh:88` en `install_database.php`
- [ ] Commit: `fix(init): orquestador estricto con validaciones previas`

### 1.3 Helper común de acceso a Moodle

- [ ] Crear `init-scripts/lib/moodle-lib.sh` con:
  - `moodle_id` — sustituir los ~10 parseos `awk '/[id] =>/ {print $3}'` por un único helper
  - `moodle_user_create` — unificar los 3 sitios que crean usuarios (`load_usuarios.sh:29`, `import:78-96`, `test_data.sh:27-42`) y el bloque de fallback de contraseña duplicado
- [ ] Migrar los scripts consumidores
- [ ] Commit: `refactor(init): extrae moodle-lib.sh y elimina duplicación`

### 1.4 Una sola fuente de verdad para plugins

- [ ] Decidir: **pinning por git en build** (recomendado) → eliminar `moosh plugin-install -d` de `plugins.sh:131-133` que borra el plugin clonado y reinstala desde moodle.org anulando el `git_branch`
- [ ] Eliminar la dualidad `/init-data/plugins.json` vs `/init-scripts/plugins.json` en `plugins-lib.sh:12-16`: montar solo `/init-data` (exigirlo) o copiar siempre al arrancar
- [ ] Limpiar código muerto: bloque `block_configurable_reports` en `plugins.sh:68-82` (el plugin ya no está en el catálogo) y vars huérfanas `PLUGIN_BLOCK_CONFIGURABLE_REPORTS` / `PLUGIN_REPORT_COURSESTATS` en `.env.example`
- [ ] Clonar solo plugins habilitados en build (ahora `docker-clone-plugins.sh` clona todos, líneas 28-60)
- [ ] Commit: `refactor(plugins): unifica fuente de verdad y respeta pinning por git`

### 1.5 Datos hardcodeados → configuración

- [ ] Mover la access key de Airnotifier (`moodle.sh:187`) a variable de entorno
- [ ] Eliminar suposiciones frágiles donde sea posible: `siteadmins="2"` (`import:46-49`), `fieldid=1` (`import:143`) — resolver por consulta en vez de asumir IDs
- [ ] Revisar hardcodeos de nombres de cursos/cohortes (`import:235-270`) y pasarlos a `jefaturas.csv`/config si procede
- [ ] Commit: `refactor(init): externaliza secretos y elimina IDs mágicos`

---

## FASE 2 — Claridad del despliegue Docker

### 2.1 Un despliegue, una verdad

- [ ] Documentar en `docker-compose.yml` (comentario o `networks:` externa) la red real de la BD externa (`mariadb_10.11.16_network` según `.env.save`)
- [ ] Decidir el acceso web: ¿puerto 8080 directo (`compose:87`) o proxy nginx-proxy? Eliminar/documentar la opción no usada
- [ ] Eliminar el perfil `with-db` o invertirlo a `dev-db` (no se usa en prod)
- [ ] Eliminar variables huérfanas: `VIRTUAL_HOST`, `SSL_EMAIL` (sin consumidor), `SSL_PROXY` (se pasa en `compose:61` pero nadie la usa)
- [ ] Commit: `chore(compose): documenta despliegue real y elimina opciones muertas`

### 2.2 Corregir defaults

- [ ] `Dockerfile:4` y `docker-compose.yml:41`: `PHP_BASE_IMAGE` default → `php:8.2-apache`
- [ ] `.env.example:15`: borrar resto de la era nginx/php-fpm
- [ ] Commit: `fix(build): defaults coherentes con PHP 8.2`

### 2.3 Build reproducible

- [ ] Fijar `composer:2.x` (ahora `composer:latest`, `Dockerfile:62`)
- [ ] Fijar moosh por tag/commit (ahora master, `Dockerfile:65-69`)
- [ ] Fijar `pecl install redis-X.Y.Z` (`Dockerfile:56`)
- [ ] Considerar checksum del tarball de Moodle (`Dockerfile:75`)
- [ ] Commit: `build: fija versiones de herramientas para reproducibilidad`

### 2.4 Reparar y limpiar runtime

- [ ] `scripts/backup.sh:7-8`: corregir nombres de contenedores (`fpvirtual-*` según compose) o usar `docker compose exec`; hacer que cargue `.env` él mismo
- [ ] Quitar paquetes innecesarios del Dockerfile: `cron` (instalado, nunca ejecutado), `libmemcached-dev`, libs X11/xfonts si ghostscript no los necesita, `vim`/`nano` si se quiere imagen slim
- [ ] Eliminar `php-conf/zzz-disable-apcu.ini` (vacío; APCu ni se instala; la desactivación real ya está en `uploads.ini:9-12`)
- [ ] Revisar si la restauración desde `/usr/src/moodle` (entrypoint.sh:5-10) debe incluir plugins+custom para que un volumen vacío reproduzca la imagen completa
- [ ] `MOODLE_DB_PORT`: separar semántica de puerto de publicación del perfil interno vs. puerto de conexión a BD externa
- [ ] Commit: `fix(runtime): backup funcional y build más limpio`

---

## FASE 3 — Reestructuración de directorios (opcional, cuando 0-2 estén estables)

- [ ] `docker/` ← Dockerfile, docker-compose*.yml, entrypoint.sh, apache-conf/, php-conf/
- [ ] `init/` ← init-scripts/ + init-data/ (renombrar a `install/` + `data/`)
- [ ] `web/` ← custom/ (renombrado; subdirectorios autodescriptivos)
- [ ] `tools/` ← scripts/backup.sh, generar_configuracion.py, Moodle-API-Test/
- [ ] Actualizar rutas en Dockerfile, compose, entrypoint, AGENTS.md y docs vivos
- [ ] Commit: `refactor: reestructura directorios en docker/init/web/tools`

---

## FASE 4 — Documentación

- [ ] Actualizar `AGENTS.md`: orden real de scripts en `init.sh` (differe de lo documentado), CSVs ahora en `init-data/data/` (no `new-install/data/`), `import_...sh` ya no tiene array de 750 líneas, estado de plugins
- [ ] Actualizar `README.md`: despliegue real (BD externa, puerto, red)
- [ ] Actualizar `UPGRADE.md` con el nuevo flujo de plugins (pinning por git)
- [ ] Eliminar advertencias/obsoletos del propio AGENTS.md
- [ ] Commit: `docs: sincroniza AGENTS.md/README con la realidad`

---

## Verificación final

- [ ] `docker compose config` válido
- [ ] Build de imagen desde cero (`docker compose build --no-cache`) sin warnings de versiones
- [ ] Instalación limpia en entorno de prueba con CSVs de ejemplo → revisar logs del orquestador (debe fallar en seco ante fallos, no continuar)
- [ ] `admin/cli/check_database_schema.php` y `admin/cli/purge_caches.php` OK
- [ ] `scripts/backup.sh` genera backup real
- [ ] Plugins críticos funcionan: `format_tiles`, `theme_moove`, `local_mail`, `mod_board`, `local_educaaragon`
- [ ] `git ls-files` sin secretos ni basura; `git log -p | grep -i password` limpio (salvo histórico a purgar en 0.1)
