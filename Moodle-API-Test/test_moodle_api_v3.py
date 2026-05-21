#!/usr/bin/env python3
"""
Script de prueba para API Moodle
Versión con diagnóstico detallado para error 500 en matriculación
"""

import os
from pathlib import Path
import requests
import json
import sys
from datetime import datetime

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

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"

results = {"passed": 0, "failed": 0, "skipped": 0}
CREATED_USER_ID = None
CREATED_COHORT_ID = None
CREATED_GROUP_ID = None
TEST_COURSE_ID = None


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


def print_info(text):
    print(f"{YELLOW}ℹ INFO{RESET} {text}")


def print_skip(text, reason=""):
    results["skipped"] += 1
    print(f"{YELLOW}⊘ SKIP{RESET} {text} {reason}")


def call_ws(function, params=None, timeout=60):
    payload = {
        "wstoken": TOKEN,
        "wsfunction": function,
        "moodlewsrestformat": "json"
    }
    if params:
        payload.update(params)

    try:
        response = requests.post(REST_ENDPOINT, data=payload, timeout=timeout, verify=True)
        response.raise_for_status()
        data = response.json()

        if isinstance(data, dict) and ("exception" in data or "errorcode" in data):
            error_msg = data.get("message", data.get("error", "Error desconocido"))
            return None, error_msg

        return data, None
    except requests.exceptions.HTTPError as e:
        status = e.response.status_code if hasattr(e, 'response') else 'unknown'
        body = e.response.text[:500] if hasattr(e, 'response') and e.response else ''
        return None, f"HTTP {status}: {body}"
    except Exception as e:
        return None, str(e)


# ============================================================
# TEST 1: INFORMACIÓN DEL SITIO
# ============================================================
print_header("TEST 1: Información del sitio")
data, error = call_ws("core_webservice_get_site_info")
if error:
    print_error("Sin conexión", error)
    sys.exit(1)
else:
    print_success("Conectado", {
        "sitename": data.get("sitename"),
        "release": data.get("release"),
        "username": data.get("username"),
        "functions_count": len(data.get("functions", []))
    })


# ============================================================
# TEST 2: CREAR USUARIO
# ============================================================
print_header("TEST 2: Crear usuario")
test_username = f"testuser_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
test_email = f"{test_username}@test.fpvirtualaragon.com"

data, error = call_ws("core_user_create_users", {
    "users[0][username]": test_username,
    "users[0][password]": "TestPass123!",
    "users[0][firstname]": "Usuario",
    "users[0][lastname]": "De Prueba",
    "users[0][email]": test_email,
    "users[0][auth]": "manual",
    "users[0][lang]": "es"
})

if error:
    print_error("No se pudo crear usuario", error)
else:
    CREATED_USER_ID = data[0]["id"]
    print_success(f"Usuario creado: ID={CREATED_USER_ID}")


# ============================================================
# TEST 3: BUSCAR USUARIO
# ============================================================
print_header("TEST 3: Buscar usuario")
if CREATED_USER_ID:
    data, error = call_ws("core_user_get_users_by_field", {
        "field": "username", "values[0]": test_username
    })
    if error:
        print_error("No se encontró", error)
    else:
        print_success("Usuario encontrado")
else:
    print_skip("Buscar usuario")


# ============================================================
# TEST 4: ACTUALIZAR USUARIO
# ============================================================
print_header("TEST 4: Actualizar usuario")
if CREATED_USER_ID:
    data, error = call_ws("core_user_update_users", {
        "users[0][id]": CREATED_USER_ID,
        "users[0][city]": "Zaragoza"
    })
    if error:
        print_error("Fallo al actualizar", error)
    else:
        print_success("Usuario actualizado")
else:
    print_skip("Actualizar usuario")


# ============================================================
# TEST 5: LISTAR USUARIOS
# ============================================================
print_header("TEST 5: Listar usuarios")
data, error = call_ws("core_user_get_users", {
    "criteria[0][key]": "username",
    "criteria[0][value]": "api_"
})
if error:
    print_error("Fallo al listar", error)
else:
    users = data.get("users", [])
    print_success(f"Encontrados {len(users)} usuarios")


# ============================================================
# TEST 6: CREAR COHORTE
# ============================================================
print_header("TEST 6: Crear cohorte")
test_cohort_name = f"Cohorte Test {datetime.now().strftime('%Y%m%d_%H%M%S')}"
data, error = call_ws("core_cohort_create_cohorts", {
    "cohorts[0][categorytype][type]": "system",
    "cohorts[0][categorytype][value]": "",
    "cohorts[0][name]": test_cohort_name,
    "cohorts[0][idnumber]": f"TEST_{datetime.now().strftime('%Y%m%d%H%M%S')}",
    "cohorts[0][description]": "Cohorte de prueba"
})
if error:
    print_error("No se pudo crear cohorte", error)
else:
    CREATED_COHORT_ID = data[0]["id"]
    print_success(f"Cohorte creada: ID={CREATED_COHORT_ID}")


# ============================================================
# TEST 7: AÑADIR USUARIO A COHORTE
# ============================================================
print_header("TEST 7: Añadir usuario a cohorte")
if CREATED_COHORT_ID and CREATED_USER_ID:
    data, error = call_ws("core_cohort_add_cohort_members", {
        "members[0][cohorttype][type]": "id",
        "members[0][cohorttype][value]": CREATED_COHORT_ID,
        "members[0][usertype][type]": "id",
        "members[0][usertype][value]": CREATED_USER_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario añadido a cohorte")
else:
    print_skip("Añadir a cohorte")


# ============================================================
# TEST 8: VER MIEMBROS COHORTE
# ============================================================
print_header("TEST 8: Miembros de cohorte")
if CREATED_COHORT_ID:
    data, error = call_ws("core_cohort_get_cohort_members", {
        "cohortids[0]": CREATED_COHORT_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        members = data[0].get("userids", []) if data else []
        print_success(f"{len(members)} miembros")
else:
    print_skip("Ver miembros")


# ============================================================
# TEST 9: LISTAR CURSOS (con timeout largo)
# ============================================================
print_header("TEST 9: Listar cursos")
data, error = call_ws("core_course_get_courses", timeout=120)
if error:
    print_error("No se pudieron listar cursos", error)
    print_info("Intentando con búsqueda alternativa...")
    data, error = call_ws("core_course_search_courses", {
        "criterianame": "search",
        "criteriavalue": "a",
        "page": 0, "perpage": 5
    }, timeout=60)
    if error:
        print_error("Tampoco con búsqueda", error)
    else:
        courses = data.get("courses", []) if isinstance(data, dict) else []
        print_success(f"Encontrados {len(courses)} cursos (vía búsqueda)")
        TEST_COURSE_ID = courses[0]["id"] if courses else None
else:
    courses = data if isinstance(data, list) else []
    print_success(f"Encontrados {len(courses)} cursos")
    TEST_COURSE_ID = courses[0]["id"] if courses else None

if TEST_COURSE_ID:
    print_info(f"Curso de prueba seleccionado: ID={TEST_COURSE_ID}")


# ============================================================
# DIAGNÓSTICO: Ver métodos de matriculación del curso
# ============================================================
print_header("DIAGNÓSTICO: Métodos de matriculación del curso")
if TEST_COURSE_ID:
    data, error = call_ws("core_enrol_get_course_enrolment_methods", {
        "courseid": TEST_COURSE_ID
    })
    if error:
        print_error("No se pudieron obtener métodos de matriculación", error)
    else:
        methods = data if isinstance(data, list) else []
        print_success(f"Métodos disponibles: {len(methods)}")
        for m in methods:
            status = "ACTIVO" if m.get("status") == 0 else "INACTIVO"
            print(f"  - {m.get('name')} (ID: {m.get('id')}, Type: {m.get('type')}) [{status}]")

        # Buscar matriculación manual
        manual_methods = [m for m in methods if m.get("type") == "manual" and m.get("status") == 0]
        if not manual_methods:
            print_info("⚠️ No hay matriculación manual activa en este curso. Prueba con otro curso.")
            TEST_COURSE_ID = None
else:
    print_skip("Diagnóstico de matriculación")


# ============================================================
# DIAGNÓSTICO: Ver roles disponibles
# ============================================================
print_header("DIAGNÓSTICO: Roles disponibles")
data, error = call_ws("core_webservice_get_site_info")
if not error:
    # No hay función directa para listar roles, pero podemos verificar con un curso conocido
    print_info("Los roles estándar de Moodle son: 1=Manager, 3=Teacher, 4=Non-editing teacher, 5=Student, etc.")
    print_info("Si el roleid 5 falla, prueba con roleid 3 (profesor) o verifica en Admin > Users > Permissions > Define roles")


# ============================================================
# TEST 10: MATRICULAR USUARIO (con diagnóstico)
# ============================================================
print_header("TEST 10: Matricular usuario en curso")
if CREATED_USER_ID and TEST_COURSE_ID:
    # Intentar primero con roleid 5 (estudiante)
    print_info("Intentando matricular como estudiante (roleid=5)...")
    data, error = call_ws("enrol_manual_enrol_users", {
        "enrolments[0][roleid]": 5,
        "enrolments[0][userid]": CREATED_USER_ID,
        "enrolments[0][courseid]": TEST_COURSE_ID,
        "enrolments[0][timestart]": 0,
        "enrolments[0][timeend]": 0,
        "enrolments[0][suspend]": 0
    })

    if error:
        print_error("Fallo con roleid=5", error)
        print_info("Intentando con roleid=3 (profesor)...")
        data, error = call_ws("enrol_manual_enrol_users", {
            "enrolments[0][roleid]": 3,
            "enrolments[0][userid]": CREATED_USER_ID,
            "enrolments[0][courseid]": TEST_COURSE_ID
        })
        if error:
            print_error("También falló con roleid=3", error)
            print_info("Posibles causas del error 500:")
            print_info("  1. El método de matriculación manual no está activo en el curso")
            print_info("  2. El usuario api_manager necesita rol de Manager o Admin en el curso")
            print_info("  3. Hay un plugin de matriculación personalizado que interfiere")
            print_info("  4. Problema de configuración del servidor (límite de memoria, timeout PHP)")
        else:
            print_success(f"Usuario matriculado como profesor en curso ID={TEST_COURSE_ID}")
    else:
        print_success(f"Usuario matriculado como estudiante en curso ID={TEST_COURSE_ID}")
else:
    print_skip("Matricular usuario", "(falta usuario o curso con matriculación manual activa)")


# ============================================================
# TEST 11: LISTAR MATRICULADOS
# ============================================================
print_header("TEST 11: Usuarios matriculados en curso")
if TEST_COURSE_ID:
    data, error = call_ws("core_enrol_get_enrolled_users", {
        "courseid": TEST_COURSE_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        users = data if isinstance(data, list) else []
        print_success(f"Curso tiene {len(users)} usuarios matriculados")
else:
    print_skip("Listar matriculados")


# ============================================================
# TEST 12: CREAR GRUPO
# ============================================================
print_header("TEST 12: Crear grupo en curso")
if TEST_COURSE_ID:
    test_group_name = f"Grupo Test {datetime.now().strftime('%H%M%S')}"
    data, error = call_ws("core_group_create_groups", {
        "groups[0][courseid]": TEST_COURSE_ID,
        "groups[0][name]": test_group_name,
        "groups[0][description]": "Grupo de prueba"
    })
    if error:
        print_error("No se pudo crear grupo", error)
        CREATED_GROUP_ID = None
    else:
        CREATED_GROUP_ID = data[0]["id"]
        print_success(f"Grupo creado: ID={CREATED_GROUP_ID}")
else:
    print_skip("Crear grupo")
    CREATED_GROUP_ID = None


# ============================================================
# TEST 13: AÑADIR USUARIO A GRUPO
# ============================================================
print_header("TEST 13: Añadir usuario a grupo")
if CREATED_GROUP_ID and CREATED_USER_ID:
    data, error = call_ws("core_group_add_group_members", {
        "members[0][groupid]": CREATED_GROUP_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario añadido al grupo")
else:
    print_skip("Añadir a grupo")


# ============================================================
# TEST 14: LISTAR GRUPOS
# ============================================================
print_header("TEST 14: Listar grupos del curso")
if TEST_COURSE_ID:
    data, error = call_ws("core_group_get_course_groups", {
        "courseid": TEST_COURSE_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        groups = data if isinstance(data, list) else []
        print_success(f"Curso tiene {len(groups)} grupos")
else:
    print_skip("Listar grupos")


# ============================================================
# TEST 15: ELIMINAR USUARIO DE GRUPO
# ============================================================
print_header("TEST 15: Eliminar usuario de grupo")
if CREATED_GROUP_ID and CREATED_USER_ID:
    data, error = call_ws("core_group_delete_group_members", {
        "members[0][groupid]": CREATED_GROUP_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario eliminado del grupo")
else:
    print_skip("Eliminar de grupo")


# ============================================================
# TEST 16: ELIMINAR GRUPO
# ============================================================
print_header("TEST 16: Eliminar grupo")
if CREATED_GROUP_ID:
    data, error = call_ws("core_group_delete_groups", {
        "groupids[0]": CREATED_GROUP_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Grupo eliminado")
else:
    print_skip("Eliminar grupo")


# ============================================================
# TEST 17: DESMATRICULAR
# ============================================================
print_header("TEST 17: Desmatricular usuario")
if CREATED_USER_ID and TEST_COURSE_ID:
    data, error = call_ws("enrol_manual_unenrol_users", {
        "enrolments[0][userid]": CREATED_USER_ID,
        "enrolments[0][courseid]": TEST_COURSE_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario desmatriculado")
else:
    print_skip("Desmatricular")


# ============================================================
# TEST 18: ELIMINAR DE COHORTE
# ============================================================
print_header("TEST 18: Eliminar usuario de cohorte")
if CREATED_COHORT_ID and CREATED_USER_ID:
    data, error = call_ws("core_cohort_delete_cohort_members", {
        "members[0][cohortid]": CREATED_COHORT_ID,
        "members[0][userid]": CREATED_USER_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario eliminado de cohorte")
else:
    print_skip("Eliminar de cohorte")


# ============================================================
# TEST 19: ELIMINAR COHORTE
# ============================================================
print_header("TEST 19: Eliminar cohorte")
if CREATED_COHORT_ID:
    data, error = call_ws("core_cohort_delete_cohorts", {
        "cohortids[0]": CREATED_COHORT_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Cohorte eliminada")
else:
    print_skip("Eliminar cohorte")


# ============================================================
# TEST 20: BORRAR USUARIO
# ============================================================
print_header("TEST 20: Borrar usuario")
if CREATED_USER_ID:
    data, error = call_ws("core_user_delete_users", {
        "userids[0]": CREATED_USER_ID
    })
    if error:
        print_error("Fallo", error)
    else:
        print_success("Usuario borrado")
else:
    print_skip("Borrar usuario")


# ============================================================
# RESUMEN
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
