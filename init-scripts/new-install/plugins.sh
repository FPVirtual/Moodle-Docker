#!/bin/bash
# Instalación de plugins para FPD

####################
# functions        #
####################
actions_asociated_to_plugin(){
    echo "Executing actions associated to plugin ${1}..."
    case ${1} in
        "local_mail")
            echo "Configuring local_mail..."
            moosh config-set maxfiles 5 local_mail
            moosh config-set maxbytes 2097152 local_mail
            moosh config-set enablebackup 1 local_mail
            echo "Updating default notification preferences for local_mail"
            moosh config-set  message_provider_local_mail_mail_loggedin    popup   message
            moosh config-set  message_provider_local_mail_mail_loggedoff    popup   message
            ;;
        "mod_jitsi")
            echo "Configuring jitsi..."
            moosh config-set jitsi_livebutton 1
            moosh config-set jitsi_shareyoutube 1
            moosh config-set jitsi_id nameandsurname
            moosh config-set jitsi_finishandreturn 1
            moosh config-set jitsi_sesionname 0,1,2
            moosh config-set jitsi_domain meet.jit.si
            moosh config-set jitsi_watermarklink https://jitsi.org
            moosh config-set jitsi_channellastcam 4
            ;;
        "block_grade_me")
            echo "Configuring block_grade_me..."
            moosh config-set block_grade_me_maxcourses 10
            moosh config-set block_grade_me_enableassign 1
            moosh config-set block_grade_me_enableassignment 1
            moosh config-set block_grade_me_enablequiz 1
            ;;
        "format_tiles")
            echo "Configuring format_tiles..."
            moosh config-set modalresources pdf,url,html format_tiles
            moosh config-set showprogresssphototiles 0 format_tiles
            moosh config-set showseczerocoursewide 1 format_tiles
            moosh config-set allowphototiles 1 format_tiles
            moosh -n config-set usejavascriptnav 0 format_tiles
            ;;
        "block_xp")
            echo "Configuring block_xp..."
            moosh config-set blocktitle "¡Sube de nivel!" block_xp
            ;;
        "mod_pdfannotator")
            echo "Configuring mod_pdfannotator..."
            moosh config-set usevotes 1 mod_pdfannotator
            ;;
        "mod_board")
            moosh config-set new_column_icon fa-plus mod_board
            moosh config-set new_note_icon fa-plus mod_board
            moosh config-set media_selection 1 mod_board
            moosh config-set post_max_length 250 mod_board
            moosh config-set history_refresh 60 mod_board
            ;;
        "block_configurable_reports")
            echo "Configuring configurable_reports..."
            moosh config-set cron_hour 1 block_configurable_reports
            moosh config-set cron_minute 15 block_configurable_reports
            moosh config-set crrepository jleyva/moodle-configurable_reports_repository block_configurable_reports
            moosh config-set dbhost ${MOODLE_DB_HOST} block_configurable_reports
            moosh config-set dbname ${MOODLE_DB_NAME} block_configurable_reports
            moosh config-set dbuser ${MOODLE_DB_USER} block_configurable_reports
            moosh config-set dbpass ${MOODLE_DB_PASSWORD} block_configurable_reports
            moosh config-set reportlimit 5000 block_configurable_reports
            moosh config-set reporttableui datatables block_configurable_reports
            moosh config-set sharedsqlrepository jleyva/moodle-custom_sql_report_queries block_configurable_reports
            moosh config-set sqlsecurity 1 block_configurable_reports
            moosh config-set sqlsyntaxhighlight 1 block_configurable_reports
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

set +x

echo >&2 "Downloading plugin list..."
moosh plugin-list >/dev/null
echo >&2 "Plugin list downloaded!"

echo >&2 "Installing plugins..."
echo "Moodle's version: ${VERSION}"
VERSION_MINOR=$(echo ${VERSION} | cut -d. -f1,2)
echo "Moodle's minor version: ${VERSION_MINOR}"

PLUGINS=( 
    "theme_moove"
    "format_tiles"
    "block_xp"
    "availability_xp"
    "block_configurable_reports"
    "report_coursestats"
    "quizaccess_onesession"
    "mod_choicegroup"
    "mod_board"
    "local_mail"
    "mod_pdfannotator"
    "block_grade_me"
    "block_completion_progress"
    "atto_fontsize"
    "atto_fontfamily"
    "atto_fullscreen"
    "qtype_gapfill"
    "mod_attendance"
    "mod_checklist"
    "mod_checklist" # repito porque si no el último plugin no termina de instalarse
)

for PLUGIN in "${PLUGINS[@]}"
do
    moosh plugin-list | grep ${PLUGIN} | grep ${VERSION_MINOR} >/dev/null && echo "trying to install ${PLUGIN} ..." && moosh plugin-install -d ${PLUGIN} && actions_asociated_to_plugin ${PLUGIN} || echo "${PLUGIN} is not available for ${VERSION_MINOR}"
done

echo >&2 "Plugins installed!"

# CONFIGURE PLUGINS
echo "Configuring plugins..."

echo "Configuring editor_atto..."
moosh config-set toolbar "collapse = collapse
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

echo "Configuring atto_fontfamily..."
moosh config-set fontselectlist "Arial=Arial, Helvetica, sans-serif;
Times=Times New Roman, Times, serif;
Courier=Courier New, Courier, mono;
Georgia=Georgia, Times New Roman, Times, serif;
Verdana=Verdana, Geneva, sans-serif;
Trebuchet=Trebuchet MS, Helvetica, sans-serif;
Escolar=Boo;" atto_fontfamily

echo "Plugins configurated!"
