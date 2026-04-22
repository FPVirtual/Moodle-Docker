# Rama `creacion_moodle-data_propio` — Documento de trabajo

> Fecha de creación: 2026-04-21
> Estado: En desarrollo / Testing
> Rama Git: `creacion_moodle-data_propio`

---

## 1. Objetivo

Crear una **imagen Docker autocontenida** que permita desplegar el entorno completo de Moodle FPD (Formación Profesional a Distancia de Aragón) **sin depender de importar `moodle-data` desde otra instancia**.

En otras palabras: con una base de datos vacía y `INSTALL_TYPE=new-install`, el contenedor debe ser capaz de generar todo el entorno funcional (plugins, temas, idiomas, categorías, cursos, usuarios, configuraciones) en su primer arranque.

---

## 2. ¿Qué problema resuelve?

### Situación anterior (rama `main` / migración de abril 2026)
- El despliegue funcionaba copiando `moodle-code` del contenedor anterior (`www.fpvirtualaragon.es`).
- El `moodle-data` se montaba como **volumen compartido** desde el contenedor anterior.
- **Problema**: Para replicar el entorno en otro servidor, era necesario copiar gigas de datos de otra instancia. No era una instalación "desde cero".

### Situación deseada (esta rama)
- La imagen Docker contiene **todo el código necesario**: Moodle core + plugins + temas + scripts custom.
- Los `init-scripts` configuran todo automáticamente al primer arranque.
- El `moodle-data` se genera **propiamente** a partir del código y la configuración, sin depender de datos importados.
- **Beneficio**: Se puede desplegar en cualquier servidor (testing, staging, producción) con solo la imagen Docker, el `.env` y una BD vacía.

---

## 3. Arquitectura objetivo

```
┌──────────────────────────────────────────────────────────────┐
│  Imagen Docker (build)                                       │
│  ──────────────────────────────────────────────────────────  │
│  • Moodle 4.1.19 (descargado desde GitHub oficial)           │
│  • 20+ plugins de terceros (clonados desde git)              │
│  • Scripts PHP custom (decalogo, faqs, soporte, etc.)        │
│  • init-scripts (new-install + upgrade)                      │
│  • Tema FPD (assets, SCSS, mustaches)                        │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│  Contenedor (runtime) — INSTALL_TYPE=new-install             │
│  ──────────────────────────────────────────────────────────  │
│  1. entrypoint.sh genera config.php                          │
│  2. install_database.php crea tablas en BD vacía             │
│  3. init.sh ejecuta:                                         │
│     • moodle.sh     → configura sitio, SMTP, idioma es       │
│     • plugins.sh    → configura plugins (ya en la imagen)    │
│     • import_FPD... → crea categorías, cursos, usuarios      │
│     • theme.sh      → aplica tema Moove + assets FPD         │
│  4. moodle-data/ se genera automáticamente (filedir, lang)   │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Cambios realizados en esta rama

### 4.1. `Dockerfile`

| Antes (rama main) | Ahora (esta rama) |
|-------------------|-------------------|
| `COPY moodle-code /var/www/html` | Descarga Moodle 4.1.19 desde GitHub releases |
| Plugins dependían del moodle-code copiado | Clona plugins desde git durante el build |
| Sin scripts custom en la imagen | Copia `custom/` a `/var/www/html/` |

**Instrucciones añadidas**:
```dockerfile
ARG MOODLE_VERSION=4.1.19
RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz | tar xz -C /tmp \
    && mv /tmp/moodle-* /usr/src/moodle \
    && cp -r /usr/src/moodle/* /var/www/html/ \
    && chown -R www-data:www-data /var/www/html /usr/src/moodle
```

Y ~20 instrucciones `git clone --depth 1` para plugins de terceros.

### 4.2. `custom/` (nuevo directorio)

Copiado desde el contenedor anterior (`www.fpvirtualaragon.es`). Contiene aplicaciones PHP que viven en la raíz del documento web:

| Directorio | Contenido |
|-----------|-----------|
| `custom/decalogo/` | 4 imágenes JPG del decálogo metodológico FP Virtual |
| `custom/faqs/` | Imágenes y recursos de preguntas frecuentes |
| `custom/private-reports/` | Scripts PHP internos: `docentes.php`, `inspeccion.php`, `jefaturas.php`, `mensajeria.php` |
| `custom/soporte/` | Formulario de soporte con captcha (`index.php`, `action.php`, etc.) |
| `custom/userpix/` | `index.php` para gestión de avatares |

> **Nota**: Los directorios `private-reports/` y `soporte/` tenían repositorios `.git` embebidos que fueron eliminados para evitar problemas de submódulos.

### 4.3. `init-scripts/new-install/moodle.sh`

Añadida la instalación automática del idioma español:
```bash
moosh lang-install es
```

Esto garantiza que el paquete de idioma `es` exista en `moodle-data/lang/es/` sin depender de que esté copiado desde otra instancia.

### 4.4. `init-scripts/new-install/plugins.sh`

Modificado el bucle de instalación para que ejecute `actions_asociated_to_plugin` **independientemente** de si `moosh plugin-install` tuvo éxito, porque los plugins ya están clonados en la imagen:

```bash
if moosh plugin-list | grep ${PLUGIN} | grep ${VERSION_MINOR} >/dev/null; then
    moosh plugin-install -d ${PLUGIN} || echo "${PLUGIN} already present or install skipped"
fi
actions_asociated_to_plugin ${PLUGIN}
```

### 4.5. `docker-compose.yml`

El volumen `moodle-data` vuelve a usar el path local `./moodle-data` (en lugar del path absoluto del contenedor anterior).

---

## 5. Cómo probar esta rama

### 5.1. Prerequisitos

- Docker y Docker Compose instalados.
- Red externa `nginx-proxy_frontend` creada.
- Base de datos MariaDB/MySQL vacía y accesible.
- Archivo `.env` configurado (ver sección 5.3).

### 5.2. Pasos

```bash
# 1. Cambiar a esta rama
cd /var/moodle-docker-deploy/moodle-docker-test/Moodle-Docker
git checkout creacion_moodle-data_propio

# 2. Asegurar que moodle-data sea local y esté vacío
sudo rm -rf moodle-data
mkdir moodle-data
sudo chown -R 33:33 moodle-data
sudo chmod 755 moodle-data

# 3. Verificar .env (debe apuntar a una BD vacía y tener INSTALL_TYPE=new-install)
cat .env | grep INSTALL_TYPE
# → INSTALL_TYPE=new-install

# 4. Build y despliegue
docker compose up -d --build

# 5. Seguir logs (el proceso puede tardar varios minutos)
docker compose logs -f moodle
```

### 5.3. Variables de entorno mínimas para prueba

```env
MOODLE_DB_HOST=moodle_mariadb_10.11.16
MOODLE_DB_PORT=3306
MOODLE_DB_NAME=moodle
MOODLE_DB_USER=moodle
MOODLE_DB_PASSWORD=moodle_password

MOODLE_URL=https://redestel.fpvirtualaragon.es
VIRTUAL_HOST=redestel.fpvirtualaragon.es
SSL_EMAIL=juandacorreo@gmail.com

MOODLE_ADMIN_USER=admin
MOODLE_ADMIN_PASSWORD=AeducAR#2020
MOODLE_ADMIN_EMAIL=pruizs@campusdigitalfp.com

INSTALL_TYPE=new-install
VERSION=4.1.19
```

### 5.4. Verificaciones post-arranque

Una vez que el contenedor esté estable (`php-fpm` corriendo sin errores en los logs):

1. Acceder a `https://<VIRTUAL_HOST>/login/index.php`.
2. Verificar que el tema Moove se carga correctamente.
3. Verificar que el idioma es español.
4. Revisar que los plugins estén instalados: `Administración del sitio > Plugins > Resumen de plugins`.
5. Verificar que existen las categorías y cursos FPD.

---

## 6. Trabajo pendiente y riesgos conocidos

### 6.1. Plugins: compatibilidad de ramas git

Algunos plugins se clonan desde `main`/`master` en lugar de una rama explícita compatible con Moodle 4.1. **Riesgo**: Si el repositorio del plugin actualiza a una versión incompatible (p. ej. para Moodle 4.2+), el build podría incluir código roto.

**Mitigación**: En el `Dockerfile`, fijar `--branch MOODLE_401_STABLE` o un tag/commit específico para cada plugin.

### 6.2. Plugin `local_educaaragon`

Este plugin no se clona desde un repositorio público conocido. Es posible que sea interno de la organización. Si no está disponible públicamente, el build fallará al intentar clonarlo.

**Mitigación**: Verificar si existe un repositorio interno de Aragón. Si no, se puede omitir del `Dockerfile` y copiar manualmente como archivo `.zip` o directorio.

### 6.3. Scripts custom: credenciales hardcodeadas

Los archivos `custom/soporte/secret.php` y posiblemente `custom/private-reports/` contienen credenciales o configuraciones específicas del entorno anterior.

**Mitigación**: Auditar estos scripts y parametrizar valores sensibles mediante variables de entorno.

### 6.4. Tiempo de build

Clonar ~20 repositorios git durante el build aumenta significativamente el tiempo de construcción de la imagen (puede tardar 5-15 minutos dependiendo de la conexión).

**Mitigación futura**: Usar un stage intermedio en el Dockerfile para cachear la descarga de plugins, o empaquetar plugins como archivos `.zip`/`.tar` dentro del repositorio.

### 6.5. `moodle-data` inicial

Aunque el `moodle-data` se genera automáticamente, algunos recursos (como archivos subidos a cursos, backups `.mbz`, o imágenes de perfil de usuarios existentes) **no se pueden regenerar** desde cero. Esta rama está pensada para **nuevas instalaciones**; para migraciones con datos de usuario, seguirá siendo necesario importar `moodle-data`.

---

## 7. Decisiones de diseño

| Decisión | Justificación |
|----------|---------------|
| Descargar Moodle desde GitHub en lugar de `git clone` | Más rápido (no descarga historial completo) y reproducible (tag fijo). |
| Usar `git clone --depth 1` para plugins | Reduce tiempo de build y tamaño de imagen. |
| Copiar `custom/` en lugar de dejarlo en `moodle-code` | Separa claramente lo que es "core de Moodle + plugins" de lo que es "aplicaciones propias de FPD". |
| `moodle-data` vuelve a ser local (`./moodle-data`) | Coherencia con el objetivo de la rama: generar datos propios, no compartidos. |
| `moosh lang-install es` en `moodle.sh` | El idioma español no viene en Moodle core; debe instalarse explícitamente. |

---

## 8. Relación con otros documentos

| Documento | Rol |
|-----------|-----|
| `AGENTS.md` | Guía general del proyecto, convenciones y stack tecnológico. |
| `Analisis-sistema.md` | Estado actual del sistema tras la migración de abril 2026. |
| `Estudio-moodle-code-to-container.md` | Análisis detallado de plugins y estrategia de refactorización a imagen autocontenida. |
| `UPGRADE.md` | Guía para actualizar Moodle (relevante cuando se pase de 4.1.19 a versiones posteriores). |
| `README.md` | Documentación general para usuarios humanos. |

---

## 9. Contacto y mantenimiento

- Si se detecta que un plugin no clona o no es compatible, actualizar la URL/rama en el `Dockerfile`.
- Si se añaden nuevos plugins a la instancia, incluirlos tanto en el `Dockerfile` (clone) como en `init-scripts/new-install/plugins.sh` (configuración).
- Antes de mergear esta rama a `main`, probar una instalación limpia completa (`new-install` + BD vacía) y un upgrade (`upgrade` + BD poblada).
