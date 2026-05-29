#!/bin/bash
# =============================================================================
# Script de carga de datos de TEST (no ejecutar en producción)
# =============================================================================
# Carga usuarios de test y los matricula en cursos específicos.
# Controlado por la variable de entorno ENABLE_TEST_DATA.
# =============================================================================

if [ "${ENABLE_TEST_DATA:-false}" != "true" ]; then
    echo "ENABLE_TEST_DATA no activado. Skipping test data."
    exit 0
fi

set -e

DATA_DIR="/init-data/data"

echo "=========================================="
echo "CARGA DE DATOS DE TEST"
echo "=========================================="

# -----------------------------------------------------------------------------
# 1. Crear usuarios de test desde CSV
# -----------------------------------------------------------------------------
if [ -f "${DATA_DIR}/usuarios_test.csv" ]; then
    echo "Creando usuarios de test..."
    while IFS=$'\t' read -r username password_env email firstname lastname role; do
        [ "$username" = "username" ] && continue
        [ -z "$username" ] && continue

        # Resolver variable de entorno para la contraseña
        password="${!password_env}"
        if [ -z "$password" ]; then
            echo >&2 "WARNING: Variable $password_env no definida para $username, usando valor literal"
            password="$password_env"
        fi

        moosh -n user-create --password "$password" --email "$email" --digest 2 \
            --city "Aragón" --country ES --firstname "$firstname" --lastname "$lastname" "$username" \
            >/dev/null 2>&1 || true
        echo "  ✓ $username"
    done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/usuarios_test.csv")
else
    echo "  (sin usuarios_test.csv)"
fi

# -----------------------------------------------------------------------------
# 2. Matricular usuarios de test según CSV de matriculaciones
# -----------------------------------------------------------------------------
HAS_MATRICULATIONS=0
if [ -f "${DATA_DIR}/matriculaciones_test.csv" ]; then
    while IFS=$'\t' read -r username shortname role; do
        [ "$username" = "username" ] && continue
        [ -z "$username" ] && continue
        [ "${username:0:1}" = "#" ] && continue

        HAS_MATRICULATIONS=1

        USER_ID=$(moosh -n sql-run "SELECT id FROM {user} WHERE username='${username}'" | grep -oE '[0-9]+' | tail -1)
        COURSE_ID=$(moosh -n sql-run "SELECT id FROM {course} WHERE shortname='${shortname}'" | grep -oE '[0-9]+' | tail -1)

        if [ -n "$USER_ID" ] && [ -n "$COURSE_ID" ]; then
            moosh -n course-enrol -r "$role" -i "$COURSE_ID" "$USER_ID" >/dev/null 2>&1 || true
            echo "  ✓ $username -> $shortname ($role)"
        else
            echo >&2 "  ✗ ERROR: No se encontro usuario '$username' (ID=$USER_ID) o curso '$shortname' (ID=$COURSE_ID)"
        fi
    done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/matriculaciones_test.csv")
fi

# -----------------------------------------------------------------------------
# 3. Si no hay matriculaciones concretas, matricular prof_cd_daw en cd_daw
# -----------------------------------------------------------------------------
if [ "$HAS_MATRICULATIONS" -eq 0 ]; then
    echo "Matriculando prof_cd_daw en todos los cursos de la categoria cd_daw..."

    PROF_CD_DAW_ID=$(moosh -n sql-run "SELECT id FROM {user} WHERE username='prof_cd_daw'" | grep -oE '[0-9]+' | tail -1)
    if [ -z "$PROF_CD_DAW_ID" ]; then
        echo >&2 "WARNING: prof_cd_daw no encontrado. No se matricula en cd_daw."
    else
        # Obtener IDs de cursos en categorias cd_daw
        COURSE_IDS=$(moosh -n sql-run "SELECT id FROM {course} WHERE category IN (SELECT id FROM {course_categories} WHERE idnumber LIKE 'cd_daw%')" | grep -oE '[0-9]+')
        for COURSE_ID in $COURSE_IDS; do
            moosh -n course-enrol -r editingteacher -i "$COURSE_ID" "$PROF_CD_DAW_ID" >/dev/null 2>&1 || true
        done
        echo "  ✓ prof_cd_daw matriculado en cursos cd_daw"
    fi
fi

# -----------------------------------------------------------------------------
# 4. Crear y matricular usuarios de la app en marketplaces
# -----------------------------------------------------------------------------
MARKETPLACES_COURSE_ID=$(moosh -n sql-run "SELECT id FROM {course} WHERE shortname='marketplaces'" | grep -oE '[0-9]+' | tail -1)
if [ -n "$MARKETPLACES_COURSE_ID" ]; then
    echo "Configurando usuarios de app en marketplaces..."

    APP_STUDENT_ID=$(moosh -n sql-run "SELECT id FROM {user} WHERE username='demoapp'" | grep -oE '[0-9]+' | tail -1)
    APP_TEACHER_ID=$(moosh -n sql-run "SELECT id FROM {user} WHERE username='profesor1'" | grep -oE '[0-9]+' | tail -1)

    if [ -n "$APP_STUDENT_ID" ]; then
        moosh -n course-enrol -r student -i "$MARKETPLACES_COURSE_ID" "$APP_STUDENT_ID" >/dev/null 2>&1 || true
        echo "  ✓ demoapp matriculado en marketplaces"
    fi

    if [ -n "$APP_TEACHER_ID" ]; then
        moosh -n course-enrol -r editingteacher -i "$MARKETPLACES_COURSE_ID" "$APP_TEACHER_ID" >/dev/null 2>&1 || true
        echo "  ✓ profesor1 matriculado en marketplaces"
    fi
else
    echo "  (curso marketplaces no encontrado)"
fi

echo "=========================================="
echo "Datos de test cargados"
echo "=========================================="
