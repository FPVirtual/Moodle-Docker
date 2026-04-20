#!/bin/bash

# GET PLUGIN LIST
echo >&2 "Downloading plugin list..."
moosh plugin-list >/dev/null
echo >&2 "Plugin list downloaded!"

# INSTALL PLUGINS
echo >&2 "Installing plugins..."
echo "Moodle's version: ${VERSION}"
VERSION_MINOR=$(echo ${VERSION} | cut -d. -f1,2)
echo "Moodle's minor version: ${VERSION_MINOR}"

PLUGINS=( 
    "theme_moove" 
    "format_tiles"
    "block_xp"
    "availability_xp"
    "local_mail"
    "block_configurable_reports"
    "report_coursestats"
    "quizaccess_onesession"
    "mod_choicegroup"
    "mod_board"
    "mod_pdfannotator"
    "block_grade_me"
    "block_completion_progress"
    "atto_fontsize"
    "atto_fontfamily"
    "atto_fullscreen"
    "qtype_gapfill"
    "mod_attendance"
    "mod_checklist"
    "mod_checklist"
)

for PLUGIN in "${PLUGINS[@]}"
do
    moosh plugin-install -d ${PLUGIN} 
done

echo >&2 "Plugins installed!"
