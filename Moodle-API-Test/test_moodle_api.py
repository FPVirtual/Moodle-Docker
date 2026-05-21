#!/usr/bin/env python3
"""
Script de prueba para API Moodle
"""

import os
from pathlib import Path
import requests
import json
import sys
from datetime import datetime

# ============================================================
# CONFIGURACIÓN
# ============================================================

# Cargar variables desde .env si existe
_env_path = Path(__file__).parent / '.env'
if _env_path.exists():
    with open(_env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ.setdefault(key, value)

BASE_URL = os.environ.get("MOODLE_URL")
TOKEN = os.environ.get("MOODLE_TOKEN")

if not BASE_URL or not TOKEN:
    print("❌ ERROR: Define MOODLE_URL y MOODLE_TOKEN en el archivo .env")
    sys.exit(1)

REST_ENDPOINT = f"{BASE_URL}/webservice/rest/server.php"

# Colores para terminal
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"

# Variables inicializadas al inicio:
CREATED_USER_ID = None
CREATED_COHORT_ID = None
CREATED_GROUP_ID = None
TEST_COURSE_ID = None

results = {"passed": 0, "failed": 0, "skipped": 0}


def print_header(text):
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}{BLUE}{text}{RESET}")
    print(f"{BOLD}{'='*60}{RESET}")


def print_success(text, data=None):
    results["passed"] += 1
    print(f"{GREEN}✓ PASS{RESET} {text}")
    if data:
        print(f"  {YELLOW}→ Respuesta:{RESET}")
        print(json.dumps(data, indent=2, ensure_ascii=False)[:500])


def print_error(text, error=None):
    results["failed"] += 1
    print(f"{RED}✗ FAIL{RESET} {text}")
    if error:
        print(f"  {RED}→ Error:{RESET} {error}")


def print_skip(text, reason=""):
    results["skipped"] += 1
    print(f"{YELLOW}⊘ SKIP{RESET} {text} {reason}")


def call_ws(function, params=None):
    """Llama a una función del web service de Moodle."""
    payload = {
        "wstoken": TOKEN,
        "wsfunction": function,
        "moodlewsrestformat": "json"
    }
    if params:
        payload.update(params)

    try:
        response = requests.post(REST_ENDPOINT, data=payload, timeout=130, verify=True)
        response.raise_for_status()
        data = response.json()

        # Moodle devuelve errores como JSON con campo 'exception' o 'errorcode'
        if isinstance(data, dict) and ("exception" in data or "errorcode" in data):
            error_msg = data.get("message", data.get("error", "Error desconocido"))
            return None, error_msg

        return data, None
    except requests.exceptions.SSLError as e:
        return None, f"Error SSL: {e}"
    except requests.exceptions.ConnectionError as e:
        return None, f"Error de conexión: {e}"
    except requests.exceptions.Timeout:
        return None, "Timeout"
    except Exception as e:
        return None, str(e)


# ============================================================
# TEST 1: INFORMACIÓN DEL SITIO
# ============================================================
print_header("TEST 1: Información del sitio (core_webservice_get_site_info)")
data, error = call_ws("core_webservice_get_site_info")
if error:
    print_error("No se pudo obtener info del sitio", error)
    print(f"\n{RED}ABORTANDO: Sin conexión al API{RESET}")
    sys.exit(1)
else:
    print_success("Conexión exitosa", {
        "sitename": data.get("sitename"),
        "siteurl": data.get("siteurl"),
        "release": data.get("release"),
        "version": data.get("version"),
        "userid": data.get("userid"),
        "username": data.get("username"),
        "fullname": data.get("fullname"),
        "functions_count": len(data.get("functions", []))
    })
    USER_ID = data.get("userid")
    # Verificar que tenemos las funciones necesarias
    available_functions = [f["name"] for f in data.get("functions", [])]
    print(f"  {BLUE}→ Funciones disponibles:{RESET} {len(available_functions)}")


# ============================================================
# TEST 2: CREAR USUARIO
# ============================================================
print_header("TEST 2: Crear usuario (core_user_create_users)")
test_username = f"testuser_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
test_email = f"{test_username}@test.fpvirtualaragon.com"

data, error = call_ws("core_user_create_users", {
    "users[0][username]": test_username,
    "users[0][password]": "TestPass123!",
    "users[0][firstname]": "Usuario",
    "users[0][lastname]": "De Prueba",
    "users[0][email]": test_email,
    "users[0][auth]": "manual",
    "users[0][lang]": "es",
    "users[0][maildisplay]": 0
})

if error:
    print_error("No se pudo crear el usuario", error)
    CREATED_USER_ID = None
else:
    CREATED_USER_ID = data[0]["id"] if data and len(data) > 0 else None
    print_success(f"Usuario creado: ID={CREATED_USER_ID}, username={test_username}", data)


# ============================================================
# TEST 3: BUSCAR USUARIO POR USERNAME
# ============================================================
print_header("TEST 3: Buscar usuario por username (core_user_get_users_by_field)")
if CREATED_USER_ID:
    data, error = call_ws("core_user_get_users_by_field", {
        "field": "username",
        "values[0]": test_username
    })
    if error:
        print_error("No se pudo buscar el usuario", error)
    else:
        print_success(f"Usuario encontrado", data)
else:
    print_skip("Buscar usuario", "(usuario no creado)")


# ============================================================
# TEST 4: ACTUALIZAR USUARIO
# ============================================================
print_header("TEST 4: Actualizar usuario (core_user_update_users)")
if CREATED_USER_ID:
    data, error = call_ws("core_user_update_users", {
        "users[0][id]": CREATED_USER_ID,
        "users[0][firstname]": "Usuario",
        "users[0][lastname]": "Actualizado",
        "users[0][city]": "Zaragoza"
    })
    if error:
        print_error("No se pudo actualizar el usuario", error)
    else:
        print_success("Usuario actualizado correctamente", data)
else:
    print_skip("Actualizar usuario", "(usuario no creado)")


# ============================================================
# TEST 5: LISTAR USUARIOS (con filtros)
# ============================================================
print_header("TEST 5: Listar usuarios (core_user_get_users)")
data, error = call_ws("core_user_get_users", {
    "criteria[0][key]": "username",
    "criteria[0][value]": "api_"
})
if error:
    print_error("No se pudo listar usuarios", error)
else:
    users = data.get("users", [])
    print_success(f"Encontrados {len(users)} usuarios que coinciden con 'api_'", 
                  {"total": data.get("total"), "count": len(users), "primeros": [u["username"] for u in users[:3]]})


# ============================================================
# TEST 6: CREAR COHORTE
# ============================================================
print_header("TEST 6: Crear cohorte (core_cohort_create_cohorts)")
test_cohort_name = f"Cohorte Test {datetime.now().strftime('%Y%m%d_%H%M%S')}"
data, error = call_ws("core_cohort_create_cohorts", {
    "cohorts[0][categorytype][type]": "system",
    "cohorts[0][categorytype][value]": "",
    "cohorts[0][name]": test_cohort_name,
    "cohorts[0][idnumber]": f"TEST_COHORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
    "cohorts[0][description]": "Cohorte de prueba creada vía API"
})
if error:
    print_error("No se pudo crear la cohorte", error)
    CREATED_COHORT_ID = None
else:
    CREATED_COHORT_ID = data[0]["id"] if data and len(data) > 0 else None
    print_success(f"Cohorte creada: ID={CREATED_COHORT_ID}", data)


# ============================================================
# TEST 7: AÑADIR USUARIO A COHORTE
# ============================================================
print_header("TEST 7: Añadir usuario a cohorte (core_cohort_add_cohort_members)")
if CREATED_COHORT_ID and CREATED_USER_ID:
    data, error = call_ws("core_cohort_add_cohort_members", {
        "members[0][cohorttype][type]": "id",
        "members[0][cohorttype][value]": CREATED_COHORT_ID,
        "members[0][usertype][type]": "id",
        "members[0][usertype][value]": CREATED_USER_ID
    })
    if error:
        print_error("No se pudo añadir usuario a cohorte", error)
    else:
        print_success("Usuario añadido a cohorte correctamente", data)
else:
    print_skip("Añadir a cohorte", "(falta cohorte o usuario)")


# ============================================================
# TEST 8: VER MIEMBROS DE COHORTE
# ============================================================
print_header("TEST 8: Ver miembros de cohorte (core_cohort_get_cohort_members)")
if CREATED_COHORT_ID:
    data, error = call_ws("core_cohort_get_cohort_members", {
        "cohortids[0]": CREATED_COHORT_ID
    })
    if error:
        print_error("No se pudo obtener miembros", error)
    else:
        members = data[0].get("userids", []) if data and len(data) > 0 else []
        print_success(f"Cohorte tiene {len(members)} miembros", {"cohortid": CREATED_COHORT_ID, "members": members})
else:
    print_skip("Ver miembros de cohorte", "(cohorte no creada)")


# ============================================================
# TEST 9: LISTAR CURSOS
# ============================================================
print_header("TEST 9: Listar cursos (core_course_get_courses)")
data, error = call_ws("core_course_get_courses")
if error:
    print_error("No se pudieron listar cursos", error)
else:
    courses = data if isinstance(data, list) else []
    print_success(f"Encontrados {len(courses)} cursos", 
                  {"total": len(courses), "ejemplos": [{"id": c["id"], "fullname": c["fullname"]} for c in courses[:3]]})
    # Guardar el primer curso para pruebas de matriculación
    TEST_COURSE_ID = courses[0]["id"] if courses else None


# ============================================================
# TEST 10: MATRICULAR USUARIO EN CURSO
# ============================================================
print_header("TEST 10: Matricular usuario en curso (enrol_manual_enrol_users)")
if CREATED_USER_ID and TEST_COURSE_ID:
    data, error = call_ws("enrol_manual_enrol_users", {
        "enrolments[0][roleid]": 5,  # 5 = estudiante
        "enrolments[0][userid]": CREATED_USER_ID,
        "enrolments[0][courseid]": TEST_COURSE_ID,
        "enrolments[0][timestart]": 0,
        "enrolments[0][timeend]": 0,
        "enrolments[0][suspend]": 0
    })
    if error:
        print_error("No se pudo matricular el usuario", error)
    else:
        print_success(f"Usuario matriculado en curso ID={TEST_COURSE_ID}", data)
else:
    print_skip("Matricular usuario", "(falta usuario o curso)")


# ============================================================
# TEST 11: LISTAR USUARIOS MATRICULADOS EN CURSO (con filtros)
# ============================================================
print_header("TEST 11: Usuarios matriculados en curso (core_enrol_get_enrolled_users)")
if TEST_COURSE_ID:
    data, error = call_ws("core_enrol_get_enrolled_users", {
        "courseid": TEST_COURSE_ID
    })
    if error:
        print_error("No se pudieron obtener usuarios matriculados", error)
    else:
        users = data if isinstance(data, list) else []
        print_success(f"Curso tiene {len(users)} usuarios matriculados", 
                      {"courseid": TEST_COURSE_ID, "count": len(users), "usuarios": [u["username"] for u in users[:5]]})
else:
    print_skip("Listar matriculados", "(no hay curso disponible)")


# ============================================================
# TEST 12: CREAR GRUPO EN CURSO
# ============================================================
print_header("TEST 12: Crear grupo en curso (core_group_create_groups)")
if TEST_COURSE_ID:
    test_group_name = f"Grupo Test {datetime.now().strftime('%H%M%S')}"
    data, error = call_ws("core_group_create_groups", {
        "groups[0][courseid]": TEST_COURSE_ID,
        "groups[0][name]": test_group_name,
        "groups[0][description]": "Grupo de prueba creado vía API",
        "groups[0][descriptionformat]": 1
    })
    if error:
        print_error("No se pudo crear el grupo", error)
        CREATED_GROUP_ID = None
    else:
        CREATED_GROUP_ID = data[0]["id"] if data and len(data) > 0 else None
        print_success(f"Grupo creado: ID={CREATED_GROUP_ID}", data)
else:
    print_skip("Crear grupo", "(no hay curso disponible)")
    CREATED_GROUP_ID = None


# ============================================================
# TEST 13: AÑADIR USUARIO A GRUPO
# ============================================================
print_header("TEST 13: Añadir usuario a grupo (core_group_add_group_members)")
if CREATED_GROUP_ID and CREATED_USER_ID:
    data, error = call_ws("core_group_add_group_members", {
        "members[0][groupid]": CREATED_GROUP_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("No se pudo añadir usuario al grupo", error)
    else:
        print_success("Usuario añadido al grupo correctamente", data)
else:
    print_skip("Añadir a grupo", "(falta grupo o usuario)")


# ============================================================
# TEST 14: LISTAR GRUPOS DEL CURSO
# ============================================================
print_header("TEST 14: Listar grupos del curso (core_group_get_course_groups)")
if TEST_COURSE_ID:
    data, error = call_ws("core_group_get_course_groups", {
        "courseid": TEST_COURSE_ID
    })
    if error:
        print_error("No se pudieron listar grupos", error)
    else:
        groups = data if isinstance(data, list) else []
        print_success(f"Curso tiene {len(groups)} grupos", 
                      {"courseid": TEST_COURSE_ID, "grupos": [{"id": g["id"], "name": g["name"]} for g in groups[:5]]})
else:
    print_skip("Listar grupos", "(no hay curso disponible)")


# ============================================================
# TEST 15: ELIMINAR USUARIO DE GRUPO
# ============================================================
print_header("TEST 15: Eliminar usuario de grupo (core_group_delete_group_members)")
if CREATED_GROUP_ID and CREATED_USER_ID:
    data, error = call_ws("core_group_delete_group_members", {
        "members[0][groupid]": CREATED_GROUP_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("No se pudo eliminar usuario del grupo", error)
    else:
        print_success("Usuario eliminado del grupo correctamente", data)
else:
    print_skip("Eliminar de grupo", "(falta grupo o usuario)")


# ============================================================
# TEST 16: ELIMINAR GRUPO
# ============================================================
print_header("TEST 16: Eliminar grupo (core_group_delete_groups)")
if CREATED_GROUP_ID:
    data, error = call_ws("core_group_delete_groups", {
        "groupids[0]": CREATED_GROUP_ID
    })
    if error:
        print_error("No se pudo eliminar el grupo", error)
    else:
        print_success("Grupo eliminado correctamente", data)
else:
    print_skip("Eliminar grupo", "(grupo no creado)")


# ============================================================
# TEST 17: DESMATRICULAR USUARIO DE CURSO
# ============================================================
print_header("TEST 17: Desmatricular usuario (enrol_manual_unenrol_users)")
if CREATED_USER_ID and TEST_COURSE_ID:
    data, error = call_ws("enrol_manual_unenrol_users", {
        "enrolments[0][userid]": CREATED_USER_ID,
        "enrolments[0][courseid]": TEST_COURSE_ID
    })
    if error:
        print_error("No se pudo desmatricular el usuario", error)
    else:
        print_success("Usuario desmatriculado correctamente", data)
else:
    print_skip("Desmatricular usuario", "(falta usuario o curso)")


# ============================================================
# TEST 18: ELIMINAR USUARIO DE COHORTE
# ============================================================
print_header("TEST 18: Eliminar usuario de cohorte (core_cohort_delete_cohort_members)")
if CREATED_COHORT_ID and CREATED_USER_ID:
    data, error = call_ws("core_cohort_delete_cohort_members", {
        "members[0][cohortid]": CREATED_COHORT_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("No se pudo eliminar usuario de cohorte", error)
    else:
        print_success("Usuario eliminado de cohorte correctamente", data)
else:
    print_skip("Eliminar de cohorte", "(falta cohorte o usuario)")


# ============================================================
# TEST 19: ELIMINAR COHORTE
# ============================================================
print_header("TEST 19: Eliminar cohorte (core_cohort_delete_cohorts)")
if CREATED_COHORT_ID:
    data, error = call_ws("core_cohort_delete_cohorts", {
        "cohortids[0]": CREATED_COHORT_ID
    })
    if error:
        print_error("No se pudo eliminar la cohorte", error)
    else:
        print_success("Cohorte eliminada correctamente", data)
else:
    print_skip("Eliminar cohorte", "(cohorte no creada)")


# ============================================================
# TEST 20: BORRAR USUARIO
# ============================================================
print_header("TEST 20: Borrar usuario (core_user_delete_users)")
if CREATED_USER_ID:
    data, error = call_ws("core_user_delete_users", {
        "userids[0]": CREATED_USER_ID
    })
    if error:
        print_error("No se pudo borrar el usuario", error)
    else:
        print_success("Usuario borrado correctamente", data)
else:
    print_skip("Borrar usuario", "(usuario no creado)")


# ============================================================
# RESUMEN FINAL
# ============================================================
print_header("RESUMEN DE PRUEBAS")
print(f"{GREEN}✓ Pasados:{RESET}   {results['passed']}")
print(f"{RED}✗ Fallidos:{RESET}  {results['failed']}")
print(f"{YELLOW}⊘ Saltados:{RESET}  {results['skipped']}")
print(f"{BOLD}Total:{RESET}     {results['passed'] + results['failed'] + results['skipped']}")

if results['failed'] == 0:
    print(f"\n{GREEN}{BOLD}🎉 TODAS LAS PRUEBAS PASARON{RESET}")
else:
    print(f"\n{RED}{BOLD}⚠️  HAY {results['failed']} PRUEBAS FALLIDAS{RESET}")
