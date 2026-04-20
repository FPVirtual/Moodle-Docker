#!/bin/bash
set -e

# Esperar a que la base de datos esté disponible
echo "Esperando a que la base de datos esté disponible en ${MOODLE_DB_HOST}:${MOODLE_DB_PORT:-3306}..."
until php -r "new mysqli('${MOODLE_DB_HOST}', '${MOODLE_DB_USER}', '${MOODLE_DB_PASSWORD}', '${MOODLE_DB_NAME}', ${MOODLE_DB_PORT:-3306});" 2>/dev/null; do
    echo "Base de datos no disponible aún. Esperando..."
    sleep 2
done
echo "Base de datos disponible."

# Función para comprobar si Moodle ya está instalado (tiene tablas)
moodle_is_installed() {
    php -r "
        require '/var/www/html/config.php';
        \$mysqli = new mysqli('${MOODLE_DB_HOST}', '${MOODLE_DB_USER}', '${MOODLE_DB_PASSWORD}', '${MOODLE_DB_NAME}', ${MOODLE_DB_PORT:-3306});
        if (\$mysqli->connect_error) exit(1);
        \$result = \$mysqli->query(\"SHOW TABLES LIKE 'mdl_config'\");
        exit(\$result && \$result->num_rows > 0 ? 0 : 1);
    " 2>/dev/null
}

if ! moodle_is_installed; then
    echo "Moodle no detectado en la base de datos. Procediendo a instalación..."
    
    php /var/www/html/admin/cli/install_database.php \
        --lang="${MOODLE_LANG:-es}" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASSWORD}" \
        --adminemail="${MOODLE_ADMIN_EMAIL}" \
        --fullname="${MOODLE_SITE_FULLNAME}" \
        --shortname="${MOODLE_SITE_NAME}" \
        --agree-license \
        --non-interactive || true

    # Ejecutar scripts de personalización si es instalación nueva
    if [ "${INSTALL_TYPE:-new-install}" = "new-install" ]; then
        echo "Ejecutando scripts de personalización para FPD..."
        /init-scripts/init.sh
    fi

    touch /var/www/moodledata/.moodle-installed
    echo "Instalación completada."
else
    echo "Moodle ya instalado."
    
    if [ "${INSTALL_TYPE:-}" = "upgrade" ]; then
        echo "Ejecutando actualización de Moodle..."
        php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable || true
        /init-scripts/init.sh
    fi
fi

# Limpiar caché
php /var/www/html/admin/cli/purge_caches.php || true

exec "$@"
