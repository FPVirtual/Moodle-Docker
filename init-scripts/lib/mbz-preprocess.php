<?php
/**
 * Preprocesamiento de backups .mbz para restore sin usuarios.
 *
 * Moodle al restaurar un backup intenta importar los usuarios que contiene.
 * En una instalacion de 0, esos usuarios ya existen (creados desde CSV)
 * con IDs diferentes, lo que provoca conflicto y aborta el restore.
 *
 * Este script vacia users.xml para que el restore solo importe contenido
 * del curso (actividades, recursos, foros...) sin intentar traer usuarios.
 *
 * Uso con moosh:
 *   moosh course-restore -i -p /init-scripts/lib/mbz-preprocess.php backup.mbz category_id
 */

function moosh_preprocess_mbz(string $path, bool $verbose): void
{
    $users_xml = $path . DIRECTORY_SEPARATOR . 'users.xml';

    if (file_exists($users_xml)) {
        // Vaciar el XML manteniendo la estructura minima valida
        file_put_contents($users_xml, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<users></users>\n");

        if ($verbose) {
            echo "Preprocess: emptied users.xml to skip user import\n";
        }
    }
}
