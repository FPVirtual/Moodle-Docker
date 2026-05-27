#!/bin/bash
# =============================================================================
# Script de configuración del API Web Service de Moodle
# =============================================================================
# Usuario: moodle-api (usuario normal, NO admin)
# Rol: integracion_api (rol personalizado con capacidades limitadas)
# Servicio: Test API
# =============================================================================

set -e

echo "=========================================="
echo "Configuración API Moodle"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# VARIABLES CONFIGURABLES
# -----------------------------------------------------------------------------
API_USER="moodle-api"
API_ROLE="integracion_api"
SERVICE_NAME="Test API"
SERVICE_SHORTNAME="test_api"

# -----------------------------------------------------------------------------
# 1. VERIFICAR ENTORNO
# -----------------------------------------------------------------------------
echo "[1/8] Verificando instalación de moosh..."
if ! command -v moosh &> /dev/null; then
    echo "ERROR: moosh no está instalado."
    exit 1
fi
echo "  ✓ moosh detectado"

if [ ! -f "config.php" ]; then
    echo "ERROR: No se encontró config.php. Ejecuta este script desde /var/www/html"
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. HABILITAR WEB SERVICES A NIVEL DE SITIO
# -----------------------------------------------------------------------------
echo ""
echo "[2/8] Habilitando servicios web..."
moosh -n config-set enablewebservices 1
echo "  ✓ enablewebservices = 1"

# -----------------------------------------------------------------------------
# 3. HABILITAR PROTOCOLO REST
# -----------------------------------------------------------------------------
echo ""
echo "[3/8] Habilitando protocolo REST..."
# En Moodle 4.5+ REST es un protocolo core; solo hay que asegurar que esté activo
moosh -n config-set webserviceprotocols 'rest' || true
echo "  ✓ Protocolo REST habilitado"

# -----------------------------------------------------------------------------
# 4. CREAR ROL DE INTEGRACIÓN API
# -----------------------------------------------------------------------------
echo ""
echo "[4/8] Creando rol de integración API..."

ROLE_EXISTS=$(moosh -n role-list | grep "$API_ROLE" | wc -l)

if [ "$ROLE_EXISTS" -eq "0" ]; then
    moosh -n role-create \
        -d "Rol para acceso programático vía web services" \
        -a user \
        -n "Integración API" \
        "$API_ROLE"
    echo "  ✓ Rol '$API_ROLE' creado"
else
    echo "  ✓ Rol '$API_ROLE' ya existe"
fi

# Habilitar asignación a nivel de sistema (requerido para user-assign-system-role)
echo "  → Habilitando contexto de sistema para el rol..."
moosh -n role-update-contextlevel --system-on "$API_ROLE"
echo "  ✓ Contexto de sistema activado"

# -----------------------------------------------------------------------------
# 5. ASIGNAR CAPACIDADES AL ROL
# -----------------------------------------------------------------------------
echo ""
echo "[5/8] Asignando capacidades al rol..."

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
    moosh -n role-update-capability "$API_ROLE" "$cap" allow 1 > /dev/null 2>&1 || true
done

echo "  ✓ ${#capabilities[@]} capacidades asignadas"

# -----------------------------------------------------------------------------
# 6. ASIGNAR ROL AL USUARIO moodle-api EN CONTEXTO DE SISTEMA
# -----------------------------------------------------------------------------
echo ""
echo "[6/8] Asignando rol '$API_ROLE' a usuario '$API_USER'..."

# Verificar que el usuario existe
USER_ID=$(moosh -n sql-run "SELECT id FROM {user} WHERE username = '$API_USER'" | grep -oP '\d+' | tail -1)

if [ -z "$USER_ID" ]; then
    echo "ERROR: Usuario '$API_USER' no encontrado. Crea el usuario primero (load_usuarios.sh)."
    exit 1
fi

moosh -n user-assign-system-role "$API_USER" "$API_ROLE" > /dev/null 2>&1 || true
echo "  ✓ Rol asignado a $API_USER (ID: $USER_ID)"

# -----------------------------------------------------------------------------
# 7. CREAR SERVICIO EXTERNO, FUNCIONES Y GENERAR TOKEN (vía PHP nativo)
# -----------------------------------------------------------------------------
echo ""
echo "[7/8] Creando servicio externo, funciones y token..."

PHP_SCRIPT="/init-scripts/new-install/api_service_setup.php"

if [ ! -f "$PHP_SCRIPT" ]; then
    echo "ERROR: No se encontró $PHP_SCRIPT"
    exit 1
fi

php "$PHP_SCRIPT"

# -----------------------------------------------------------------------------
# 8. LIMPIEZA DE CACHÉ
# -----------------------------------------------------------------------------
echo ""
echo "[8/8] Limpiando cachés..."
moosh -n cache-clear
echo "  ✓ Caché limpiada"

echo ""
echo "=========================================="
echo "CONFIGURACIÓN API COMPLETADA"
echo "=========================================="
