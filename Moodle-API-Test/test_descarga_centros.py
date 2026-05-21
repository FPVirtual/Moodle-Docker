#!/usr/bin/env python3
"""
Descarga la estructura completa de centros Moodle:
- Árbol de categorías (centros → familias → ciclos)
- Todos los cursos de cada subcategoría
"""

import os
from pathlib import Path
import requests
import json
from datetime import datetime

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN
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

CENTROS_DESCRIPTION = {
    "50020125": None,  # CAMPUS DIGITAL FP
    "50008460": None,  # IES LUIS BUÑUEL
}

OUTPUT_FILE = "estructura_centros_cursos_moodle.json"

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
    data = response.json()
    if isinstance(data, dict) and "exception" in data:
        raise Exception(f"API Error [{data.get('errorcode')}]: {data.get('message')}")
    return data


def get_all_categories() -> list:
    result = api_call("core_course_get_categories", {})
    return result if isinstance(result, list) else []


def get_courses_by_category(category_id: int) -> list:
    """Obtiene todos los cursos de una categoría específica."""
    try:
        result = api_call("core_course_get_courses_by_field", {
            "field": "category",
            "value": str(category_id),
        })
        courses = result.get("courses", []) if isinstance(result, dict) else []
        
        # Simplificar datos de cada curso
        simplified = []
        for course in courses:
            simplified.append({
                "id": course.get("id"),
                "shortname": course.get("shortname"),
                "fullname": course.get("fullname"),
                "displayname": course.get("displayname"),
                "idnumber": course.get("idnumber"),
                "visible": course.get("visible"),
                "startdate": course.get("startdate"),
                "enddate": course.get("enddate"),
                "timemodified": course.get("timemodified"),
                "categoryid": course.get("categoryid"),
            })
        return simplified
    except Exception as e:
        print(f"    ⚠️  Error obteniendo cursos de categoría {category_id}: {e}")
        return []


def clean_desc(desc: str) -> str:
    if not desc:
        return ""
    return (desc
            .replace("<p>", "")
            .replace("</p>", "")
            .replace("<br />", "")
            .replace("<br>", "")
            .replace("<p dir=\"ltr\" style=\"text-align:left;\">", "")
            .strip())


def build_category_tree(categories_flat: list, parent_id: int = 0, include_courses: bool = True) -> list:
    """Construye el árbol de categorías recursivamente, opcionalmente con cursos."""
    tree = []
    for cat in categories_flat:
        if cat.get("parent") == parent_id:
            node = {
                "id": cat.get("id"),
                "name": cat.get("name"),
                "idnumber": cat.get("idnumber"),
                "description": clean_desc(cat.get("description")),
                "visible": cat.get("visible"),
                "depth": cat.get("depth"),
                "path": cat.get("path"),
                "coursecount": cat.get("coursecount"),
            }

            # Obtener cursos de esta categoría (solo si es nivel hoja o se solicita)
            if include_courses:
                courses = get_courses_by_category(cat.get("id"))
                if courses:
                    node["courses"] = courses
                    node["course_count_actual"] = len(courses)

            # Recursivamente obtener hijos
            children = build_category_tree(categories_flat, cat.get("id"), include_courses)
            if children:
                node["children"] = children

            tree.append(node)
    return tree


def count_categories(tree: list) -> int:
    count = len(tree)
    for node in tree:
        if "children" in node:
            count += count_categories(node["children"])
    return count


def count_courses(tree: list) -> int:
    """Cuenta todos los cursos en un árbol."""
    count = 0
    for node in tree:
        if "courses" in node:
            count += len(node["courses"])
        if "children" in node:
            count += count_courses(node["children"])
    return count


def get_center_structure(center_description: str, all_categories: list) -> dict:
    print(f"\n{'='*60}")
    print(f"🔍 CENTRO: {center_description}")
    print(f"{'='*60}")

    # Buscar categoría raíz del centro por description
    center_cat = None
    for cat in all_categories:
        if clean_desc(cat.get("description")) == center_description and cat.get("parent") == 0:
            center_cat = cat
            break

    if not center_cat:
        raise Exception(f"Centro '{center_description}' no encontrado")

    center_id = center_cat.get("id")
    center_name = center_cat.get("name")
    print(f"✅ Encontrado: '{center_name}' (ID: {center_id})")

    # Construir árbol completo con cursos
    print(f"⏳ Descargando estructura y cursos...")
    tree = build_category_tree(all_categories, center_id, include_courses=True)

    total_cats = count_categories(tree)
    total_courses = count_courses(tree)

    print(f"📊 Subcategorías: {total_cats}")
    print(f"📚 Cursos totales: {total_courses}")

    return {
        "center_description": center_description,
        "center_name": center_name,
        "center_id": center_id,
        "total_categories": total_cats,
        "total_courses": total_courses,
        "structure": tree,
    }


def main():
    print("╔════════════════════════════════════════════════════╗")
    print("║  ESTRUCTURA DE CENTROS + CURSOS MOODLE             ║")
    print("╚════════════════════════════════════════════════════╝")
    print(f"🔗 URL: {MOODLE_URL}")
    print(f"📅 Fecha: {datetime.now().isoformat()}")

    all_categories = get_all_categories()
    print(f"\n📥 Total categorías en sistema: {len(all_categories)}")

    result = {
        "generated_at": datetime.now().isoformat(),
        "moodle_url": MOODLE_URL,
        "centers": [],
    }

    for center_desc in CENTROS_DESCRIPTION.keys():
        try:
            center_data = get_center_structure(center_desc, all_categories)
            result["centers"].append(center_data)
        except Exception as e:
            print(f"❌ ERROR: {e}")
            result["centers"].append({
                "center_description": center_desc,
                "error": str(e),
            })

    # Guardar JSON
    print(f"\n💾 Guardando en: {OUTPUT_FILE}")
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    # Estadísticas del archivo
    file_size = len(json.dumps(result))
    print(f"📦 Tamaño del JSON: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)")

    # Resumen final
    print("\n" + "=" * 60)
    print("📊 RESUMEN FINAL")
    print("=" * 60)
    for center in result["centers"]:
        if "error" in center:
            print(f"\n❌ {center['center_description']}: {center['error']}")
        else:
            print(f"\n✅ {center['center_description']}: {center['center_name']}")
            print(f"   ├─ Subcategorías: {center['total_categories']}")
            print(f"   └─ Cursos: {center['total_courses']}")

    print(f"\n📁 Archivo: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
