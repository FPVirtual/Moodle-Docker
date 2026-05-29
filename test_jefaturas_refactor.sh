#!/bin/bash
# Script de prueba para validar la refactorización de matriculación de jefaturas
# Ejecuta solo la parte relevante sin alterar la estructura de categorías/cursos existente

set -e

DATA_DIR="/init-data/data"

echo "=========================================="
echo "TEST: Refactorización jefaturas"
echo "=========================================="

# 1. Reconstruir array de jefaturas desde la BD actual
declare -A JEFATURA_USER_IDS
declare -A JEFATURA_ERRORS

echo ""
echo "[1/3] Reconstruyendo array de jefaturas desde BD..."
while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
do
    USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='${username}'" | awk '/\[id\] =>/ {print $3}')
    if [ -n "$USER_ID" ] && echo "$USER_ID" | grep -qE '^[0-9]+$'; then
        JEFATURA_USER_IDS["${cod_centro}"]="${USER_ID}"
        echo "  $username (centro $cod_centro) -> ID=$USER_ID"
    else
        echo >&2 "  WARNING: No se encontró ID para $username (centro $cod_centro)"
        JEFATURA_ERRORS["${cod_centro}"]="Usuario ${username} no encontrado"
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/jefaturas.csv")

echo ""
echo "[2/3] Verificando matriculaciones de jefaturas en cursos..."
# Solo verificar, NO matricular (dry-run) para no alterar la BD en la prueba
while IFS=$'\t' read -r category_var shortname fullname visible
do
    [ "$category_var" = "category_var" ] && continue
    
    CODCENTRO=$(echo "${shortname}" | cut -d '-' -f 1)
    JEFE_ID="${JEFATURA_USER_IDS[$CODCENTRO]:-}"
    
    # Obtener course_id
    COURSE_ID=$(moosh -n sql-run "SELECT id FROM mdl_course WHERE shortname='${shortname}'" | awk '/\[id\] =>/ {print $3}')
    
    if [ -n "$COURSE_ID" ] && echo "$COURSE_ID" | grep -qE '^[0-9]+$'; then
        if [ -n "$JEFE_ID" ] && echo "$JEFE_ID" | grep -qE '^[0-9]+$'; then
            # Verificar si ya está matriculado
            ALREADY_ENROLLED=$(moosh -n sql-run "SELECT COUNT(*) as c FROM mdl_user_enrolments ue JOIN mdl_enrol e ON ue.enrolid=e.id WHERE e.courseid=${COURSE_ID} AND ue.userid=${JEFE_ID}" | awk '/\[c\] =>/ {print $3}')
            if [ "$ALREADY_ENROLLED" -gt 0 ]; then
                echo "  OK: $shortname (curso $COURSE_ID) -> jefe $JEFE_ID YA matriculado"
            else
                echo "  PENDIENTE: $shortname (curso $COURSE_ID) -> jefe $JEFE_ID NO matriculado"
            fi
        elif [[ ${shortname} == *-*-* ]]; then
            echo >&2 "  WARNING: No hay jefe para centro $CODCENTRO en curso $shortname"
            JEFATURA_ERRORS["${CODCENTRO}"]="${JEFATURA_ERRORS[${CODCENTRO}]:-}; Sin jefe para curso $shortname"
        fi
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/cursos.csv")

echo ""
echo "[3/3] Resumen de errores/detectados:"
if [ ${#JEFATURA_ERRORS[@]} -gt 0 ]; then
    echo "=========================================="
    echo "ERRORES / WARNINGs POR CENTRO"
    echo "=========================================="
    for centro in "${!JEFATURA_ERRORS[@]}"; do
        echo "  Centro: $centro -> ${JEFATURA_ERRORS[$centro]}"
    done
    echo "=========================================="
else
    echo "✓ Sin errores detectados."
fi

echo ""
echo "Test completado."
