#!/usr/bin/env python3
import os
from pathlib import Path
import requests
import json

# Cargar variables desde .env si existe
_env_path = Path(__file__).parent / '.env'
if _env_path.exists():
    with open(_env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ.setdefault(key, value)

MOODLE_URL = os.environ.get("MOODLE_URL")
TOKEN = os.environ.get("MOODLE_TOKEN")

if not MOODLE_URL or not TOKEN:
    print("❌ ERROR: Define MOODLE_URL y MOODLE_TOKEN en el archivo .env")
    exit(1)

def api_call(function, params=None):
    url = f"{MOODLE_URL}/webservice/rest/server.php"
    payload = {
        "wstoken": TOKEN,
        "wsfunction": function,
        "moodlewsrestformat": "json",
    }
    if params:
        payload.update(params)
    response = requests.post(url, data=payload, timeout=30)
    return response.json()

print("📥 Descargando categorías...")
categories = api_call("core_course_get_categories", {})

if isinstance(categories, dict) and "exception" in categories:
    print(f"❌ ERROR API: {categories}")
    exit(1)

print(f"Total: {len(categories)}\n")

print("=" * 70)
print("TODAS LAS CATEGORÍAS:")
print("=" * 70)

for cat in categories:
    cat_id = cat.get('id')
    name = cat.get('name', 'N/A')
    idnumber = cat.get('idnumber', 'N/A') or 'VACÍO'
    parent = cat.get('parent')
    depth = cat.get('depth')
    path = cat.get('path', 'N/A')
    print(f"\nID: {cat_id} | Depth: {depth} | Parent: {parent}")
    print(f"  Name: '{name}'")
    print(f"  Idnumber: '{idnumber}'")
    print(f"  Path: {path}")

# Buscar 50020125
print("\n" + "=" * 70)
print("BUSCANDO '50020125' en name e idnumber:")
print("=" * 70)
for cat in categories:
    name = cat.get('name', '')
    idnum = cat.get('idnumber', '') or ''
    if '50020125' in name or '50020125' in idnum:
        print(f"✅ ID {cat['id']}: name='{name}', idnumber='{idnum}'")

# Buscar 50008460
print("\n" + "=" * 70)
print("BUSCANDO '50008460' en name e idnumber:")
print("=" * 70)
for cat in categories:
    name = cat.get('name', '')
    idnum = cat.get('idnumber', '') or ''
    if '50008460' in name or '50008460' in idnum:
        print(f"✅ ID {cat['id']}: name='{name}', idnumber='{idnum}'")

# Guardar todo
with open("todas_categorias.json", "w", encoding="utf-8") as f:
    json.dump(categories, f, ensure_ascii=False, indent=2)
print(f"\n💾 Guardado en: todas_categorias.json")

