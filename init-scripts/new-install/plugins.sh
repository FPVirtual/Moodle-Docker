#!/bin/bash
# Instalacion de plugins para FPVirtual
# Lee el catalogo desde /init-data/plugins.json (o /init-scripts/plugins.json como fallback)
# y las variables PLUGIN_* del .env

set +x

# Cargar helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/plugins-lib.sh"

####################
# functions        #
####################
actions_asociated_to_plugin(){
    echo "Executing actions associated to plugin ${1}..."
    case ${1} in
        "local_mail")
            echo "Configuring local_mail..."
            moosh -n config-set maxfiles 5 local_mail
            moosh -n config-set maxbytes 2097152 local_mail
            moosh -n config-set enablebackup 1 local_mail
            echo "Updating default notification preferences for local_mail"
            moosh -n config-set  message_provider_local_mail_mail_loggedin    popup   message
            moosh -n config-set  message_provider_local_mail_mail_loggedoff    popup   message
            ;;
        "mod_jitsi")
            echo "Configuring jitsi..."
            moosh -n config-set jitsi_livebutton 1
            moosh -n config-set jitsi_shareyoutube 1
            moosh -n config-set jitsi_id nameandsurname
            moosh -n config-set jitsi_finishandreturn 1
            moosh -n config-set jitsi_sesionname 0,1,2
            moosh -n config-set jitsi_domain meet.jit.si
            moosh -n config-set jitsi_watermarklink https://jitsi.org
            moosh -n config-set jitsi_channellastcam 4
            ;;
        "block_grade_me")
            echo "Configuring block_grade_me..."
            moosh -n config-set block_grade_me_maxcourses 10
            moosh -n config-set block_grade_me_enableassign 1
            moosh -n config-set block_grade_me_enableassignment 1
            moosh -n config-set block_grade_me_enablequiz 1
            ;;
        "format_tiles")
            echo "Configuring format_tiles..."
            moosh -n config-set modalresources pdf,url,html format_tiles
            moosh -n config-set showprogresssphototiles 0 format_tiles
            moosh -n config-set showseczerocoursewide 1 format_tiles
            moosh -n config-set allowphototiles 1 format_tiles
            moosh -n config-set usejavascriptnav 0 format_tiles
            ;;
        "block_xp")
            echo "Configuring block_xp..."
            moosh -n config-set blocktitle "¡Sube de nivel!" block_xp
            ;;
        "mod_pdfannotator")
            echo "Configuring mod_pdfannotator..."
            moosh -n config-set usevotes 1 mod_pdfannotator
            ;;
        "mod_board")
            moosh -n config-set new_column_icon fa-plus mod_board
            moosh -n config-set new_note_icon fa-plus mod_board
            moosh -n config-set media_selection 1 mod_board
            moosh -n config-set post_max_length 250 mod_board
            moosh -n config-set history_refresh 60 mod_board
            ;;
        "block_configurable_reports")
            echo "Configuring configurable_reports..."
            moosh -n config-set cron_hour 1 block_configurable_reports
            moosh -n config-set cron_minute 15 block_configurable_reports
            moosh -n config-set crrepository jleyva/moodle-configurable_reports_repository block_configurable_reports
            moosh -n config-set dbhost ${MOODLE_DB_HOST} block_configurable_reports
            moosh -n config-set dbname ${MOODLE_DB_NAME} block_configurable_reports
            moosh -n config-set dbuser ${MOODLE_DB_USER} block_configurable_reports
            moosh -n config-set dbpass ${MOODLE_DB_PASSWORD} block_configurable_reports
            moosh -n config-set reportlimit 5000 block_configurable_reports
            moosh -n config-set reporttableui datatables block_configurable_reports
            moosh -n config-set sharedsqlrepository jleyva/moodle-custom_sql_report_queries block_configurable_reports
            moosh -n config-set sqlsecurity 1 block_configurable_reports
            moosh -n config-set sqlsyntaxhighlight 1 block_configurable_reports
            ;;
        "local_educaaragon")
            echo "Configuring local_educaaragon..."
            php /init-scripts/new-install/educaaragon_setup.php
            ;;
        *)
            echo "No additional actions for plugin ${1}"
            ;;
    esac
    echo "Done with actions asociated to plugin ${1}."
}

####################
# main             #
####################

# Google Meet: elegir entre fork hyukudan (moderno) o legacy (ronefel)
# Ambos se clonan en build-time; aqui decidimos cual se activa en runtime.
if [ "${PLUGIN_MOD_GOOGLEMEET_LEGACY:-false}" = "true" ]; then
    echo >&2 "Google Meet legacy (ronefel) seleccionado. Reemplazando mod/googlemeet..."
    rm -rf /var/www/html/mod/googlemeet
    cp -a /var/www/html/mod/googlemeet_legacy /var/www/html/mod/googlemeet
    # Deshabilitar hyukudan para evitar conflictos en el bucle de instalacion
    PLUGIN_MOD_GOOGLEMEET=false
elif [ "${PLUGIN_MOD_GOOGLEMEET:-false}" = "true" ]; then
    # Hyukudan seleccionado: limpiar legacy para no ocupar espacio
    rm -rf /var/www/html/mod/googlemeet_legacy
fi

echo >&2 "Downloading plugin list..."
moosh -n plugin-list >/dev/null
echo >&2 "Plugin list downloaded!"

echo >&2 "Installing plugins..."
echo "Moodle's version: ${MOODLE_VERSION}"
VERSION_MINOR=$(echo ${MOODLE_VERSION} | cut -d. -f1,2)
echo "Moodle's minor version: ${VERSION_MINOR}"

# Mostrar resumen antes de empezar
plugins_show_summary

# Iterar sobre los plugins habilitados
while IFS= read -r PLUGIN; do
    [ -z "$PLUGIN" ] && continue

    echo ""
    echo "===> Processing plugin: ${PLUGIN}"

    # Instalar via moosh -n si esta disponible para esta version
    if moosh -n plugin-list | grep "^${PLUGIN} " | grep "${VERSION_MINOR}" >/dev/null; then
        echo "trying to install ${PLUGIN} ..."
        moosh -n plugin-install -d ${PLUGIN} || echo "${PLUGIN} already present or install skipped"
    else
        echo "${PLUGIN} is not available in remote list for ${VERSION_MINOR}, checking local..."
    fi

    # Ejecutar acciones asociadas (configuracion post-instalacion)
    actions_asociated_to_plugin ${PLUGIN}
done < <(plugins_list_enabled)

echo >&2 "Plugins installed!"

# CONFIGURE PLUGINS GLOBALES
# Solo configuramos Atto si al menos uno de los plugins de Atto esta habilitado
if plugin_is_enabled "atto_fontsize" || plugin_is_enabled "atto_fontfamily" || plugin_is_enabled "atto_fullscreen" || plugin_is_enabled "atto_c4l"; then
    echo "Configuring editor_atto..."
    moosh -n config-set toolbar "collapse = collapse
style1 = title, fontsize, fontfamily, fontcolor, backcolor, bold, italic
list = unorderedlist, orderedlist
links = link
files = image, media, recordrtc, managefiles
h5p = h5p
style2 = underline, strike, subscript, superscript
align = align
indent = indent
insert = equation, charmap, table, clear
undo = undo
accessibility = accessibilitychecker, accessibilityhelper
other = html, fullscreen" editor_atto
fi

if plugin_is_enabled "atto_fontfamily"; then
    echo "Configuring atto_fontfamily..."
    moosh -n config-set fontselectlist "Arial=Arial, Helvetica, sans-serif;
Times=Times New Roman, Times, serif;
Courier=Courier New, Courier, mono;
Georgia=Georgia, Times New Roman, Times, serif;
Verdana=Verdana, Geneva, sans-serif;
Trebuchet=Trebuchet MS, Helvetica, sans-serif;
Escolar=Boo;" atto_fontfamily
fi

echo "Plugins configurated!"
