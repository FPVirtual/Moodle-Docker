#!/usr/bin/env python3
"""
Backup de cursos Moodle - Usando configuración existente (Test API)
"""

import requests
import time
import os
from datetime import datetime
from pathlib import Path

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN EXISTENTE (de tu setup anterior)
# ═══════════════════════════════════════════════════════════════

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
BACKUP_DIR = "./backups_moodle"

CURSOS_SHORTNAMES = [
    "50020125-IFC201-4995",
    "50020125-IFC201-16695",
    "50020125-IFC303-5089",
    "50020125-IFC303-5084",
    "50020125-IFC201-627t",
    "50020125-IFC303-682t",
]

# ═══════════════════════════════════════════════════════════════

def api_call(function: str, params: dict = None) -> dict:
    url = f"{MOODLE_URL}/webservice/rest/server.php"
    payload = {
        "wstoken": TOKEN,
        "wsfunction": function,
        "moodlewsrestformat": "json",
    }
    if params:
        payload.update(params)
    
    response = requests.post(url, data=payload, timeout=30)
    response.raise_for_status()
    return response.json()


def get_course_id(shortname: str) -> int:
    """Busca curso por shortname."""
    result = api_call("core_course_get_courses_by_field", {
        "field": "shortname",
        "value": shortname,
    })
    
    courses = result.get("courses", [])
    if not courses:
        raise Exception(f"Curso '{shortname}' no encontrado")
    
    return courses[0]["id"]


def backup_course(course_id: int, shortname: str):
    """Inicia backup y descarga el .mbz."""
    print(f"\n📚 {shortname} (ID: {course_id})")
    
    # 1. Iniciar backup
    print("  🚀 Iniciando backup...")
    result = api_call("core_course_backup_course", {
        "courseid": course_id,
        "users": 1,
        "activities": 1,
        "blocks": 1,
        "filters": 1,
        "comments": 1,
        "badges": 1,
        "calendarevents": 1,
        "userscompletion": 1,
        "logs": 0,
        "grade_histories": 0,
    })
    
    backup_id = result.get("backupid")
    if not backup_id:
        print(f"  ⚠️  Respuesta: {result}")
        raise Exception("No se obtuvo backupid")
    
    print(f"  ⏳ Backup ID: {backup_id}")
    
    # 2. Esperar finalización
    max_wait = 300  # 5 minutos máximo
    waited = 0
    while waited < max_wait:
        status = api_call("core_course_get_course_backup_status", {
            "backupid": backup_id,
        })
        
        state = status.get("status", "unknown")
        progress = status.get("progress", 0)
        
        if state == "finished":
            file_url = status.get("fileurl")
            if not file_url:
                raise Exception("Backup terminado pero sin URL")
            
            # 3. Descargar
            print(f"  📥 Descargando ({progress}%)...")
            download_url = f"{file_url}&token={TOKEN}"
            response = requests.get(download_url, stream=True, timeout=120)
            response.raise_for_status()
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"backup_{shortname}_{timestamp}.mbz"
            filepath = Path(BACKUP_DIR) / filename
            
            with open(filepath, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            size_mb = filepath.stat().st_size / 1024 / 1024
            print(f"  ✅ Guardado: {filename} ({size_mb:.1f} MB)")
            return filepath
            
        elif state == "error":
            raise Exception(f"Error en backup: {status}")
        
        time.sleep(5)
        waited += 5
        if waited % 30 == 0:
            print(f"     ... esperando ({waited}s, progreso: {progress}%)")
    
    raise Exception(f"Timeout después de {max_wait} segundos")


def main():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    print("╔════════════════════════════════════════════════════╗")
    print("║  BACKUP DE CURSOS MOODLE (.mbz)                    ║")
    print("╚════════════════════════════════════════════════════╝")
    
    ok = []
    fail = []
    
    for shortname in CURSOS_SHORTNAMES:
        try:
            course_id = get_course_id(shortname)
            path = backup_course(course_id, shortname)
            ok.append((shortname, path))
        except Exception as e:
            print(f"  ❌ ERROR: {e}")
            fail.append((shortname, str(e)))
    
    print(f"\n{'='*50}")
    print(f"✅ Completados: {len(ok)} | ❌ Fallidos: {len(fail)}")
    if fail:
        for name, err in fail:
            print(f"   • {name}: {err}")
    print(f"💾 Directorio: {os.path.abspath(BACKUP_DIR)}")


if __name__ == "__main__":
    main()
