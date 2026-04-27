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

DATA_DIR="$(cd "$(dirname "$0")" && pwd)/data"

echo >&2 "Importing categories and courses..."

#############################################################################################
# Creo los usuarios, roles,... específicos de FPD:
#############################################################################################
echo "Creating users, roles,... of PFD"

# Create admin user for FPD

echo "Creating admin user for FP..."
FPD_ADMIN_USER_ID=$(moosh user-create --password "${FPD_PASSWORD}" --email "${FPD_EMAIL}" --digest 2 --city Aragón --country ES --firstname fp --lastname distancia admin2)
moosh config-set siteadmins 2,"${FPD_ADMIN_USER_ID}"

# Crear rol y usuario de inspección
echo "Creating inspeccion role and configuring it..."
INSPECCION_ROLE_ID=$(moosh role-create -d "Los usuarios con rol de inspección tienen acceso a determinados informes" -a manager -n "Inspeccion" inspeccion)

# set permissions to inspeccion role
moosh role-import -f /init-scripts/themes/fpdist/roles/role-inspeccion.xml

# Creating user
INSPECCION_USER_ID=$(moosh user-create --password "${MANAGER_PASSWORD}" --email inspeccion@educa.aragon.es --digest 2 --city Aragón --country ES --firstname Inspección --lastname Inspección profinspector)

# Assiging user to r
moosh user-assign-system-role profinspector inspeccion

# Crear rol de jefaturas y usuarios
echo "Creating jefatura-estudios role and configuring it..."
JEFATURA_ROLE_ID=$(moosh role-create -d "Los usuarios con rol de inspección tienen acceso a determinados informes" -c system,category,course,block -n "Jefatura de estudios" jefatura-estudios)

# Setting permissions to jefatura de estudios role
moosh role-import -f /init-scripts/themes/fpdist/roles/role-jefatura-estudios.xml

# Creating jefatura users from CSV
echo "Creating jefatura users from CSV..."
while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
 do
    echo "Creating jefatura user: ${username}"
    suffix=$(echo "${username}" | sed 's/prof_je_//')
    var_name="JE_${suffix^^}_USER_ID"
    eval "${var_name}=\$(moosh user-create --password \"\${${password_env}}\" --email \"${email}\" --digest 2 --city Aragón --country ES --firstname \"${firstname}\" --lastname \"${lastname}\" ${username})"
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

    echo "Creating category: ${name} (var=${var_name}, parent=${parent})"
    eval "ID_CATEGORY_${var_name}=\$(moosh category-create -p \"\${parent_id}\" -v \"\${visible}\" -d \"\${description}\" \"\${name}\")"
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/categorias.csv")

#############################################################################################
# A los usuarios jefes de estudios les cambio su campo personalizado para que tengan el valor correspondiente a su categoría
#############################################################################################

# Añadir el campo personalizado a los usuarios y asignar a cada jefe de estudios el suyo 
echo "Creating custom fields for jefatura estudios..."
# # Creo el campo personalizado
moosh userprofilefields-import /init-scripts/themes/fpdist/custom-fields/user_profile_fields.csv

# # Asignar a cada usuario el valor que le corresponde en el campo personalizado
while IFS=$'\t' read -r username password_env email firstname lastname cod_centro category_var
 do
    suffix=$(echo "${username}" | sed 's/prof_je_//')
    user_var="JE_${suffix^^}_USER_ID"
    eval "user_id=\${${user_var}}"
    eval "cat_id=\${ID_CATEGORY_${category_var}}"
    moosh sql-run "INSERT INTO mdl_user_info_data (userid, fieldid, data, dataformat) values (${user_id}, 1, ${cat_id}, 0)"
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/jefaturas.csv")


#############################################################################################
# Creo las cohortes
#############################################################################################
echo "Creating cohorts from CSV..."

while IFS=$'\t' read -r description id category_var name
 do
    eval "cat_id=\${ID_CATEGORY_${category_var}}"
    moosh cohort-create -d "${description}" -i "${id}" -c "${cat_id}" "${name}"
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
    moosh cohort-enrol -u "${user_id}" "jefaturas"
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
    
    if [ ! -f "/var/www/moodledata/repository/mbzs_curso_anterior/${shortname}.mbz" ]; then
        # Si no existe el curso, lo creo
        echo "***** The course /var/www/moodledata/repository/mbzs_curso_anterior/${shortname}.mbz doesn't exist, creating empty course ${shortname} into category ${CATEGORY}"
        COURSE_ID=$(moosh course-create --category "${CATEGORY}" --fullname "${fullname}" --description "${fullname}" "${shortname}")
    else
        # Si existe el curso lo restauro
        echo "***** Restoring /var/www/moodledata/repository/mbzs_curso_anterior/${shortname}.mbz course to category ${CATEGORY}"
        COURSE_ID=$(moosh course-restore /var/www/moodledata/repository/mbzs_curso_anterior/${shortname}.mbz "${CATEGORY}")
        COURSE_ID=$(echo "${COURSE_ID}" | tail -n 1 | cut -d ':' -f 2 | cut -d ' ' -f 2)
        # Configuro full y short names por si al restaurar había datos erróneos en origen
        moosh course-config-set course "${COURSE_ID}" shortname "${shortname}"
        moosh course-config-set course "${COURSE_ID}" fullname "${fullname}"
    fi
    moosh course-config-set course "${COURSE_ID}" visible "${visible}"
    # TODO: valorar si los que no son visible los borro una vez creados <- verificar no afecta a los IDs

    # matriculo en el curso de ayuda a las cohortes alumnado, profesorado, coordinacion y jefaturas
    if [[ ${shortname} == 'ayuda' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts alumnado, profesorado, coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh cohort-enrol -c "${COURSE_ID}" "alumnado"
        moosh cohort-enrol -c "${COURSE_ID}" "profesorado"
        moosh cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # matriculo en el curso de profesorado a las cohortes profesorado, coordinacion y jefaturas
    if [[ ${shortname} == 'profesorado' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts profesorado, coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh cohort-enrol -c "${COURSE_ID}" "profesorado"
        moosh cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # matriculo en el curso de coordinacion a las cohortes coordinacion y jefaturas
    if [[ ${shortname} == 'coordinacion' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohorts coordinacion and jefaturas into the course_id ${COURSE_ID}"
        moosh cohort-enrol -c "${COURSE_ID}" "coordinacion"
        moosh cohort-enrol -c "${COURSE_ID}" "jefaturas"
    fi

    # matriculo en el curso de marketplaces a los usuarios que nos piden desde la app
    if [[ ${shortname} == 'marketplaces' ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Creating and enrolling the users for marketplaces into the course_id ${COURSE_ID}"
        FPD_APP_USER_STUDENT_ID=$(moosh user-create --password "${APP_PASSWORD}" --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname student --lastname demoapp demoapp)
        FPD_APP_USER_TEACHER_ID=$(moosh user-create --password "${APP_TEACHER_PASSWORD}" --email alumnado@education.catedu.es --digest 2 --city Aragón --country ES --firstname teacher --lastname demoapp profesor1)

        moosh course-enrol -r editingteacher -i "${COURSE_ID}" "${FPD_APP_USER_TEACHER_ID}"
        moosh course-enrol -r student -i "${COURSE_ID}" "${FPD_APP_USER_STUDENT_ID}"
    fi

    # si el cod_ensenanza contiene una t al final (es una tutoría) entonces matriculo a la cohorte en ese curso
    if [[ ${shortname} == *t ]]; 
    then
        COHORT=$(echo "${shortname}" | cut -d '-' -f 1,2)
        echo "****** Enrolling the cohort ${COHORT} into the course_id ${COURSE_ID}"
        moosh cohort-enrol -c "${COURSE_ID}" "${COHORT}"
    fi

    # Matricular a jefes de estudios en los cursos en base al ID centro del shortname
    if [[ ${shortname} == *-*-* ]];
    then
        CODCENTRO=$(echo "${shortname}" | cut -d '-' -f 1)
        case "${CODCENTRO}" in
            "22002521") # IES Sierra de Guara
                echo "****** Enrolling the user ${JE_SG_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_SG_USER_ID}"
                ;;
            "44003211") # IES SANTA EMERENCIANA
                echo "****** Enrolling the user ${JE_SE_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_SE_USER_ID}"
                ;;
            "50010511") # IES TIEMPOS MODERNOS
                echo "****** Enrolling the user ${JE_TM_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_TM_USER_ID}"
                ;;
            "50010314") # CPIFP LOS ENLACES
                echo "****** Enrolling the user ${JE_LE_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_LE_USER_ID}"
                ;;
            "50018829") # CPIFP CORONA DE ARAGÓN
                echo "****** Enrolling the user ${JE_CA_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_CA_USER_ID}"
                ;;
            "22010712") # CPIFP PIRÁMIDE
                echo "****** Enrolling the user ${JE_PI_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_PI_USER_ID}"
                ;;
            "44003028") # CPIFP SAN BLAS
                echo "****** Enrolling the user ${JE_SB_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_SB_USER_ID}"
                ;;
            "50010156") # IES MIRALBUENO
                echo "****** Enrolling the user ${JE_MI_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_MI_USER_ID}"
                ;;
            "50010144") # IES PABLO SERRANO
                echo "****** Enrolling the user ${JE_PS_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_PS_USER_ID}"
                ;;
            "44010537") # CPIFP BAJO ARAGÓN
                echo "****** Enrolling the user ${JE_BA_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_BA_USER_ID}"
                ;;
            "50009567") # IES RÍO GÁLLEGO
                echo "****** Enrolling the user ${JE_RG_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_RG_USER_ID}"
                ;;
            "44003235") # IES VEGA DEL TURIA
                echo "****** Enrolling the user ${JE_VT_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_VT_USER_ID}"
                ;;
            "50008460") # IES LUIS BUÑUEL
                echo "****** Enrolling the user ${JE_LB_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_LB_USER_ID}"
                ;;
            "22002491") # CPIFP MONTEARAGON
                echo "****** Enrolling the user ${JE_MO_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_MO_USER_ID}"
                ;;
            "22004611") # IES MARTÍNEZ VARGAS
                echo "****** Enrolling the user ${JE_MV_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_MV_USER_ID}"
                ;;
            "50009348") # IES AVEMPACE
                echo "****** Enrolling the user ${JE_AV_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_AV_USER_ID}"
                ;;
            "50008642") # IES MARÍA MOLINER
                echo "****** Enrolling the user ${JE_MM_USER_ID} into the course_id ${COURSE_ID} with role jefatura-estudios"
                moosh course-enrol -r jefatura-estudios -i "${COURSE_ID}" "${JE_MM_USER_ID}"
                ;;
        esac
    fi
done < <(php "${DATA_DIR}/read_csv.php" "${DATA_DIR}/cursos.csv")

echo >&2 "... importing categories and courses. Done!"
