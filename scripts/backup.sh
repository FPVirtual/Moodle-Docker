#!/bin/bash
# Script de backup coordinado para FPD
set -euo pipefail

BACKUP_DIR="${1:-./backups}"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_DB="fpd-db"
CONTAINER_MOODLE="fpd-moodle"

mkdir -p "${BACKUP_DIR}"

echo "========================================="
echo " Iniciando backup FPD - ${DATE}"
echo "========================================="

echo "[1/4] Activando modo mantenimiento..."
docker compose exec -T "${CONTAINER_MOODLE}" moosh -n maintenance-on || true

echo "[2/4] Volcando base de datos..."
docker compose exec -T "${CONTAINER_DB}" \
    mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" --single-transaction --routines "${MOODLE_DB_NAME}" \
    > "${BACKUP_DIR}/backup_db_${DATE}.sql"
echo "      -> ${BACKUP_DIR}/backup_db_${DATE}.sql"

echo "[3/4] Comprimiendo moodle-data..."
tar -czf "${BACKUP_DIR}/backup_moodledata_${DATE}.tar.gz" -C . moodle-data
echo "      -> ${BACKUP_DIR}/backup_moodledata_${DATE}.tar.gz"

echo "[4/4] Desactivando modo mantenimiento..."
docker compose exec -T "${CONTAINER_MOODLE}" moosh -n maintenance-off || true

echo "========================================="
echo " Backup completado con éxito"
echo "========================================="
ls -lh "${BACKUP_DIR}"/backup_*_${DATE}.*
