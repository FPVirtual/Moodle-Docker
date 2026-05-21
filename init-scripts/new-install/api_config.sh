#!/bin/bash
# =============================================================================
# Script de configuración del API Web Service de Moodle usando moosh
# =============================================================================
# Usuario: moodle-api (ya existe con permisos de admin)
# Servicio: Test API
# Versión: Moodle 4.1.19+
# =============================================================================

set -e  # Salir si algún comando falla

echo "=========================================="
echo "Configuración API Moodle con moosh"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# VARIABLES CONFIGURABLES
# -----------------------------------------------------------------------------
MOODLE_DIR="/var/www/html"          # Directorio de Moodle en el contenedor
SERVICE_NAME="Test API"
SERVICE_SHORTNAME="test_api"
API_USER="moodle-api"
API_ROLE="integracion_api"

# -----------------------------------------------------------------------------
# 1. VERIFICAR QUE ESTAMOS EN EL DIRECTORIO DE MOODLE
# -----------------------------------------------------------------------------
if [ ! -f "config.php" ]; then
    echo "ERROR: No se encontró config.php. Ejecuta este script desde el directorio de Moodle."
    echo "Ejemplo: cd /var/www/moodle && bash /ruta/a/este/script.sh"
    exit 1
fi

echo "[1/8] Verificando instalación de moosh..."
if ! command -v moosh &> /dev/null; then
    echo "ERROR: moosh no está instalado. Instálalo primero:"
    echo "  sudo apt-get install moosh"
    echo "  o visita https://moosh-online.com/"
    exit 1
fi
echo "  ✓ moosh detectado"

# -----------------------------------------------------------------------------
# 2. HABILITAR WEB SERVICES A NIVEL DE SITIO
# -----------------------------------------------------------------------------
echo ""
echo "[2/8] Habilitando servicios web..."
moosh config-set enablewebservices 1
echo "  ✓ enablewebservices = 1"

# -----------------------------------------------------------------------------
# 3. HABILITAR PROTOCOLO REST
# -----------------------------------------------------------------------------
echo ""
echo "[3/8] Habilitando protocolo REST..."
# Activar REST (habilitar el plugin)
moosh plugin-install webservice_rest 2>/dev/null || echo "  REST ya está disponible"

# -----------------------------------------------------------------------------
# 4. CREAR ROL DE INTEGRACIÓN API
# -----------------------------------------------------------------------------
echo ""
echo "[4/8] Creando rol de integración API..."

# Verificar si el rol ya existe
ROLE_EXISTS=$(moosh role-list | grep "$API_ROLE" | wc -l)

if [ "$ROLE_EXISTS" -eq "0" ]; then
    moosh role-create -d "Rol para acceso programático vía web services"                       -a user                       -n "Integración API"                       "$API_ROLE"
    echo "  ✓ Rol '$API_ROLE' creado"
else
    echo "  ✓ Rol '$API_ROLE' ya existe"
fi

# -----------------------------------------------------------------------------
# 5. ASIGNAR CAPACIDADES AL ROL (vía SQL con moosh)
# -----------------------------------------------------------------------------
echo ""
echo "[5/8] Asignando capacidades al rol..."

ROLE_ID=$(moosh sql-run "SELECT id FROM {role} WHERE shortname = '$API_ROLE'" | grep -oP '\d+' | tail -1)

capabilities=(
    # Usuarios
    "moodle/user:create"
    "moodle/user:viewalldetails"
    "moodle/user:update"
    "moodle/user:delete"
    "moodle/user:viewhiddendetails"
    # Cohortes
    "moodle/cohort:manage"
    "moodle/cohort:view"
    # Cursos
    "moodle/course:create"
    "moodle/course:update"
    "moodle/course:viewhiddencourses"
    "moodle/course:viewparticipants"
    "moodle/course:manageactivities"
    # Backup/Restore
    "moodle/backup:backupcourse"
    "moodle/backup:restorecourse"
    "moodle/restore:restorecourse"
    "moodle/backup:backuptargetimport"
    "moodle/backup:configure"
    # Matriculación
    "enrol/manual:enrol"
    "enrol/manual:unenrol"
    "enrol/manual:manage"
    # Grupos
    "moodle/course:managegroups"
    "moodle/site:accessallgroups"
    # Web Services
    "webservice/rest:use"
    "moodle/webservice:createtoken"
    "moodle/webservice:managealltokens"
    # Archivos
    "moodle/user:manageownfiles"
)

for cap in "${capabilities[@]}"; do
    moosh sql-run "INSERT INTO {role_capabilities} (roleid, contextid, capability, permission, timemodified, modifierid) 
                   VALUES ($ROLE_ID, 1, '$cap', 1, $(date +%s), 2)
                   ON DUPLICATE KEY UPDATE permission = 1, timemodified = $(date +%s)" > /dev/null 2>&1
done

echo "  ✓ ${#capabilities[@]} capacidades asignadas"

# -----------------------------------------------------------------------------
# 6. ASIGNAR ROL AL USUARIO moodle-api EN CONTEXTO DE SISTEMA
# -----------------------------------------------------------------------------
echo ""
echo "[6/8] Asignando rol a usuario '$API_USER'..."

USER_ID=$(moosh sql-run "SELECT id FROM {user} WHERE username = '$API_USER'" | grep -oP '\d+' | tail -1)

if [ -z "$USER_ID" ]; then
    echo "ERROR: Usuario '$API_USER' no encontrado. Crea el usuario primero."
    exit 1
fi

moosh sql-run "INSERT INTO {role_assignments} (roleid, contextid, userid, timemodified, modifierid, component, itemid)
               VALUES ($ROLE_ID, 1, $USER_ID, $(date +%s), 2, '', 0)
               ON DUPLICATE KEY UPDATE roleid = $ROLE_ID, timemodified = $(date +%s)" > /dev/null 2>&1

echo "  ✓ Rol asignado a $API_USER (ID: $USER_ID)"

# -----------------------------------------------------------------------------
# 7. CREAR SERVICIO EXTERNO Y GENERAR TOKEN
# -----------------------------------------------------------------------------
echo ""
echo "[7/8] Creando servicio externo '$SERVICE_NAME'..."

# Crear servicio
moosh sql-run "INSERT INTO {external_services} (name, shortname, enabled, requiredcapability, restrictedusers, 
               component, timecreated, timemodified, downloadfiles, uploadfiles)
               VALUES ('$SERVICE_NAME', '$SERVICE_SHORTNAME', 1, 'moodle/user:create', 1, 
               '', $(date +%s), $(date +%s), 1, 1)
               ON DUPLICATE KEY UPDATE enabled = 1, restrictedusers = 1, downloadfiles = 1, uploadfiles = 1" > /dev/null 2>&1

SERVICE_ID=$(moosh sql-run "SELECT id FROM {external_services} WHERE shortname = '$SERVICE_SHORTNAME'" | grep -oP '\d+' | tail -1)

# Autorizar usuario al servicio
moosh sql-run "INSERT INTO {external_services_users} (externalserviceid, userid, iprestriction, validuntil, 
               timecreated, timemodified, creatorid)
               VALUES ($SERVICE_ID, $USER_ID, '', 0, $(date +%s), $(date +%s), 2)
               ON DUPLICATE KEY UPDATE timecreated = $(date +%s), timemodified = $(date +%s)" > /dev/null 2>&1

# Generar token
TOKEN=$(openssl rand -hex 16)
moosh sql-run "INSERT INTO {external_tokens} (token, privatetoken, tokentype, userid, externalserviceid, 
               sid, contextid, creatorid, iprestriction, validuntil, timecreated, lastaccess, name)
               VALUES ('$TOKEN', MD5(CONCAT('private_', $(date +%s))), 0, $USER_ID, $SERVICE_ID, 
               '', 1, 2, '', 0, $(date +%s), 0, 'Token $SERVICE_NAME')
               ON DUPLICATE KEY UPDATE token = '$TOKEN', timemodified = $(date +%s)" > /dev/null 2>&1

echo "  ✓ Servicio creado (ID: $SERVICE_ID)"
echo "  ✓ Token generado: $TOKEN"

# -----------------------------------------------------------------------------
# 8. AÑADIR FUNCIONES AL SERVICIO
# -----------------------------------------------------------------------------
echo ""
echo "[8/8] Añadiendo funciones al servicio..."

functions=(
    # Usuarios
    "core_user_create_users"
    "core_user_delete_users"
    "core_user_update_users"
    "core_user_get_users"
    "core_user_get_users_by_field"
    "core_user_get_course_user_profiles"
    # Cohortes
    "core_cohort_add_cohort_members"
    "core_cohort_delete_cohort_members"
    "core_cohort_get_cohort_members"
    "core_cohort_get_cohorts"
    "core_cohort_create_cohorts"
    "core_cohort_delete_cohorts"
    "core_cohort_update_cohorts"
    "core_cohort_search_cohorts"
    # Cursos
    "core_course_get_courses"
    "core_course_get_courses_by_field"
    "core_course_create_courses"
    "core_course_update_courses"
    "core_course_delete_courses"
    "core_course_import_course"
    "core_course_search_courses"
    "core_course_get_contents"
    "core_course_get_categories"
    "core_course_create_categories"
    # Matriculación
    "enrol_manual_enrol_users"
    "enrol_manual_unenrol_users"
    "core_enrol_get_enrolled_users"
    "core_enrol_get_course_enrolment_methods"
    "core_enrol_get_users_courses"
    "core_enrol_get_enrolled_users_with_capability"
    "core_enrol_get_potential_users"
    "core_enrol_search_users"
    "core_enrol_edit_user_enrolment"
    # Grupos
    "core_group_create_groups"
    "core_group_delete_groups"
    "core_group_get_groups"
    "core_group_get_course_groups"
    "core_group_add_group_members"
    "core_group_delete_group_members"
    "core_group_get_group_members"
    "core_group_update_groups"
    # Backup/Restore
    "core_backup_get_course_backup_status"
    "core_backup_get_copy_progress"
    "core_backup_submit_course_backup"
    "core_course_duplicate_course"
    # Archivos
    "core_files_get_files"
    "core_files_upload"
    "core_files_delete_draft_files"
    "core_files_get_unused_draft_itemid"
    # Roles
    "core_role_assign_roles"
    "core_role_unassign_roles"
    # Info sitio
    "core_webservice_get_site_info"
)

for func in "${functions[@]}"; do
    moosh sql-run "INSERT INTO {external_services_functions} (functionname, externalserviceid)
                   VALUES ('$func', $SERVICE_ID)
                   ON DUPLICATE KEY UPDATE externalserviceid = $SERVICE_ID" > /dev/null 2>&1
done

echo "  ✓ ${#functions[@]} funciones añadidas"

# -----------------------------------------------------------------------------
# 9. LIMPIEZA DE CACHÉ
# -----------------------------------------------------------------------------
echo ""
echo "[9/9] Limpiando cachés..."
moosh cache-clear
echo "  ✓ Caché limpiada"

# -----------------------------------------------------------------------------
# RESUMEN
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Servicio:     $SERVICE_NAME"
echo "Shortname:    $SERVICE_SHORTNAME"
echo "Usuario API:  $API_USER (ID: $USER_ID)"
echo "Rol:          $API_ROLE (ID: $ROLE_ID)"
echo "Token:        $TOKEN"
echo ""
echo "Endpoint:     https://TU_DOMINIO/webservice/rest/server.php"
echo ""
echo "Prueba de conexión:"
echo "  curl -X POST \"
echo "    -d "wstoken=$TOKEN" \"
echo "    -d "wsfunction=core_webservice_get_site_info" \"
echo "    -d "moodlewsrestformat=json" \"
echo "    https://TU_DOMINIO/webservice/rest/server.php"
echo ""
echo "=========================================="