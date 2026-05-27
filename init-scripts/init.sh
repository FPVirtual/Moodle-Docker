#!/bin/bash
# Script orquestador para FPD
# Ejecuta los scripts correspondientes según INSTALL_TYPE

FILES="/init-scripts/${INSTALL_TYPE}/moodle.sh
/init-scripts/${INSTALL_TYPE}/plugins.sh
/init-scripts/${INSTALL_TYPE}/load_usuarios.sh
/init-scripts/${INSTALL_TYPE}/import_FPVirtual_categories_and_courses.sh
/init-scripts/${INSTALL_TYPE}/theme.sh
/init-scripts/${INSTALL_TYPE}/api_config.sh
/init-scripts/${INSTALL_TYPE}/test_data.sh"


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
