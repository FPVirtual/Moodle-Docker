#!/bin/bash
# Lee /init-scripts/plugins.json (ya copiado en la imagen) y clona todos los plugins
# de terceros en sus rutas correspondientes dentro de /var/www/html.
# Uso: se ejecuta durante el build de Docker, NO en runtime.

set -e

# Este script se ejecuta en build-time; /init-data no esta disponible aun.
# Lee la copia del catalogo empaquetada en /init-scripts/plugins.json.
JSON_FILE="/init-scripts/plugins.json"
BASE_DIR="/var/www/html"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq no esta instalado. Instalarlo antes de ejecutar este script." >&2
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: No se encontro $JSON_FILE" >&2
    exit 1
fi

# Contar plugins
count=$(jq '.plugins | length' "$JSON_FILE")
echo "Clonando $count plugins desde $JSON_FILE ..." >&2

# Iterar sobre cada plugin
for i in $(seq 0 $((count - 1))); do
    plugin=$(jq -r ".plugins[$i]" "$JSON_FILE")
    name=$(echo "$plugin" | jq -r '.name')
    git_url=$(echo "$plugin" | jq -r '.git_url')
    git_branch=$(echo "$plugin" | jq -r '.git_branch // empty')
    moodle_path=$(echo "$plugin" | jq -r '.moodle_path')

    if [ -z "$git_url" ] || [ "$git_url" = "null" ]; then
        echo "  [$name] Omitido: sin git_url" >&2
        continue
    fi

    target_dir="$BASE_DIR/$moodle_path"

    # Si el directorio ya existe (ej. parte de Moodle core), saltar
    if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
        echo "  [$name] Omitido: $target_dir ya existe y no esta vacio" >&2
        continue
    fi

    # Preparar argumentos de branch
    branch_arg=""
    if [ -n "$git_branch" ]; then
        branch_arg="--branch $git_branch"
    fi

    echo "  [$name] git clone --depth 1 $branch_arg $git_url -> $moodle_path" >&2
    mkdir -p "$(dirname "$target_dir")"
    git clone --depth 1 $branch_arg "$git_url" "$target_dir" || {
        echo "  [$name] ERROR: fallo el clone de $git_url" >&2
        exit 1
    }
done

echo "Todos los plugins clonados correctamente." >&2
