#!/bin/bash
# Reinstalacion de plugins para FPD (upgrade)
# Lee el catalogo desde plugins.json y las variables PLUGIN_* del .env

# Cargar helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/plugins-lib.sh"

# GET PLUGIN LIST
echo >&2 "Downloading plugin list..."
moosh plugin-list >/dev/null
echo >&2 "Plugin list downloaded!"

# INSTALL PLUGINS
echo >&2 "Installing plugins..."
echo "Moodle's version: ${VERSION}"
VERSION_MINOR=$(echo ${VERSION} | cut -d. -f1,2)
echo "Moodle's minor version: ${VERSION_MINOR}"

# Mostrar resumen antes de empezar
plugins_show_summary

while IFS= read -r PLUGIN; do
    [ -z "$PLUGIN" ] && continue
    echo "===> Upgrading/Reinstalling plugin: ${PLUGIN}"
    moosh plugin-install -d ${PLUGIN} || echo "${PLUGIN} skipped or already present"
done < <(plugins_list_enabled)

echo >&2 "Plugins installed!"
