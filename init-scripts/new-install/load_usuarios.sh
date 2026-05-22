#!/bin/bash
# Carga usuarios iniciales desde CSV
# Uso: load_usuarios.sh <archivo.csv>

set -e

DATA_DIR="/init-data/data"
CSV_FILE="${1:-${DATA_DIR}/usuarios.csv}"

if [ ! -f "$CSV_FILE" ]; then
    echo >&2 "ERROR: No se encontro $CSV_FILE"
    exit 1
fi

echo >&2 "Cargando usuarios desde $CSV_FILE ..."

while IFS=$'\t' read -r username password_env email firstname lastname role; do
    # Omitir cabecera
    [ "$username" = "username" ] && continue

    # Resolver variable de entorno para la contraseña
    password="${!password_env}"
    if [ -z "$password" ]; then
        echo >&2 "WARNING: Variable de entorno $password_env no definida para $username, usando valor literal"
        password="$password_env"
    fi

    echo "Creando usuario: $username"
    moosh -n user-create --password "$password" --email "$email" --digest 2 --city "Aragón" --country ES --firstname "$firstname" --lastname "$lastname" "$username"
done < <(php "${DATA_DIR}/read_csv.php" "$CSV_FILE")

echo >&2 "Usuarios creados."
