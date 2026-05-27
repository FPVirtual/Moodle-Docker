# Plan de corrección: API Moodle (moodle-api) sin privilegios de admin

> Fecha: 2026-05-26  
> Estado: Pendiente de implementar los cambios de archivo. El diagnóstico está completo.

---

## 1. PROBLEMAS IDENTIFICADOS

### Bug A: `moosh plugin-install webservice_rest` innecesario
- En Moodle 4.5 REST es un protocolo **core**, no un plugin de terceros.
- `moosh plugin-install` falla porque no encuentra `plugins.json` descargado.

### Bug B: `moosh sql-run` no soporta strings con `:`
- El parser DML de Moodle (`fix_sql_params`) interpreta `:cualquierCosa` como un *named parameter*.
- Falla en cualquier `INSERT/UPDATE` que contenga capacidades como `moodle/user:create`.
- Esto afecta a `api_config.sh` en:
  - Las capacidades del rol (paso 5).
  - El campo `requiredcapability` del servicio externo (paso 7).

### Bug C: `init.sh` no detecta errores
- Si un script del bucle falla, igual imprime `executed!`, ocultando el fallo.
- **Ya corregido** en el repo: ahora verifica exit code y muestra `ERROR`.

### Bug D: `moodle-api` es admin completo
- En `usuarios.csv` figura con rol `admin`.
- `import_FPVirtual_categories_and_courses.sh` lo añade explícitamente a `siteadmins`.
- El objetivo es que sea un **usuario limitado** con rol propio `integracion_api`.

---

## 2. DECISIONES TOMADAS

- **Alternativa elegida**: Separación de privilegios (Alternativa 2).
- `moodle-api` **dejará de ser admin**.
- Se mantendrá el rol `integracion_api` con capacidades mínimas necesarias.
- Las partes que requieren SQL (servicio externo, token, funciones) se harán con un **script PHP CLI nativo** usando la clase `webservice` de Moodle (`/webservice/lib.php`).
- Las partes que tienen comando `moosh` nativo se harán con `moosh`.

---

## 3. ARCHIVOS A MODIFICAR

### 3.1 `init-data/data/usuarios.csv`
**Cambio**: Cambiar el rol de `moodle-api` de `admin` a `user`.

```csv
# ANTES
moodle-api,API_USER_PASSWORD,api@fpvirtualaragon.es,API,Moodle,admin

# DESPUÉS
moodle-api,API_USER_PASSWORD,api@fpvirtualaragon.es,API,Moodle,user
```

> Nota: `load_usuarios.sh` no usa el campo `role` en la creación, pero es correcto reflejarlo.

---

### 3.2 `init-scripts/new-install/import_FPVirtual_categories_and_courses.sh`
**Cambio**: Quitar a `moodle-api` de la lista de `siteadmins`.

**Líneas a modificar** (aprox. líneas 42-51):

```bash
# ANTES
FPD_ADMIN_USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='admin2'" | awk '/\[id\] =>/ {print $3}')
MOODLE_API_USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='moodle-api'" | awk '/\[id\] =>/ {print $3}')

SITEADMINS="2"
[ -n "$FPD_ADMIN_USER_ID" ] && SITEADMINS="${SITEADMINS},${FPD_ADMIN_USER_ID}"
[ -n "$MOODLE_API_USER_ID" ] && SITEADMINS="${SITEADMINS},${MOODLE_API_USER_ID}"

moosh -n config-set siteadmins "${SITEADMINS}"
```

```bash
# DESPUÉS
FPD_ADMIN_USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='admin2'" | awk '/\[id\] =>/ {print $3}')

SITEADMINS="2"
[ -n "$FPD_ADMIN_USER_ID" ] && SITEADMINS="${SITEADMINS},${FPD_ADMIN_USER_ID}"

moosh -n config-set siteadmins "${SITEADMINS}"
```

> También quitar el `if [ -z "$MOODLE_API_USER_ID" ]` y su warning asociado.

---

### 3.3 `init-scripts/new-install/api_config.sh`
**Cambio**: Reescribir completamente. Quedará mucho más corto y robusto.

**Pasos del nuevo script:**

1. Verificar `moosh` (`command -v moosh`).
2. Habilitar webservices (`moosh config-set enablewebservices 1`).
3. Habilitar protocolo REST (`moosh config-set webserviceprotocols rest`).
4. Crear rol `integracion_api` (`moosh role-create`).
5. **NUEVO**: Habilitar contextlevel de sistema para el rol (`moosh role-update-contextlevel --system-on integracion_api`).
6. Asignar capacidades con `moosh role-update-capability` (bucle nativo, sin SQL).
7. Asignar rol al usuario `moodle-api` con `moosh user-assign-system-role moodle-api integracion_api`.
8. Ejecutar el script PHP `api_service_setup.php` para crear el servicio, funciones y token.
9. Limpiar caché (`moosh cache-clear`).

**Capacidades a mantener** (las mismas 26 del script original):
- Usuarios: create, viewalldetails, update, delete, viewhiddendetails
- Cohortes: manage, view
- Cursos: create, update, viewhiddencourses, viewparticipants, manageactivities
- Backup/Restore: backupcourse, restorecourse, restorecourse (restore), backuptargetimport, configure
- Matriculación: manual/enrol, manual/unenrol, manual/manage
- Grupos: managegroups, accessallgroups
- WebServices: rest/use, createtoken, managealltokens
- Archivos: manageownfiles

**Funciones WebService a registrar** (las 27 del script original + posibles adicionales para MBZ/restore si hiciera falta).

---

### 3.4 `init-scripts/new-install/api_service_setup.php` (NUEVO ARCHIVO)
**Cambio**: Crear este script PHP CLI que use la API nativa `webservice` de Moodle.

**Qué debe hacer:**

```php
<?php
define('CLI_SCRIPT', true);
require('/var/www/html/config.php');
require_once($CFG->dirroot . '/webservice/lib.php');

$service_name    = 'Test API';
$service_shortname = 'test_api';
$api_user        = 'moodle-api';

$user = $DB->get_record('user', ['username' => $api_user, 'deleted' => 0]);
if (!$user) {
    fwrite(STDERR, "ERROR: Usuario $api_user no encontrado\n");
    exit(1);
}

$ws = new webservice();

// 1. Crear o actualizar servicio externo
$service = new stdClass();
$service->name             = $service_name;
$service->shortname        = $service_shortname;
$service->enabled          = 1;
$service->restrictedusers  = 1;
$service->downloadfiles    = 1;
$service->uploadfiles      = 1;

$existing = $ws->get_external_service_by_shortname($service_shortname);
if ($existing) {
    $service->id = $existing->id;
    $ws->update_external_service($service);
    $serviceid = $existing->id;
    echo "Servicio actualizado (ID: $serviceid)\n";
} else {
    $serviceid = $ws->add_external_service($service);
    echo "Servicio creado (ID: $serviceid)\n";
}

// 2. Autorizar usuario al servicio
if (!$ws->get_ws_authorised_user($serviceid, $user->id)) {
    $auth = new stdClass();
    $auth->externalserviceid = $serviceid;
    $auth->userid            = $user->id;
    $auth->timecreated       = time();
    $auth->timemodified      = time();
    $auth->creatorid         = $user->id;
    $DB->insert_record('external_services_users', $auth);
    echo "Usuario autorizado al servicio\n";
} else {
    echo "Usuario ya estaba autorizado\n";
}

// 3. Añadir funciones al servicio
$functions = [
    "core_user_create_users",
    "core_user_delete_users",
    "core_user_update_users",
    "core_user_get_users",
    "core_user_get_users_by_field",
    "core_user_get_course_user_profiles",
    "core_cohort_add_cohort_members",
    "core_cohort_delete_cohort_members",
    "core_cohort_get_cohort_members",
    "core_cohort_get_cohorts",
    "core_cohort_create_cohorts",
    "core_cohort_delete_cohorts",
    "core_cohort_update_cohorts",
    "core_cohort_search_cohorts",
    "core_course_get_courses",
    "core_course_get_courses_by_field",
    "core_course_create_courses",
    "core_course_update_courses",
    "core_course_delete_courses",
    "core_course_import_course",
    "core_course_search_courses",
    "core_course_get_contents",
    "core_course_get_categories",
    "core_course_create_categories",
    "enrol_manual_enrol_users",
    "enrol_manual_unenrol_users",
    "core_enrol_get_enrolled_users",
    "core_enrol_get_course_enrolment_methods",
    "core_enrol_get_users_courses",
    "core_enrol_get_enrolled_users_with_capability",
    "core_enrol_get_potential_users",
    "core_enrol_search_users",
    "core_enrol_edit_user_enrolment",
    "core_group_create_groups",
    "core_group_delete_groups",
    "core_group_get_groups",
    "core_group_get_course_groups",
    "core_group_add_group_members",
    "core_group_delete_group_members",
    "core_group_get_group_members",
    "core_group_update_groups",
    "core_backup_get_course_backup_status",
    "core_backup_get_copy_progress",
    "core_backup_submit_course_backup",
    "core_course_duplicate_course",
    "core_files_get_files",
    "core_files_upload",
    "core_files_delete_draft_files",
    "core_files_get_unused_draft_itemid",
    "core_role_assign_roles",
    "core_role_unassign_roles",
    "core_webservice_get_site_info",
];

foreach ($functions as $func) {
    if (!$ws->service_function_exists($func, $serviceid)) {
        $ws->add_external_function_to_service($func, $serviceid);
    }
}
echo count($functions) . " funciones aseguradas en el servicio\n";

// 4. Generar token (la clase webservice lo hace nativamente)
$ws->generate_user_ws_tokens($user->id);

// 5. Recuperar e imprimir token
$token = $DB->get_record('external_tokens', [
    'userid'            => $user->id,
    'externalserviceid' => $serviceid,
    'tokentype'         => EXTERNAL_TOKEN_PERMANENT,
]);

if ($token) {
    echo "Token: " . $token->token . "\n";
} else {
    fwrite(STDERR, "ERROR: No se pudo generar/recuperar el token\n");
    exit(1);
}
```

**Nota importante**: `generate_user_ws_tokens()` solo actúa si:
- El usuario **NO es siteadmin** (por eso quitamos a `moodle-api` de admin).
- Tiene la capacidad `moodle/webservice:createtoken` (se la damos con `role-update-capability`).
- Los servicios web están habilitados a nivel de sitio.

---

### 3.5 `init-scripts/init.sh`
**Cambio**: Ya está hecho. Ahora detecta exit codes y muestra `ERROR: script failed`.

---

## 4. LISTA DE TAREAS PENDIENTES (checklist)

- [ ] Modificar `init-data/data/usuarios.csv` (cambiar `admin` → `user` para `moodle-api`).
- [ ] Modificar `init-scripts/new-install/import_FPVirtual_categories_and_courses.sh` (quitar `moodle-api` de `siteadmins`).
- [ ] Crear `init-scripts/new-install/api_service_setup.php` (script PHP CLI nativo).
- [ ] Reescribir `init-scripts/new-install/api_config.sh` (usar `moosh` nativo + llamada al PHP).
- [ ] Verificar que `api_config.sh` tenga permisos de ejecución (`chmod +x`).
- [ ] Probar levantando de cero: `docker compose down -v`, borrar moodle-data, `docker compose up -d --build`.
- [ ] Ejecutar `test_moodle_api_v3.py` para validar que el token funciona.

---

## 5. CONSIDERACIONES ADICIONALES

### ¿Qué pasa con `import_FPVirtual_categories_and_courses.sh` y `moodle-api`?
- Ese script también busca a `moodle-api` para añadirlo a `siteadmins`. **Hay que quitar esa lógica**.
- El resto del script (creación de categorías, cursos, cohortes, roles de inspección/jefatura) **no se toca**.

### Capacidades del rol `integracion_api`
- El rol necesita `moodle/webservice:createtoken` para que `generate_user_ws_tokens()` funcione.
- También necesita `webservice/rest:use` para poder consumir el API.
- Las demás capacidades son las operaciones de negocio (usuarios, cursos, cohortes, etc.).

### Funciones WebService para MBZ/restore
- El script actual ya incluye `core_backup_submit_course_backup`, `core_course_import_course`, etc.
- Para subir archivos MBZ y restaurarlos, el flujo típico es:
  1. `core_files_upload` (sube el .mbz a draft area).
  2. `core_course_import_course` o restauración vía otro mecanismo.
- Moodle no expone una función WS directa de "restore from file", pero con `core_course_import_course` y los backups ya se cubre gran parte.

### `moosh sql-run` en otros scripts
- `import_FPVirtual_categories_and_courses.sh` y `moodle.sh` usan `moosh sql-run` sin strings con `:`. **No requieren cambios**.
- `plugins.sh` (new-install) debería precargar `moosh plugin-list` como hace `upgrade/plugins.sh`, pero eso es una mejora aparte.

---

## 6. COMANDOS DE PRUEBA (para mañana)

```bash
# Reconstruir desde cero
docker compose down -v
sudo rm -rf moodle-data/*
docker compose up -d --build

# Seguir logs
docker compose logs -f moodle

# Verificar que el token existe
 docker compose exec moodle bash -c "cd /var/www/html && moosh -n sql-run 'SELECT token FROM mdl_external_tokens WHERE userid = (SELECT id FROM mdl_user WHERE username = \"moodle-api\")'"

# Ejecutar tests Python
 cd Moodle-API-Test && python3 test_moodle_api_v3.py
```

---

*Fin del plan. Listo para continuar mañana.*
