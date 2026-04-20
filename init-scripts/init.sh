#!/bin/bash
# Script orquestador para FPD
# Ejecuta los scripts correspondientes según INSTALL_TYPE

FILES="/init-scripts/${INSTALL_TYPE}/moodle.sh
/init-scripts/${INSTALL_TYPE}/plugins.sh
/init-scripts/${INSTALL_TYPE}/import_FPD_categories_and_courses.sh
/init-scripts/${INSTALL_TYPE}/theme.sh"

for f in $FILES
do
	if [ -x "$f" ]; then
		echo >&2 "$f executing..."
		$f
		echo >&2 "$f executed!"
	else
		echo >&2 "$f skipped, no x permission"
	fi
done

echo "All done"
