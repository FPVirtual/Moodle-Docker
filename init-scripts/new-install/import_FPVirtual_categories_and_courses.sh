#!/bin/bash
##########################################
#                                                       MUY IMPORTANTE
#                                                       MUY IMPORTANTE
#                                                       MUY IMPORTANTE
# MUY IMPORTANTE                  MUY IMPORTANTE
#     MUY IMPORTANTE          MUY IMPORTANTE
#         MUY IMPORTANTE  MUY IMPORTANTE
#     MUY IMPORTANTE          MUY IMPORTANTE
# MUY IMPORTANTE                  MUY IMPORTANTE
#                                                       MUY IMPORTANTE
#                                                       MUY IMPORTANTE
#                                                       MUY IMPORTANTE
#
# Los IDs de las categorias y cursos son invariables
# NO deben modificarse entre despliegues para mantener la compatibilidad
# con plugin de videollamadas y edición de contenidos
##########################################

DATA_DIR="/init-data/data"

# ------------------------------------------------------------------
# Idempotencia: si ya existen datos clave de FPVirtual, salir
# ------------------------------------------------------------------
echo "Checking if FPVirtual data already exists..."
ADMIN2_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='admin2'" | awk '/\[id\] =>/ {print $3}')
JEFATURA_ROLE_ID=$(moosh -n sql-run "SELECT id FROM mdl_role WHERE shortname='jefatura-estudios'" | awk '/\[id\] =>/ {print $3}')

if [ -n "$ADMIN2_ID" ] && [ -n "$JEFATURA_ROLE_ID" ]; then
    echo "FPVirtual data already detected (admin2 ID=${ADMIN2_ID}, role jefatura-estudios ID=${JEFATURA_ROLE_ID}). Skipping import."
    echo >&2 "... importing categories and courses. Skipped (already exists)."
    exit 0
fi

echo >&2 "Importing categories and courses..."

#############################################################################################
# Creo los usuarios, roles,... específicos de FPD:
#############################################################################################
echo "Creating users, roles,... of PFD"

# Añadir usuarios admin (creados desde CSV) a siteadmins
echo "Configurando usuarios admin como siteadmin..."
FPD_ADMIN_USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='admin2'" | awk '/\[id\] =>/ {print $3}')

SITEADMINS="2"
[ -n "$FPD_ADMIN_USER_ID" ] && SITEADMINS="${SITEADMINS},${FPD_ADMIN_USER_ID}"

moosh -n config-set siteadmins "${SITEADMINS}"

if [ -z "$FPD_ADMIN_USER_ID" ]; then
    echo >&2 "WARNING: admin2 no encontrado, omitiendo de siteadmins"
fi


# Crear rol de inspección
echo "Creating inspeccion role and configuring it..."
INSPECCION_ROLE_ID=$(moosh -n role-create -d "Los usuarios con rol de inspección tienen acceso a determinados informes" -a manager -n "Inspeccion" inspeccion | tail -1)

# set permissions to inspeccion role
moosh -n role-import -f /init-scripts/themes/fpdist/roles/role-inspeccion.xml

# Asignar rol inspeccion a profinspector (ya creado desde CSV)
moosh -n user-assign-system-role profinspector inspeccion

# Crear rol de jefaturas y usuarios
echo "Creating jefatura-estudios role and configuring it..."
JEFATURA_ROLE_ID=$(moosh -n role-create -d "Los usuarios con rol de inspección tienen acceso a determinados informes" -c system,category,course,block -n "Jefatura de estudios" jefatura-estudios | tail -1)

# Setting permissions to jefatura de estudios role
moosh -n role-import -f /init-scripts/themes/fpdist/roles/role-jefatura-estudios.xml

# Creating jefatura users from CSV
echo "Creating jefatura users from CSV..."
declare -A JEFATURA_USER_IDS
declare -A JEFATURA_ERRORS

while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
 do
    echo "Processing jefatura user: ${username} (centro ${cod_centro})"
    
    # Crear usuario si no existe; nunca parsear output de moosh (frágil ante errores)
    moosh -n user-create --password "${!password_env}" --email "${email}" --digest 2 --city Aragón --country ES --firstname "${firstname}" --lastname "${lastname}" "${username}" >/dev/null 2>&1 || true
    
    # Obtener ID SIEMPRE por SQL (única fuente fiable)
    USER_ID=$(moosh -n sql-run "SELECT id FROM mdl_user WHERE username='${username}'" | awk '/\[id\] =>/ {print $3}')
    
    if [ -z "$USER_ID" ] || ! echo "$USER_ID" | grep -qE '^[0-9]+$'; then
        echo >&2 "ERROR: Could not resolve ID for ${username} (centro ${cod_centro}). Skipping."
        JEFATURA_ERRORS["${cod_centro}"]="Usuario ${username} no creado/encontrado"
        continue
    fi
    
    JEFATURA_USER_IDS["${cod_centro}"]="${USER_ID}"
    echo "  ${username} (centro ${cod_centro}) -> ID=${USER_ID}"
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/jefaturas.csv")

#############################################################################################
# Creo las categorías:
#############################################################################################
echo "Creating structure for categories from CSV..."

while IFS=$'\t' read -r var_name parent visible description name
 do
    if [ "${var_name}" = "miscelanea" ]; then
        eval "ID_CATEGORY_${var_name}=1"
        continue
    fi

    if [ "${parent}" = "0" ]; then
        parent_id=0
    else
        eval "parent_id=\${ID_CATEGORY_${parent}}"
    fi

    # Buscar si la categoría ya existe en este parent
    EXISTING_CAT_ID=$(moosh -n sql-run "SELECT id FROM mdl_course_categories WHERE name='${name}' AND parent=${parent_id}" | awk '/\[id\] =>/ {print $3}')
    
    if [ -n "$EXISTING_CAT_ID" ] && echo "$EXISTING_CAT_ID" | grep -qE '^[0-9]+$'; then
        echo "Category already exists: ${name} (var=${var_name}, id=${EXISTING_CAT_ID})"
        eval "ID_CATEGORY_${var_name}=${EXISTING_CAT_ID}"
    else
        echo "Creating category: ${name} (var=${var_name}, parent=${parent})"
        eval "ID_CATEGORY_${var_name}=\$(moosh -n category-create -p \"\${parent_id}\" -v \"\${visible}\" -d \"\${description}\" -i \"\${var_name}\" \"\${name}\" | grep -oP '\\d+' | tail -1)"
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/categorias.csv")

#############################################################################################
# A los usuarios jefes de estudios les cambio su campo personalizado para que tengan el valor correspondiente a su categoría
#############################################################################################

# Añadir el campo personalizado a los usuarios y asignar a cada jefe de estudios el suyo 
echo "Creating custom fields for jefatura estudios..."
# # Creo el campo personalizado
moosh -n userprofilefields-import /init-scripts/themes/fpdist/custom-fields/user_profile_fields.csv

# # Asignar a cada usuario el valor que le corresponde en el campo personalizado
while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
 do
    user_id="${JEFATURA_USER_IDS[$cod_centro]:-}"
    eval "cat_id=\${ID_CATEGORY_${category_var}}"
    if [ -n "$user_id" ] && echo "$user_id" | grep -qE '^[0-9]+$'; then
        moosh -n sql-run "INSERT IGNORE INTO mdl_user_info_data (userid, fieldid, data, dataformat) VALUES (${user_id}, 1, ${cat_id}, 0)"
    else
        echo >&2 "WARNING: No user_id found for ${username} (centro ${cod_centro}), skipping user_info_data"
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/jefaturas.csv")


#############################################################################################
# Creo las cohortes
#############################################################################################
echo "Creating cohorts from CSV..."

while IFS=$'\t' read -r description id category_var name
 do
    eval "cat_id=\${ID_CATEGORY_${category_var}}"
    
    # Verificar si la cohorte ya existe por idnumber
    EXISTING_COHORT_ID=$(moosh -n sql-run "SELECT id FROM mdl_cohort WHERE idnumber='${id}'" | awk '/\[id\] =>/ {print $3}')
    
    if [ -n "$EXISTING_COHORT_ID" ] && echo "$EXISTING_COHORT_ID" | grep -qE '^[0-9]+$'; then
        echo "Cohort already exists: ${name} (idnumber=${id}, id=${EXISTING_COHORT_ID})"
    else
        echo "Creating cohort: ${name} (idnumber=${id})"
        moosh -n cohort-create -d "${description}" -i "${id}" -c "${cat_id}" "${name}"
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/cohortes.csv")

#############################################################################################
# Añado a la cohorte de jefatura de estudios a los diferentes usuarios de jefes de estudios
#############################################################################################
echo "Adding jefatura users to cohort jefaturas..."

while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
 do
    suffix=$(echo "${username}" | sed 's/prof_je_//')
    user_var="JE_${suffix^^}_USER_ID"
    eval "user_id=\${${user_var}}"
    moosh -n cohort-enrol -u "${user_id}" "jefaturas" || true
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/jefaturas.csv")


#############################################################################################
# Creo los cursos intentando restaurar su contenido
#############################################################################################

# IMPORTANTE (Lee abajo)
# IMPORTANTE (Lee abajo)
# IMPORTANTE (Lee abajo)
# La siguiente lista de cursos NO puede ser modificada en su orden. Si un curso desaparece se cambiará 
# el 1 del final por un 0. Si se añaden nuevos cursos se añadirán al final, nunca 
# junto a los de su centro o estudio pues eso cambiaría el orden
# IMPORTANTE (Lee arriba)
# IMPORTANTE (Lee arriba)
# IMPORTANTE (Lee arriba)

echo "***** Processing courses from CSV..."
while IFS=$'\t' read -r category_var shortname fullname visible
 do
    eval "CATEGORY=\${ID_CATEGORY_${category_var}}"
    echo "CATEGORY '${category_var}' -> '${CATEGORY}' - SHORTNAME '${shortname}' - FULLNAME '${fullname}' - VISIBLE '${visible}'"
    COURSE_ID=""
    
    if [ ! -f "/init-data/mbzs/${shortname}.mbz" ]; then
        # Si no existe el curso, lo creo (o busco el existente si ya está creado)
        echo "***** The course /init-data/mbzs/${shortname}.mbz doesn't exist, creating empty course ${shortname} into category ${CATEGORY}"
        moosh -n course-create --category "${CATEGORY}" --fullname "${fullname}" --description "${fullname}" "${shortname}" >/dev/null 2>&1 || true
    else
        # Si existe el curso lo restauro
        echo "***** Restoring /init-data/mbzs/${shortname}.mbz course to category ${CATEGORY}"
        RESTORE_OUTPUT=$(moosh -n course-restore -i -p /init-scripts/lib/mbz-preprocess.php /init-data/mbzs/${shortname}.mbz "${CATEGORY}" 2>&1)
        echo "${RESTORE_OUTPUT}"
        # Si el restore falló (ej. curso ya existe), buscamos el ID por shortname
        if ! echo "${RESTORE_OUTPUT}" | grep -q "courseid="; then
            echo "***** course-restore did not return a new courseid. Looking up existing course by shortname..."
        fi
    fi
    
    # Obtener el ID del curso por shortname (funciona tanto si se creó, restauró o ya existía)
    COURSE_ID=$(moosh -n sql-run "SELECT id FROM mdl_course WHERE shortname='${shortname}'" | awk '/\[id\] =>/ {print $3}')
    
    if [ -z "$COURSE_ID" ]; then
        echo "***** ERROR: Could not find or create course '${shortname}'. Skipping enrolments."
        continue
    fi
    
    # Configurar nombres y visibilidad
    moosh -n course-config-set course "${COURSE_ID}" shortname "${shortname}"
    moosh -n course-config-set course "${COURSE_ID}" fullname "${fullname}"
    moosh -n course-config-set course "${COURSE_ID}" visible "${visible}"
    # TODO: valorar si los que no son visible los borro una vez creados <- verificar no afecta a los IDs

    # matriculo en el curso de ayuda a las cohortes alumnado, profesorado, coordinacion y jefaturas
    if [[ ${shortname} == 'ayuda' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts alumnado, profesorado, coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh -n cohort-enrol -c "${COURSE_ID}" "alumnado"
        moosh -n cohort-enrol -c "${COURSE_ID}" "profesorado"
        moosh -n cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh -n cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # matriculo en el curso de profesorado a las cohortes profesorado, coordinacion y jefaturas
    if [[ ${shortname} == 'profesorado' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts profesorado, coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh -n cohort-enrol -c "${COURSE_ID}" "profesorado"
        moosh -n cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh -n cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # matriculo en el curso de coordinacion a las cohortes coordinacion y jefaturas
    if [[ ${shortname} == 'coordinacion' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh -n cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh -n cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # si el cod_ensenanza contiene una t al final (es una tutoría) entonces matriculo a la cohorte en ese curso
    if [[ ${shortname} == *t ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohort ${COHORT} into the course_id ${COURSE_ID}"
        moosh -n cohort-enrol -c "${COURSE_ID}" "${COHORT}"
    fi

    # Matricular a jefe de estudios en los cursos en base al ID centro del shortname
    CODCENTRO=$(echo "${shortname}" | cut -d '-' -f 1)
    JEFE_ID="${JEFATURA_USER_IDS[$CODCENTRO]:-}"
    
    if [ -n "$JEFE_ID" ] && echo "$JEFE_ID" | grep -qE '^[0-9]+$'; then
        echo "****** Enrolling jefe de estudios (ID=$JEFE_ID) into course_id ${COURSE_ID} for centro $CODCENTRO"
        if ! moosh -n course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JEFE_ID}" >/dev/null 2>&1; then
            echo >&2 "****** ERROR: Failed to enrol jefe $JEFE_ID into course $COURSE_ID (centro $CODCENTRO)"
            JEFATURA_ERRORS["${CODCENTRO}"]="${JEFATURA_ERRORS[${CODCENTRO}]:-}; Fallo matriculacion curso $COURSE_ID"
        fi
    else
        echo "****** WARNING: No jefe de estudios found for centro $CODCENTRO (course: $shortname). Skipping enrolment."
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/cursos.csv")

# -----------------------------------------------------------------------------
# RESUMEN DE ERRORES DE JEFATURAS
# -----------------------------------------------------------------------------
if [ ${#JEFATURA_ERRORS[@]} -gt 0 ]; then
    echo >&2 ""
    echo >&2 "=========================================="
    echo >&2 "RESUMEN DE ERRORES EN JEFATURAS"
    echo >&2 "=========================================="
    for centro in "${!JEFATURA_ERRORS[@]}"; do
        echo >&2 "  Centro: $centro -> ${JEFATURA_ERRORS[$centro]}"
    done
    echo >&2 "=========================================="
else
    echo >&2 ""
    echo >&2 "✓ Sin errores en matriculaciones de jefaturas."
fi

echo >&2 "... importing categories and courses. Done!"
