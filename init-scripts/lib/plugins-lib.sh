#!/bin/bash
# =============================================================================
# plugins-lib.sh - Helpers para leer el catalogo de plugins (plugins.json)
# =============================================================================
# Uso: source /init-scripts/lib/plugins-lib.sh
#
# Dependencias: python3 (disponible en la imagen php:8.2-apache de Debian)
# =============================================================================

PLUGINS_JSON="${PLUGINS_JSON:-/init-scripts/plugins.json}"

# ---------------------------------------------------------------------------
# Verifica que exista el archivo JSON
# ---------------------------------------------------------------------------
plugins_json_exists() {
    if [ ! -f "$PLUGINS_JSON" ]; then
        echo >&2 "ERROR: No se encontro $PLUGINS_JSON"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Lista todos los nombres de plugins definidos en el JSON
# ---------------------------------------------------------------------------
plugins_list_all() {
    plugins_json_exists || return 1
    python3 -c "
import json, sys
try:
    with open('$PLUGINS_JSON', 'r') as f:
        data = json.load(f)
    for p in data.get('plugins', []):
        print(p['name'])
except Exception as e:
    print(f'Error JSON: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# ---------------------------------------------------------------------------
# Obtiene un campo de un plugin del JSON
# Uso: plugins_json_get <plugin_name> <field>
# ---------------------------------------------------------------------------
plugins_json_get() {
    local plugin_name="$1"
    local field="$2"
    plugins_json_exists || return 1
    python3 -c "
import json, sys
try:
    with open('$PLUGINS_JSON', 'r') as f:
        data = json.load(f)
    for p in data.get('plugins', []):
        if p['name'] == '$plugin_name':
            val = p.get('$field', '')
            print(val if val is not None else '')
            sys.exit(0)
    sys.exit(1)
except Exception as e:
    print(f'Error JSON: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# ---------------------------------------------------------------------------
# Comprueba si un plugin esta habilitado segun .env + JSON
#
# Logica:
#   1. Lee la variable de entorno PLUGIN_<NOMBRE_EN_MAYUSCULAS>
#   2. Si existe y es "true"  -> habilitado
#   3. Si existe y es "false" -> deshabilitado
#   4. Si no existe la variable -> usa default_enabled del JSON
# ---------------------------------------------------------------------------
plugin_is_enabled() {
    local plugin_name="$1"
    local env_var="PLUGIN_$(echo "$plugin_name" | tr '[:lower:]' '[:upper:]')"
    local env_val
    env_val="$(printenv "$env_var" 2>/dev/null || true)"

    if [ -n "$env_val" ]; then
        case "$env_val" in
            [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1)
                return 0
                ;;
            [Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]|0)
                return 1
                ;;
        esac
    fi

    # Fallback al JSON
    local default_enabled
    default_enabled="$(plugins_json_get "$plugin_name" default_enabled)"
    case "$default_enabled" in
        [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Lista solo los plugins habilitados (uno por linea)
# ---------------------------------------------------------------------------
plugins_list_enabled() {
    local plugin
    plugins_list_all | while IFS= read -r plugin; do
        if plugin_is_enabled "$plugin"; then
            echo "$plugin"
        fi
    done
}

# ---------------------------------------------------------------------------
# Muestra un resumen de plugins habilitados/deshabilitados
# ---------------------------------------------------------------------------
plugins_show_summary() {
    echo "============================================================"
    echo "Resumen de plugins (segun .env + $PLUGINS_JSON)"
    echo "============================================================"
    local plugin enabled total=0 en=0 dis=0
    while IFS= read -r plugin; do
        total=$((total + 1))
        if plugin_is_enabled "$plugin"; then
            echo "  [ON ] $plugin"
            en=$((en + 1))
        else
            echo "  [OFF] $plugin"
            dis=$((dis + 1))
        fi
    done < <(plugins_list_all)
    echo "------------------------------------------------------------"
    echo "Total: $total | Habilitados: $en | Deshabilitados: $dis"
    echo "============================================================"
}
