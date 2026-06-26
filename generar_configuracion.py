#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generar_configuracion.py

Script interactivo para generar la configuración necesaria para levantar el
proyecto new-moodle (FP Virtual Aragón) con Docker Compose.

Genera:
  - .env                : variables de entorno del proyecto
  - docker-compose.override.yml (opcional): montar código Moodle externo
  - Directorios necesarios si no existen

Uso:
  python3 generar_configuracion.py

El script presenta la configuración por BLOQUES temáticos, no campo a campo,
para que sea más rápido revisar y ajustar los valores.
"""

import argparse
import json
import re
import secrets
import string
import sys
from pathlib import Path
from typing import Any, Callable


# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent
ENV_PATH = PROJECT_ROOT / ".env"
OVERRIDE_PATH = PROJECT_ROOT / "docker-compose.override.yml"
PLUGINS_JSON = PROJECT_ROOT / "init-data" / "plugins.json"

DEFAULT_PHP_IMAGE = "php:8.2-apache"
DEFAULT_MOODLE_VERSION = "4.5.11"
DEFAULT_MARIADB_IMAGE = "mariadb:10.11.16"

RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
RESET = "\033[0m"


# -----------------------------------------------------------------------------
# Helpers de salida
# -----------------------------------------------------------------------------
def print_section(title: str) -> None:
    print(f"\n{BLUE}{'=' * 72}{RESET}")
    print(f"{BLUE}  {title}{RESET}")
    print(f"{BLUE}{'=' * 72}{RESET}\n")


def print_info(text: str) -> None:
    print(f"{BLUE}ℹ{RESET}  {text}")


def print_warning(text: str) -> None:
    print(f"{YELLOW}⚠{RESET}  {text}")


def print_success(text: str) -> None:
    print(f"{GREEN}✔{RESET}  {text}")


def print_error(text: str) -> None:
    print(f"{RED}✖{RESET}  {text}", file=sys.stderr)


def prompt(text: str, default: str = "") -> str:
    """Pide un valor, mostrando un valor por defecto."""
    if default:
        entrada = input(f"{text} [{default}]: ").strip()
        return entrada if entrada else default
    return input(f"{text}: ").strip()


def prompt_bool(text: str, default: bool = False) -> bool:
    """Pide confirmación sí/no."""
    default_str = "s" if default else "n"
    while True:
        entrada = input(f"{text} (s/n) [{default_str}]: ").strip().lower()
        if not entrada:
            return default
        if entrada in ("s", "si", "sí", "y", "yes"):
            return True
        if entrada in ("n", "no"):
            return False
        print_warning("Por favor, responde 's' o 'n'.")


def prompt_choice(text: str, options: list[str], default: str = None) -> str:
    """Pide al usuario que elija entre varias opciones."""
    opciones_str = "/".join(options)
    default_str = default if default else ""
    while True:
        entrada = input(f"{text} ({opciones_str}) [{default_str}]: ").strip()
        if not entrada and default:
            return default
        if entrada in options:
            return entrada
        print_warning(f"Opción no válida. Usa una de: {opciones_str}")


# -----------------------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------------------
def generar_password(longitud: int = 24) -> str:
    """Genera una contraseña segura sin caracteres problemáticos en shell/.env."""
    caracteres_seguros = string.ascii_letters + string.digits + "-_@%=+*.:;,"
    while True:
        pwd = "".join(secrets.choice(caracteres_seguros) for _ in range(longitud))
        if (any(c.isupper() for c in pwd)
                and any(c.islower() for c in pwd)
                and any(c.isdigit() for c in pwd)):
            return pwd


def quote_if_needed(value: str) -> str:
    """Envuelve entre comillas si contiene espacios o caracteres especiales."""
    if not value:
        return ""
    if re.search(r"[\s#\"']", value):
        return f'"{value}"'
    return value


def detectar_plugins() -> list[dict]:
    """Lee plugins.json y devuelve la lista de plugins."""
    if not PLUGINS_JSON.exists():
        print_warning(f"No se encontró {PLUGINS_JSON}. Se omitirá la sección de plugins.")
        return []
    try:
        with open(PLUGINS_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("plugins", [])
    except json.JSONDecodeError as exc:
        print_error(f"{PLUGINS_JSON} tiene JSON inválido: {exc}")
        return []


# -----------------------------------------------------------------------------
# Bloques de configuración
# -----------------------------------------------------------------------------
class Campo:
    """Descriptor de un campo configurable dentro de un bloque."""

    def __init__(
        self,
        clave: str,
        etiqueta: str,
        valor: Any,
        tipo: str = "texto",
        opciones: list[str] | None = None,
        default_opcion: str | None = None,
        secreto: bool = False,
        ayuda: str = "",
    ):
        self.clave = clave
        self.etiqueta = etiqueta
        self.valor = valor
        self.tipo = tipo  # texto, bool, choice, password
        self.opciones = opciones or []
        self.default_opcion = default_opcion
        self.secreto = secreto
        self.ayuda = ayuda


def configurar_bloque(titulo: str, campos: list[Campo], ayuda_bloque: str = "") -> dict:
    """
    Muestra un bloque de campos y permite editarlos hasta que el usuario confirme.
    Devuelve un dict con los valores finales.
    """
    print_section(titulo)
    if ayuda_bloque:
        for linea in ayuda_bloque.split("\n"):
            print_info(linea)
        print()

    while True:
        # Mostrar campos actuales
        for campo in campos:
            if campo.tipo == "bool":
                mostrar = "sí" if campo.valor else "no"
            elif campo.secreto and campo.valor:
                mostrar = "*" * min(len(str(campo.valor)), 16)
            else:
                mostrar = str(campo.valor) if campo.valor else "(vacío)"
            print(f"  {campo.etiqueta:<36} {YELLOW}{mostrar}{RESET}")
            if campo.ayuda:
                print(f"      {campo.ayuda}")

        print()
        if prompt_bool("¿El bloque está correcto?", default=True):
            break

        print_info("Edita los campos. Pulsa Enter para mantener el valor actual.\n")
        for campo in campos:
            if campo.tipo == "texto":
                default = str(campo.valor) if campo.valor is not None else ""
                campo.valor = prompt(campo.etiqueta, default)
            elif campo.tipo == "password":
                default = str(campo.valor) if campo.valor else generar_password()
                nuevo = prompt(campo.etiqueta, default)
                campo.valor = nuevo
            elif campo.tipo == "bool":
                campo.valor = prompt_bool(campo.etiqueta, default=bool(campo.valor))
            elif campo.tipo == "choice":
                campo.valor = prompt_choice(
                    campo.etiqueta,
                    campo.opciones,
                    default=campo.default_opcion or str(campo.valor),
                )

    return {campo.clave: campo.valor for campo in campos}


def bloque_imagen_y_moodle() -> dict:
    return configurar_bloque(
        "Bloque 1: Imagen Docker y versión de Moodle",
        [
            Campo("PHP_BASE_IMAGE", "Imagen base PHP", DEFAULT_PHP_IMAGE,
                  ayuda="Recomendado: php:8.2-apache (Apache + mod_php)"),
            Campo("MOODLE_VERSION", "Versión de Moodle", DEFAULT_MOODLE_VERSION,
                  ayuda="Ejemplo: 4.5.11. Se descarga desde GitHub durante el build."),
            Campo("MARIADB_IMAGE", "Imagen MariaDB (perfil with-db)", DEFAULT_MARIADB_IMAGE,
                  ayuda="Solo se usa si levantas la BD con --profile with-db."),
        ],
        ayuda_bloque=(
            "Estas variables controlan la construcción de la imagen Docker.\n"
            "Reconstruye con 'docker compose up -d --build' para aplicar cambios."
        ),
    )


def bloque_base_de_datos() -> dict:
    print_section("Bloque 2: Base de datos")
    print_info("El proyecto permite dos modos:")
    print("  • Externa (producción): ya existe un servidor MariaDB/MySQL.")
    print("  • Interna (with-db): Docker Compose levanta un contenedor MariaDB.")
    print()

    modo = prompt_choice(
        "Modo de base de datos",
        ["externa", "interna"],
        default="externa",
    )

    if modo == "interna":
        campos = [
            Campo("MOODLE_DB_NAME", "Nombre de la BD", "moodle"),
            Campo("MOODLE_DB_USER", "Usuario de la BD", "moodle"),
            Campo("MOODLE_DB_PASSWORD", "Contraseña de la BD", generar_password(), tipo="password"),
            Campo("MYSQL_ROOT_PASSWORD", "Contraseña root de MariaDB", generar_password(), tipo="password"),
        ]
        ayuda = (
            "Modo interno: el host será 'db' y el puerto 3306 automáticamente.\n"
            "Solo necesitas indicar nombre de BD, usuario y contraseñas."
        )
    else:
        campos = [
            Campo("MOODLE_DB_HOST", "Host de la base de datos", "127.0.0.1",
                  ayuda="IP o hostname del servidor MariaDB/MySQL."),
            Campo("MOODLE_DB_PORT", "Puerto de la base de datos", "3306"),
            Campo("MOODLE_DB_NAME", "Nombre de la base de datos", "moodle"),
            Campo("MOODLE_DB_USER", "Usuario de la base de datos", "moodle"),
            Campo("MOODLE_DB_PASSWORD", "Contraseña de la base de datos", generar_password(), tipo="password"),
        ]
        ayuda = (
            "Modo externo: el contenedor 'moodle' se conectará a una BD ya existente.\n"
            "Asegúrate de que el usuario tiene permisos sobre la base de datos indicada."
        )

    resultado = configurar_bloque(
        f"Bloque 2: Base de datos ({modo})",
        campos,
        ayuda_bloque=ayuda,
    )
    resultado["DB_MODO"] = modo
    if modo == "interna":
        resultado["MOODLE_DB_HOST"] = "db"
        resultado["MOODLE_DB_PORT"] = "3306"
    return resultado


def bloque_sitio() -> dict:
    return configurar_bloque(
        "Bloque 3: Configuración del sitio Moodle",
        [
            Campo("MOODLE_URL", "URL pública de Moodle", "https://fpd.catedu.es",
                  ayuda="Debe coincidir con el dominio público (proxy inverso si lo hay)."),
            Campo("VIRTUAL_HOST", "Dominio (VIRTUAL_HOST)", "fpd.catedu.es",
                  ayuda="Usado por proxies inversos como nginx-proxy."),
            Campo("MOODLE_LANG", "Idioma por defecto", "es"),
            Campo("MOODLE_SITE_NAME", "Nombre corto del sitio", "FP Virtual Aragón"),
            Campo("MOODLE_SITE_FULLNAME", "Nombre completo del sitio",
                  "Formación Profesional Virtual a Distancia de Aragón"),
        ],
    )


def bloque_admin() -> dict:
    return configurar_bloque(
        "Bloque 4: Cuenta administrador",
        [
            Campo("MOODLE_ADMIN_USER", "Usuario administrador", "admin"),
            Campo("MOODLE_ADMIN_PASSWORD", "Contraseña administrador", generar_password(), tipo="password"),
            Campo("MOODLE_ADMIN_EMAIL", "Email administrador", "admin@catedu.es"),
        ],
    )


def bloque_proxy_ssl() -> dict:
    return configurar_bloque(
        "Bloque 5: Proxy inverso / SSL",
        [
            Campo("SSL_PROXY", "¿Moodle está detrás de HTTPS?", True, tipo="bool",
                  ayuda="SSL_PROXY=true configura Moodle para confiar en cabeceras X-Forwarded-Proto."),
            Campo("SSL_EMAIL", "Email para SSL/Let's Encrypt", "admin@catedu.es"),
        ],
        ayuda_bloque="Estas variables indican a Moodle si el tráfico entrante es HTTPS.",
    )


def bloque_smtp() -> dict:
    return configurar_bloque(
        "Bloque 6: Configuración SMTP",
        [
            Campo("SMTP_HOSTS", "Servidor SMTP", "smtp.catedu.es"),
            Campo("SMTP_USER", "Usuario SMTP", "",
                  ayuda="Dejar vacío si el servidor no requiere autenticación."),
            Campo("SMTP_PASSWORD", "Contraseña SMTP", "", tipo="password"),
            Campo("SMTP_MAXBULK", "Máximo de correos en bloque", "1"),
            Campo("NO_REPLY_ADDRESS", "Dirección no-reply", "noreply@catedu.es"),
        ],
        ayuda_bloque="Configuración del servidor de correo saliente de Moodle.",
    )


def bloque_otros(config_base: dict) -> dict:
    return configurar_bloque(
        "Bloque 7: Otros ajustes FPVirtual",
        [
            Campo("CRON_BROWSER_PASS", "Contraseña cron vía navegador (opcional)", ""),
            Campo("ENABLE_TEST_DATA", "¿Cargar datos de TEST?", False, tipo="bool",
                  ayuda="NUNCA activar en producción. Crea usuarios y matriculaciones de prueba."),
            Campo("FPVIRTUAL_PASSWORD", "Contraseña genérica FPVIRTUAL", generar_password(), tipo="password"),
            Campo("FPVIRTUAL_EMAIL", "Email FPVIRTUAL", config_base.get("MOODLE_ADMIN_EMAIL", "admin@catedu.es")),
            Campo("MANAGER_PASSWORD", "Contraseña MANAGER", generar_password(), tipo="password"),
            Campo("APP_PASSWORD", "Contraseña APP (usuario demoapp)", generar_password(), tipo="password"),
            Campo("APP_TEACHER_PASSWORD", "Contraseña APP_TEACHER", generar_password(), tipo="password"),
            Campo("API_USER_PASSWORD", "Contraseña usuario moodle-api (REST)", generar_password(), tipo="password"),
        ],
        ayuda_bloque="Contraseñas específicas del entorno FPVirtual y opciones adicionales.",
    )


def bloque_plugins() -> dict:
    plugins = detectar_plugins()
    if not plugins:
        return {"PLUGINS": {}}

    print_section("Bloque 8: Plugins de terceros")
    print_info("Se leyeron los plugins desde init-data/plugins.json")
    print_info("Para cada plugin: 's' = sí, 'n' = no, Enter = usar valor por defecto\n")

    plugins_config = {}
    for plugin in plugins:
        nombre = plugin["name"]
        componente = plugin.get("component", nombre)
        descripcion = plugin.get("description", "Sin descripción")
        default = plugin.get("default_enabled", False)
        warning = plugin.get("warning", "")
        var_name = f"PLUGIN_{nombre.upper()}"

        print(f"  {YELLOW}{var_name}{RESET} ({componente})")
        print(f"     {descripcion}")
        if warning:
            print(f"     {RED}ATENCIÓN: {warning}{RESET}")

        respuesta = input(f"  ¿Instalar? (s/n) [{'s' if default else 'n'}]: ").strip().lower()
        if not respuesta:
            valor = default
        elif respuesta in ("s", "si", "sí", "y", "yes"):
            valor = True
        elif respuesta in ("n", "no"):
            valor = False
        else:
            valor = default

        plugins_config[var_name] = "true" if valor else "false"

    return {"PLUGINS": plugins_config}


def bloque_educaaragon() -> dict:
    return configurar_bloque(
        "Bloque 9: Plugin local_educaaragon",
        [
            Campo("EDUCAARAGON_RESOURCES_PATH",
                  "Ruta en host para recursos-editables",
                  "./recursos-editables",
                  ayuda="Se monta dentro del contenedor como repositorio filesystem."),
        ],
        ayuda_bloque="Este plugin edita materiales del ministerio (Educa Aragón).",
    )


def bloque_codigo_externo() -> dict:
    print_section("Bloque 10: Código Moodle externo")
    print_info("Por defecto el código de Moodle va DENTRO de la imagen Docker.")
    print_info("Para desarrollo puedes montar código Moodle desde el host.")
    usar = prompt_bool(
        "¿Usar docker-compose.override.yml con código Moodle externo?",
        default=False,
    )
    if usar:
        path = prompt("Ruta al código Moodle en el host", "./moodle-code")
        return {"USAR_CODIGO_EXTERNO": True, "MOODLE_CODE_PATH": path}
    return {"USAR_CODIGO_EXTERNO": False, "MOODLE_CODE_PATH": ""}


def bloque_puerto() -> dict:
    return configurar_bloque(
        "Bloque 11: Puerto expuesto en el host",
        [
            Campo("MOODLE_HOST_PORT", "Puerto del host para acceder a Moodle", "8080",
                  ayuda="El contenedor escucha en el puerto 80; este es el mapeo en el host."),
        ],
    )


def recopilar_configuracion() -> dict:
    """Orquesta todos los bloques de configuración."""
    config = {}
    config.update(bloque_imagen_y_moodle())
    config.update(bloque_base_de_datos())
    config.update(bloque_sitio())
    config.update(bloque_admin())
    config.update(bloque_proxy_ssl())
    config.update(bloque_smtp())
    config.update(bloque_otros(config))
    config.update(bloque_plugins())
    config.update(bloque_educaaragon())
    config.update(bloque_codigo_externo())
    config.update(bloque_puerto())
    return config


# -----------------------------------------------------------------------------
# Generación de archivos
# -----------------------------------------------------------------------------
def generar_env(config: dict) -> str:
    """Genera el contenido del archivo .env a partir de la configuración."""
    lineas = [
        "# =============================================================================",
        "# Variables de entorno generadas por generar_configuracion.py",
        "# =============================================================================",
        "",
        "# =============================================================================",
        "# Imagen Dockerfile",
        "# =============================================================================",
        f"PHP_BASE_IMAGE={config['PHP_BASE_IMAGE']}",
        f"MOODLE_VERSION={config['MOODLE_VERSION']}",
        f"MARIADB_IMAGE={config['MARIADB_IMAGE']}",
        "",
        "# Datos de test (NO activar en producción)",
        f"ENABLE_TEST_DATA={'true' if config['ENABLE_TEST_DATA'] else 'false'}",
        "",
        "# =============================================================================",
        "# Base de datos",
        "# =============================================================================",
        f"# Modo seleccionado: {config['DB_MODO']}",
        f"MOODLE_DB_HOST={config['MOODLE_DB_HOST']}",
        f"MOODLE_DB_PORT={config['MOODLE_DB_PORT']}",
        f"MOODLE_DB_NAME={config['MOODLE_DB_NAME']}",
        f"MOODLE_DB_USER={config['MOODLE_DB_USER']}",
        f"MOODLE_DB_PASSWORD={quote_if_needed(config['MOODLE_DB_PASSWORD'])}",
        "",
    ]

    if config["DB_MODO"] == "interna":
        lineas.append(f"MYSQL_ROOT_PASSWORD={quote_if_needed(config['MYSQL_ROOT_PASSWORD'])}")
    else:
        lineas.append("# MYSQL_ROOT_PASSWORD solo es necesaria con perfil with-db (DB interna)")
        lineas.append(f"MYSQL_ROOT_PASSWORD={quote_if_needed(config.get('MYSQL_ROOT_PASSWORD', ''))}")

    lineas.extend([
        "",
        "# =============================================================================",
        "# Moodle",
        "# =============================================================================",
        f"MOODLE_URL={config['MOODLE_URL']}",
        f"VIRTUAL_HOST={config['VIRTUAL_HOST']}",
        f"MOODLE_LANG={config['MOODLE_LANG']}",
        f"MOODLE_SITE_NAME={quote_if_needed(config['MOODLE_SITE_NAME'])}",
        f"MOODLE_SITE_FULLNAME={quote_if_needed(config['MOODLE_SITE_FULLNAME'])}",
        "",
        f"MOODLE_ADMIN_USER={config['MOODLE_ADMIN_USER']}",
        f"MOODLE_ADMIN_PASSWORD={quote_if_needed(config['MOODLE_ADMIN_PASSWORD'])}",
        f"MOODLE_ADMIN_EMAIL={config['MOODLE_ADMIN_EMAIL']}",
        "",
        "# =============================================================================",
        "# Código Moodle externo (opcional)",
        "# =============================================================================",
    ])

    if config.get("MOODLE_CODE_PATH"):
        lineas.append(f"MOODLE_CODE_PATH={config['MOODLE_CODE_PATH']}")
    else:
        lineas.append("# MOODLE_CODE_PATH=./moodle-code")

    lineas.extend([
        "",
        "# =============================================================================",
        "# Proxy / SSL",
        "# =============================================================================",
        f"SSL_PROXY={'true' if config['SSL_PROXY'] else 'false'}",
        f"SSL_EMAIL={config['SSL_EMAIL']}",
        "",
        "# =============================================================================",
        "# SMTP",
        "# =============================================================================",
        f"SMTP_HOSTS={config['SMTP_HOSTS']}",
        f"SMTP_USER={config['SMTP_USER']}",
        f"SMTP_PASSWORD={quote_if_needed(config['SMTP_PASSWORD'])}",
        f"SMTP_MAXBULK={config['SMTP_MAXBULK']}",
        f"NO_REPLY_ADDRESS={config['NO_REPLY_ADDRESS']}",
        "",
        "# =============================================================================",
        "# Otros",
        "# =============================================================================",
        f"CRON_BROWSER_PASS={quote_if_needed(config['CRON_BROWSER_PASS'])}",
        "",
        "# Contraseñas específicas del entorno FPVirtual",
        f"FPVIRTUAL_PASSWORD={quote_if_needed(config['FPVIRTUAL_PASSWORD'])}",
        f"FPVIRTUAL_EMAIL={config['FPVIRTUAL_EMAIL']}",
        f"MANAGER_PASSWORD={quote_if_needed(config['MANAGER_PASSWORD'])}",
        f"APP_PASSWORD={quote_if_needed(config['APP_PASSWORD'])}",
        f"APP_TEACHER_PASSWORD={quote_if_needed(config['APP_TEACHER_PASSWORD'])}",
        f"API_USER_PASSWORD={quote_if_needed(config['API_USER_PASSWORD'])}",
        "",
        "# =============================================================================",
        "# Plugins de terceros",
        "# =============================================================================",
        "# true  : habilitado (se instala y configura)",
        "# false : deshabilitado (se omite)",
        "# Comentar la linea equivale a usar 'default_enabled' de plugins.json",
        "",
    ])

    for var_name, valor in config["PLUGINS"].items():
        lineas.append(f"{var_name}={valor}")

    lineas.extend([
        "",
        "# =============================================================================",
        "# Plugin local_educaaragon (Educa Aragón)",
        "# =============================================================================",
        f"EDUCAARAGON_RESOURCES_PATH={config['EDUCAARAGON_RESOURCES_PATH']}",
        "",
        "# =============================================================================",
        "# Puerto expuesto en el host",
        "# =============================================================================",
        f"MOODLE_HOST_PORT={config['MOODLE_HOST_PORT']}",
        "",
    ])

    return "\n".join(lineas) + "\n"


def generar_override(config: dict) -> str:
    """Genera el contenido de docker-compose.override.yml."""
    code_path = config.get("MOODLE_CODE_PATH") or "./moodle-code"
    return """# =============================================================================
# Override para usar código Moodle externo
# =============================================================================
# Generado por generar_configuracion.py
# Docker Compose carga automáticamente este archivo junto con docker-compose.yml.
# Elimínalo o renómbralo para volver al código empaquetado en la imagen.
# =============================================================================

services:
  moodle:
    volumes:
      - ${MOODLE_CODE_PATH:-%s}:/var/www/html
""" % code_path


def escribir_archivos(config: dict, forzar: bool = False) -> None:
    """Escribe .env y, si aplica, docker-compose.override.yml."""
    env_content = generar_env(config)

    if ENV_PATH.exists() and not forzar:
        if not prompt_bool(f"{ENV_PATH} ya existe. ¿Sobrescribir?", default=False):
            print_info("No se ha sobrescrito .env")
            return

    with open(ENV_PATH, "w", encoding="utf-8") as f:
        f.write(env_content)
    print_success(f"Archivo .env generado en: {ENV_PATH}")

    if config.get("USAR_CODIGO_EXTERNO"):
        override_content = generar_override(config)
        if OVERRIDE_PATH.exists() and not forzar:
            if not prompt_bool(f"{OVERRIDE_PATH} ya existe. ¿Sobrescribir?", default=False):
                print_info("No se ha sobrescrito docker-compose.override.yml")
                return
        with open(OVERRIDE_PATH, "w", encoding="utf-8") as f:
            f.write(override_content)
        print_success(f"Archivo {OVERRIDE_PATH} generado.")
    else:
        if OVERRIDE_PATH.exists():
            print_warning(f"Existe {OVERRIDE_PATH}; el código externo prevalecerá sobre la imagen.")
            if prompt_bool("¿Eliminar docker-compose.override.yml para usar el código de la imagen?", default=False):
                OVERRIDE_PATH.unlink()
                print_success("docker-compose.override.yml eliminado.")


def crear_directorios_base() -> None:
    """Crea los directorios esenciales si no existen."""
    dirs = [
        PROJECT_ROOT / "moodle-data",
        PROJECT_ROOT / "init-data",
        PROJECT_ROOT / "init-data" / "data",
        PROJECT_ROOT / "init-data" / "mbzs",
        PROJECT_ROOT / "recursos-editables",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    print_success("Directorios base verificados/creados.")


def explicar_rutas() -> None:
    print_section("Rutas importantes del proyecto")
    print_info("A continuación se resumen las rutas que se necesitan:\n")
    print(f"  {YELLOW}./moodle-data/{RESET}")
    print("    Datos persistentes de Moodle (archivos, caché, sesiones...).")
    print("    Se monta en el contenedor como /var/www/moodledata.")
    print("    NUNCA compartir este directorio entre dos contenedores activos.\n")

    print(f"  {YELLOW}./init-data/{RESET}")
    print("    Datos de inicialización montados en solo lectura (/init-data).")
    print("    Contiene plugins.json, CSVs y backups .mbz.\n")

    print(f"  {YELLOW}./init-data/data/{RESET}")
    print("    CSVs con usuarios, categorías, cursos, cohortes y matriculaciones.\n")

    print(f"  {YELLOW}./init-data/mbzs/{RESET}")
    print("    Backups de cursos en formato .mbz (opcional).\n")

    print(f"  {YELLOW}./recursos-editables/{RESET}")
    print("    Recursos editables del plugin local_educaaragon.")
    print("    Se monta como /var/www/moodledata/repository/recursos-editables.\n")

    print(f"  {YELLOW}./backups/{RESET}")
    print("    Directorio donde scripts/backup.sh dejará dumps SQL y .tar.gz.\n")


def mostrar_resumen(config: dict) -> None:
    """Muestra un resumen final y comandos de ejemplo."""
    print_section("Resumen de la configuración generada")

    print(f"  Imagen PHP:              {config['PHP_BASE_IMAGE']}")
    print(f"  Versión Moodle:          {config['MOODLE_VERSION']}")
    print(f"  Modo base de datos:      {config['DB_MODO']}")
    print(f"  Host BD:                 {config['MOODLE_DB_HOST']}:{config['MOODLE_DB_PORT']}")
    print(f"  Base de datos:           {config['MOODLE_DB_NAME']}")
    print(f"  Usuario BD:              {config['MOODLE_DB_USER']}")
    print(f"  URL Moodle:              {config['MOODLE_URL']}")
    print(f"  Dominio (VIRTUAL_HOST):  {config['VIRTUAL_HOST']}")
    print(f"  Admin Moodle:            {config['MOODLE_ADMIN_USER']}")
    print(f"  Puerto host:             {config['MOODLE_HOST_PORT']}")
    print(f"  Datos de test:           {'sí' if config['ENABLE_TEST_DATA'] else 'no'}")
    print(f"  Recursos editables:      {config['EDUCAARAGON_RESOURCES_PATH']}")

    plugins_activos = [k for k, v in config["PLUGINS"].items() if v == "true"]
    plugins_inactivos = [k for k, v in config["PLUGINS"].items() if v == "false"]
    print(f"\n  Plugins habilitados ({len(plugins_activos)}):")
    for p in plugins_activos:
        print(f"    - {p}")
    if plugins_inactivos:
        print(f"\n  Plugins deshabilitados ({len(plugins_inactivos)}):")
        for p in plugins_inactivos:
            print(f"    - {p}")

    print_section("Próximos pasos")
    print_info("1. Revisa el archivo .env generado y ajusta lo que necesites.")
    print_info("2. Asegúrate de que existen los datos de inicialización:")
    print("     ./init-data/data/        (CSV de usuarios, cursos, categorías...)")
    print("     ./init-data/mbzs/        (backups .mbz, opcional)")
    print("     ./recursos-editables/    (recursos del plugin local_educaaragon)")
    print()

    if config["DB_MODO"] == "externa":
        print_info("3. Si usas BD externa, crea la red externa si aún no existe:")
        print("     docker network create moodle_network")
        print()
        print_info("4. Levanta el stack (sin perfil with-db):")
        print("     docker compose up -d --build")
    else:
        print_info("3. Levanta el stack con perfil with-db:")
        print("     docker compose --profile with-db up -d --build")

    print()
    print_info("5. Sigue los logs durante la primera instalación:")
    print("     docker compose logs -f moodle")
    print()
    print_info("6. Accede al sitio:")
    print(f"     {config['MOODLE_URL']}  (o http://localhost:{config['MOODLE_HOST_PORT']} en local)")
    print()
    print_info("7. Backup coordinado (cuando el sitio esté en marcha):")
    print("     chmod +x scripts/backup.sh")
    print("     ./scripts/backup.sh")

    print_section("Notas importantes")
    print_warning("NUNCA compartas ./moodle-data entre dos contenedores activos.")
    print_warning("NUNCA actives ENABLE_TEST_DATA=true en producción.")
    print_warning("Revisa init-data/plugins.json si quieres añadir/quitar plugins del catálogo.")


# -----------------------------------------------------------------------------
# Modo demo
# -----------------------------------------------------------------------------
def generar_configuracion_demo() -> dict:
    """Genera una configuración de ejemplo usando valores por defecto."""
    plugins = detectar_plugins()
    plugins_config = {}
    for plugin in plugins:
        var_name = f"PLUGIN_{plugin['name'].upper()}"
        plugins_config[var_name] = "true" if plugin.get("default_enabled", False) else "false"

    return {
        "PHP_BASE_IMAGE": DEFAULT_PHP_IMAGE,
        "MOODLE_VERSION": DEFAULT_MOODLE_VERSION,
        "MARIADB_IMAGE": DEFAULT_MARIADB_IMAGE,
        "DB_MODO": "externa",
        "MOODLE_DB_HOST": "db",
        "MOODLE_DB_PORT": "3306",
        "MOODLE_DB_NAME": "moodle",
        "MOODLE_DB_USER": "moodle",
        "MOODLE_DB_PASSWORD": generar_password(),
        "MYSQL_ROOT_PASSWORD": generar_password(),
        "MOODLE_URL": "https://fpd.catedu.es",
        "VIRTUAL_HOST": "fpd.catedu.es",
        "MOODLE_LANG": "es",
        "MOODLE_SITE_NAME": "FP Virtual Aragón",
        "MOODLE_SITE_FULLNAME": "Formación Profesional Virtual a Distancia de Aragón",
        "MOODLE_ADMIN_USER": "admin",
        "MOODLE_ADMIN_PASSWORD": generar_password(),
        "MOODLE_ADMIN_EMAIL": "admin@catedu.es",
        "SSL_PROXY": True,
        "SSL_EMAIL": "admin@catedu.es",
        "SMTP_HOSTS": "smtp.catedu.es",
        "SMTP_USER": "",
        "SMTP_PASSWORD": "",
        "SMTP_MAXBULK": "1",
        "NO_REPLY_ADDRESS": "noreply@catedu.es",
        "CRON_BROWSER_PASS": "",
        "ENABLE_TEST_DATA": False,
        "FPVIRTUAL_PASSWORD": generar_password(),
        "FPVIRTUAL_EMAIL": "admin@catedu.es",
        "MANAGER_PASSWORD": generar_password(),
        "APP_PASSWORD": generar_password(),
        "APP_TEACHER_PASSWORD": generar_password(),
        "API_USER_PASSWORD": generar_password(),
        "PLUGINS": plugins_config,
        "EDUCAARAGON_RESOURCES_PATH": "./recursos-editables",
        "USAR_CODIGO_EXTERNO": False,
        "MOODLE_CODE_PATH": "",
        "MOODLE_HOST_PORT": "8080",
    }


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Genera la configuración (.env) para levantar new-moodle.",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Genera un .env de ejemplo con valores por defecto (sin interacción).",
    )
    parser.add_argument(
        "--sobrescribir",
        action="store_true",
        help="Sobrescribe archivos existentes sin preguntar.",
    )
    args = parser.parse_args()

    try:
        explicar_rutas()
        crear_directorios_base()

        if args.demo:
            print_warning("Modo demo: se usarán valores por defecto. NO uses este .env en producción.")
            config = generar_configuracion_demo()
        else:
            config = recopilar_configuracion()

        escribir_archivos(config, forzar=args.sobrescribir)
        mostrar_resumen(config)
        return 0
    except KeyboardInterrupt:
        print("\n\nGeneración cancelada por el usuario.")
        return 130
    except Exception as exc:
        print_error(f"Error inesperado: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
