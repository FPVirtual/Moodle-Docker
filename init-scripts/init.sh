#!/bin/bash
# Script orquestador para FPD (new-install)
# Ejecuta los scripts de personalización en una instalación nueva

FILES="/init-scripts/new-install/moodle.sh
/init-scripts/new-install/plugins.sh
/init-scripts/new-install/load_usuarios.sh
/init-scripts/new-install/import_FPVirtual_categories_and_courses.sh
/init-scripts/new-install/theme.sh
/init-scripts/new-install/api_config.sh
/init-scripts/new-install/test_data.sh"


for f in $FILES
do
	if [ -x "$f" ]; then
		echo >&2 "$f executing..."
		if $f; then
			echo >&2 "$f executed!"
		else
			echo >&2 "ERROR: $f failed with exit code $?"
		fi
	else
		echo >&2 "$f skipped, no x permission"
	fi
done

echo "All done"
