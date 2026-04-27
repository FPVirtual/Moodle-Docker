<?php
/**
 * Lee un CSV y emite sus filas como campos separados por tabuladores.
 * Uso: php read_csv.php archivo.csv
 * La primera fila (cabecera) se omite.
 */
if ($argc !== 2) {
    fwrite(STDERR, "Uso: read_csv.php <archivo.csv>\n");
    exit(1);
}

$handle = fopen($argv[1], 'r');
if ($handle === false) {
    fwrite(STDERR, "No se pudo abrir: {$argv[1]}\n");
    exit(1);
}

// Omitir cabecera
fgetcsv($handle);

while (($row = fgetcsv($handle)) !== false) {
    echo implode("\t", $row) . "\n";
}

fclose($handle);
