#!/usr/bin/env python3
"""
Verifica qué funciones de backup están disponibles en tu servicio web.
"""

import os
from pathlib import Path
import requests

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

def check_function(function_name: str) -> bool:
    """Verifica si una función está disponible para el token."""
    url = f"{MOODLE_URL}/webservice/rest/server.php"
    response = requests.post(url, data={
        "wstoken": TOKEN,
        "wsfunction": function_name,
        "moodlewsrestformat": "json",
        "courseid": 1,  # ID ficticio para test
    })
    data = response.json()
    
    # Si no devuelve "accesseexception" o "invalidtoken", la función existe
    if "exception" in data:
        error = data.get("errorcode", "")
        if error in ["accessexception", "invalidtoken", "nosuchservice"]:
            return False
        # Otros errores (como "invalidparameter") significan que la función SÍ existe
        return True
    return True

# Funciones que necesitamos para backup
funciones = [
    "core_course_get_courses_by_field",
    "core_course_backup_course", 
    "core_course_get_course_backup_status",
]

print("🔍 Verificando funciones de backup disponibles...\n")
for func in funciones:
    disponible = check_function(func)
    estado = "✅ DISPONIBLE" if disponible else "❌ NO DISPONIBLE"
    print(f"{estado}: {func}")
