# Análisis: Merge de cambios de plugins hacia `moodle-docker-deploy` (rama `dev/fpvirtualaragon`)

> Estudio de viabilidad para llevar el procedimiento automatizado de carga de plugins del proyecto `Moodle-Docker` (rama `preprod/plugins-initdata` / `apache-moodle`) al proyecto `moodle-docker-deploy` (rama `dev/fpvirtualaragon`, plantilla `template-fpm-4.5.7-fpvirtualaragon`).

---

## 1. Resumen ejecutivo

**No es viable un merge directo** de los cambios de `Moodle-Docker` a `moodle-docker-deploy` porque las arquitecturas son fundamentalmente diferentes:

| Aspecto | `Moodle-Docker` (origen) | `moodle-docker-deploy` (destino) |
|---------|--------------------------|----------------------------------|
| **Imagen** | Se construye localmente (`Dockerfile` propio) | Imagen preconstruida (`cateduac/moodle:4.5.7-nginx-fpm-unoconv`) |
| **Código Moodle** | Descargado en build-time desde GitHub | Montado desde `moodle-code/` del host |
| **Plugins** | Clonados en build-time desde `plugins.json` | Ya incluidos en `moodle-code/` o imagen base; solo se configuran en runtime |
| **Instalación plugins** | `moosh plugin-install` + `plugins.json` | `moosh plugin-install` con lista hardcodeada en `plugins.sh` |
| **Init scripts** | `/init-scripts` dentro del contexto de build | `template-fpm-4.5.7-fpvirtualaragon/init-scripts` copiados a cada instancia |
| **Stack web** | Mixto: `main` usa nginx+fpm; `apache-moodle` usa Apache | nginx + php-fpm |
| **Gestión de instancias** | Un solo `docker-compose.yml` | Generador de instancias (`createMoodle.sh`, `upgradeMoodle.sh`) |

**Conclusión:** el concepto de catálogo `plugins.json` y la configuración automática de `local_educaaragon` **sí son trasladables**, pero requieren una **adaptación manual** al modelo de plantillas de `moodle-docker-deploy`, no un merge automático.

---

## 2. Arquitectura del destino (`moodle-docker-deploy`)

### 2.1 Repositorio y rama analizada

```text
Rama: dev/fpvirtualaragon
Commit: 0762796 feat: rama dev/fpvirtualaragon con cambios actuales del proyecto
```

### 2.2 Estructura de plantillas

El repositorio contiene múltiples plantillas históricas:

```text
template/                              -> symlink a template-fpm-4.5.7-unoconv
template-apache-3.7.6/
template-fpm-4.1.6-unoconv/
template-fpm-4.2.1-unoconv/
template-fpm-4.5.7-unoconv/
template-fpm-4.5.7-fpvirtualaragon/    <- Plantilla relevante para FPD
```

La plantilla `template-fpm-4.5.7-fpvirtualaragon` es la que contiene los scripts de inicialización para FP Virtual Aragón.

### 2.3 Imagen Docker

```yaml
# template-fpm-4.5.7-fpvirtualaragon/docker-compose.yml
moodle:
  image: cateduac/moodle:4.5.7-nginx-fpm-unoconv
```

- No hay `Dockerfile` en el repositorio.
- La imagen `cateduac/moodle` ya contiene Moodle core, plugins y herramientas (`moosh`, `expect`).
- El código fuente se monta desde `./moodle-code:/var/www/html`.

### 2.4 Flujo de creación de instancias

`createMoodle.sh`:

1. Lee `.env` raíz.
2. Crea base de datos y usuario MySQL.
3. Copia `template/*` al directorio de la instancia (`${VIRTUALHOST}/`).
4. Genera `.env` del sitio.
5. Crea y monta directorios de repositorios (`moodle-data/repository/...`).
6. Ejecuta `docker compose up -d`.

> **No copia `moodle-code`**. Se asume que el directorio `moodle-code/` existe previamente en la instancia o se regenera durante el upgrade.

### 2.5 Init scripts en la plantilla FPD

```text
template-fpm-4.5.7-fpvirtualaragon/init-scripts/
├── init.sh
├── mbzs/
├── new-install/
│   ├── import_CEE_categories_and_courses copy.sh
│   ├── import_CEIP_categories_and_courses.sh
│   ├── import_CPEPA_categories_and_courses.sh
│   ├── import_CPI_categories_and_courses.sh
│   ├── import_FPD_categories_and_courses.sh
│   ├── import_IES_categories_and_courses.sh
│   ├── import_VACIO_categories_and_courses.sh
│   ├── moodle.sh
│   ├── plugins.sh
│   └── theme.sh
├── themes/
└── upgrade/
    ├── moodle.sh
    ├── plugins.sh
    └── theme.sh
```

### 2.6 Gestión actual de plugins

El archivo `template-fpm-4.5.7-fpvirtualaragon/init-scripts/new-install/plugins.sh`:

- Tiene una lista **hardcodeada** de plugins en un array `PLUGINS=(...)`.
- Usa `moosh plugin-list` y `moosh plugin-install -d`.
- Distingue entre `SCHOOL_TYPE=FPD` y otros tipos de centro.
- No hay `plugins.json`, `docker-clone-plugins.sh` ni `plugins-lib.sh`.

Ejemplo de lista FPD:

```bash
PLUGINS=( 
    "theme_moove"
    "format_tiles"
    "block_xp"
    "availability_xp"
    "block_configurable_reports"
    "report_coursestats_v2"
    "quizaccess_onesession"
    "mod_choicegroup"
    "mod_board"
    "local_mail"
    "mod_pdfannotator"
    "block_grade_me"
    "block_completion_progress"
    "atto_fontsize"
    "atto_fontfamily"
    "atto_fullscreen"
    "qtype_gapfill"
    "mod_attendance"
    "mod_checklist"
    "mod_checklist"
)
```

> No incluye `local_educaaragon` ni `mod_googlemeet`.

---

## 3. Diferencias críticas que impiden un merge directo

### 3.1 No hay build-time de plugins en el destino

En `Moodle-Docker`, `docker-clone-plugins.sh` clona plugins durante el build de la imagen. En `moodle-docker-deploy`:

- No hay `Dockerfile`.
- No se construye imagen.
- Los plugins ya deben existir en `moodle-code/` o en la imagen `cateduac/moodle`.

**Impacto:** `plugins.json` + `docker-clone-plugins.sh` no tienen dónde ejecutarse en el flujo de `moodle-docker-deploy`.

### 3.2 `init-scripts` vive dentro de la plantilla

En `Moodle-Docker`, `init-scripts` está en la raíz y se copia a `/init-scripts` en la imagen. En `moodle-docker-deploy`:

- `init-scripts` está en `template-fpm-4.5.7-fpvirtualaragon/init-scripts/`.
- Se copia a cada instancia mediante `createMoodle.sh`.
- Las rutas dentro de los scripts son relativas a `/init-scripts` en el contenedor (por el bind mount).

**Impacto:** cualquier script nuevo como `educaaragon_setup.php` debe colocarse en `template-fpm-4.5.7-fpvirtualaragon/init-scripts/new-install/`, no en `/init-scripts/new-install/` (aunque dentro del contenedor sí esté en `/init-scripts`).

### 3.3 `init-data` no existe en `moodle-docker-deploy`

En `Moodle-Docker` (rama `preprod/plugins-initdata`) el catálogo `plugins.json` vive en `init-data/plugins.json` y se monta en runtime. En `moodle-docker-deploy`:

- No existe directorio `init-data`.
- El equivalente funcional son los propios `init-scripts` copiados a cada instancia.
- `createMoodle.sh` sí copia `template/*` a la instancia, por lo que podría incluirse un `plugins.json` dentro de `template-fpm-4.5.7-fpvirtualaragon/init-scripts/` o en la raíz de la plantilla.

### 3.4 `recursos-editables` no está montado

En `Moodle-Docker`, `EDUCAARAGON_RESOURCES_PATH` monta `recursos-editables` en `/var/www/moodledata/repository/recursos-editables`. En `moodle-docker-deploy`:

- `createMoodle.sh` crea y monta repositorios para FPD:
  - `ftp_ministerio`
  - `ftp_ministerio_htmls`
  - `mbzs_curso_anterior`
- No monta `recursos-editables`.

**Impacto:** para que `local_educaaragon` funcione, habría que añadir el montaje de `recursos-editables` en `createMoodle.sh` y en `docker-compose.yml`.

### 3.5 Versiones de Moodle/PHP y moosh

| | Moodle-Docker | moodle-docker-deploy |
|---|---|---|
| Moodle | 4.5.11 | 4.5.7 (según imagen) |
| PHP | 8.2 | depende de imagen cateduac/moodle |
| moosh | 1.x vía composer | incluido en imagen |

**Impacto:**
- Algunos plugins pueden tener comportamientos diferentes entre Moodle 4.5.7 y 4.5.11.
- La salida de `moosh` difiere entre versiones (el propio README de `moodle-docker-deploy` documenta cambios en la captura de IDs).

### 3.6 Variables de entorno diferentes

`moodle-docker-deploy` usa `VERSION` (versión de Moodle de la imagen) y `SCHOOL_TYPE`, mientras que `Moodle-Docker` usa `MOODLE_VERSION`.

En `plugins.sh` de destino:

```bash
VERSION_MINOR=$(echo ${VERSION} | cut -d. -f1,2)
```

En `plugins.sh` de origen:

```bash
VERSION_MINOR=$(echo ${MOODLE_VERSION} | cut -d. -f1,2)
```

**Impacto:** los scripts de origen no funcionarían directamente en destino sin adaptar variables.

### 3.7 Gestión de categorías/cursos diferente

`moodle-docker-deploy` tiene múltiples scripts `import_<TIPO>_categories_and_courses.sh` según el tipo de centro. `Moodle-Docker` tiene un único `import_FPVirtual_categories_and_courses.sh`.

**Impacto:** los cambios específicos de FPD no deben afectar a los otros tipos de centro (CEIP, CPI, IES, CPEPA).

---

## 4. Qué sí se podría adaptar

A pesar de las diferencias, hay elementos valiosos que se podrían incorporar:

### 4.1 Configuración automática de `local_educaaragon`

El script `educaaragon_setup.php` y el caso en `plugins.sh` son **directamente aplicables** si:

1. Se incluye `educaaragon_setup.php` en `template-fpm-4.5.7-fpvirtualaragon/init-scripts/new-install/`.
2. Se añade el caso `local_educaaragon` en `plugins.sh`.
3. Se añade `local_educaaragon` al array `PLUGINS` (para FPD).
4. Se monta el directorio `recursos-editables` en `docker-compose.yml` y en `createMoodle.sh`.
5. Se añade `EDUCAARAGON_RESOURCES_PATH` a `.env` y a `createMoodle.sh`.

### 4.2 Corrección de `mod_googlemeet`

Si `moodle-docker-deploy` incluye `mod_googlemeet` en su `moodle-code`, la corrección de la rama en `plugins.json` no aplica (no hay catálogo). Pero si el plugin se instala vía `moosh plugin-install`, habría que:

- Añadirlo al array `PLUGINS` de FPD.
- Añadir su configuración post-instalación en `actions_asociated_to_plugin()`.

### 4.3 Sistema de catálogo `plugins.json`

Se podría introducir un catálogo ligero dentro de la plantilla FPD, pero con alcance limitado:

- No para clonar plugins en build-time (no hay build).
- Sí para centralizar la lista de plugins a instalar/configurar en runtime.
- Reemplazar el array hardcodeado de `plugins.sh` por una lectura de `plugins.json`.

Esto requiere:
- Añadir `jq` a la imagen `cateduac/moodle` (o usar `python3` como en `plugins-lib.sh`).
- Adaptar `plugins-lib.sh` para leer desde la ruta de la plantilla.
- Modificar `plugins.sh` para iterar sobre `plugins.json` en lugar del array hardcodeado.

---

## 5. Problemas específicos que podrían darse

### 5.1 Imagen `cateduac/moodle` no tiene `jq` ni `python3`

`plugins-lib.sh` de origen usa `python3` para leer JSON. `docker-clone-plugins.sh` usa `jq`. Si la imagen destino no incluye estas herramientas, fallarán los scripts.

**Mitigación:** verificar la imagen o reescribir `plugins-lib.sh` para usar herramientas disponibles.

### 5.2 `moosh plugin-install` instala desde moodle.org, no desde Git

En `moodle-docker-deploy`, `moosh plugin-install -d ${PLUGIN}` descarga el plugin desde el repositorio de Moodle. En `Moodle-Docker`, los plugins se clonan desde Git en build-time y luego se registran/instalan.

**Impacto:** plugins como `local_educaaragon` (repositorio privado de FPVirtual) no están en moodle.org, por lo que `moosh plugin-install` fallará. Deben estar ya presentes en `moodle-code/`.

### 5.3 `local_educaaragon` debe estar en `moodle-code`

Si la imagen `cateduac/moodle:4.5.7-nginx-fpm-unoconv` no incluye `local_educaaragon`, el script `educaaragon_setup.php` fallará al cargar la librería del plugin.

**Mitigación:** asegurar que `local_educaaragon` esté en `moodle-code` antes de ejecutar `plugins.sh`.

### 5.4 Montajes de repositorios en `createMoodle.sh`

`createMoodle.sh` monta repositorios con `mount -o bind`. Añadir `recursos-editables` requiere:

1. Crear el directorio en `moodle-data/repository/recursos-editables`.
2. Montar el origen real (¿`/var/moodle-docker-deploy/zz_recursos_editables`?).
3. Asegurar permisos `www-data:www-data`.

Si el origen de los recursos editables no está estandarizado, el montaje fallará.

### 5.5 Actualizaciones y upgrades

`updateMoodle.sh` y `upgradeMoodle.sh` sincronizan `template-fpm-4.5.7-fpvirtualaragon/` sobre la instancia. Si se añaden archivos nuevos a la plantilla, se copiarán automáticamente. Pero:

- Si se añade `plugins.json` a la plantilla, las instancias existentes no lo tendrán hasta el próximo update/upgrade.
- Los cambios en `plugins.sh` afectan a nuevas instalaciones y upgrades, no a instancias ya creadas (a menos que se haga update).

### 5.6 Diferencias en `plugins.sh` entre `new-install` y `upgrade`

En `moodle-docker-deploy` hay scripts separados:
- `new-install/plugins.sh`
- `upgrade/plugins.sh`

Si se adapta `new-install/plugins.sh`, probablemente haya que adaptar también `upgrade/plugins.sh` para mantener consistencia.

### 5.7 Variables de entorno faltantes

`Moodle-Docker` usa variables como `MOODLE_DB_USER`, `MOODLE_DB_PASSWORD`, `MOODLE_VERSION`. `moodle-docker-deploy` usa `MOODLE_MYSQL_USER`, `MOODLE_MYSQL_PASSWORD`, `VERSION`.

`educaaragon_setup.php` no depende de estas variables, pero `plugins.sh` sí usa `MOODLE_VERSION`/`VERSION` y `block_configurable_reports` usa credenciales de DB.

---

## 6. Estrategias de integración posibles

### Opción A: Adaptación mínima (recomendada)

Solo incorporar `local_educaaragon` y la corrección de `mod_googlemeet` (si aplica) a la plantilla FPD existente.

Pasos:
1. Copiar `educaaragon_setup.php` a `template-fpm-4.5.7-fpvirtualaragon/init-scripts/new-install/`.
2. Añadir caso `local_educaaragon` en `new-install/plugins.sh`.
3. Añadir `local_educaaragon` al array `PLUGINS` de FPD.
4. Añadir montaje de `recursos-editables` en `docker-compose.yml` y en `createMoodle.sh`.
5. Añadir `EDUCAARAGON_RESOURCES_PATH` a `.env` y a `createMoodle.sh`.
6. Si se quiere `mod_googlemeet`, añadirlo al array y a `actions_asociated_to_plugin()`.
7. Hacer lo mismo en `upgrade/plugins.sh` si es necesario.

**Ventaja:** mínimo impacto, aprovecha la arquitectura existente.
**Inconveniente:** no se centraliza el catálogo de plugins.

### Opción B: Introducir catálogo `plugins.json` en la plantilla

Reemplazar el array hardcodeado de `plugins.sh` por un catálogo `plugins.json` dentro de la plantilla.

Pasos:
1. Crear `template-fpm-4.5.7-fpvirtualaragon/init-scripts/plugins.json`.
2. Adaptar `plugins-lib.sh` para leer desde `/init-scripts/plugins.json`.
3. Modificar `plugins.sh` para usar `plugins_list_enabled`.
4. Asegurar que `jq` o `python3` estén disponibles en la imagen.

**Ventaja:** consistencia con `Moodle-Docker`, single source of truth.
**Inconveniente:** requiere cambios en la imagen base y en todos los scripts de plugins (`new-install` y `upgrade`).

### Opción C: Migración completa al modelo de Moodle-Docker

Reemplazar el uso de imagen `cateduac/moodle` por un `Dockerfile` propio que construya Moodle desde GitHub y clone plugins desde `plugins.json`.

Pasos:
1. Añadir `Dockerfile` a `template-fpm-4.5.7-fpvirtualaragon/` o a la raíz.
2. Adaptar `docker-compose.yml` para hacer build en lugar de usar imagen preconstruida.
3. Añadir `plugins.json`, `docker-clone-plugins.sh`, `plugins-lib.sh`.
4. Eliminar dependencia de `moodle-code/`.

**Ventaja:** máxima flexibilidad, reproducibilidad.
**Inconveniente:** cambio arquitectónico grande, afecta a todos los scripts de orquestación (`createMoodle.sh`, `upgradeMoodle.sh`, etc.), requiere muchas pruebas.

---

## 7. Recomendación final

**Recomendación: Opción A (adaptación mínima).**

Motivos:
- `moodle-docker-deploy` es un sistema de despliegue multi-instancia estable que no debería cambiar su arquitectura base sin una razón muy fuerte.
- La imagen `cateduac/moodle` ya gestiona el código de Moodle y plugins; no es necesario replicar el build de `Moodle-Docker`.
- El valor real de los cambios de `Moodle-Docker` para `moodle-docker-deploy` se concentra en:
  1. La configuración automática de `local_educaaragon`.
  2. Posiblemente la corrección de `mod_googlemeet`.
- La Opción A permite testear en preproducción con cambios controlados y reversibles.

Si a largo plazo se quiere unificar la gestión de plugins, la **Opción B** es un paso intermedio razonable. La **Opción C** solo se justifica si se decide abandonar la imagen `cateduac/moodle` y construir imágenes propias.

---

## 8. Checklist para Opción A

- [ ] Confirmar que `local_educaaragon` está presente en `moodle-code` de la imagen `cateduac/moodle:4.5.7-nginx-fpm-unoconv`.
- [ ] Copiar `educaaragon_setup.php` a `template-fpm-4.5.7-fpvirtualaragon/init-scripts/new-install/`.
- [ ] Añadir caso `local_educaaragon` en `new-install/plugins.sh`.
- [ ] Añadir `local_educaaragon` al array `PLUGINS` para `SCHOOL_TYPE=FPD`.
- [ ] Añadir `EDUCAARAGON_RESOURCES_PATH` a `.env` generado por `createMoodle.sh`.
- [ ] Crear y montar `moodle-data/repository/recursos-editables` en `createMoodle.sh`.
- [ ] Añadir volumen `recursos-editables` en `template-fpm-4.5.7-fpvirtualaragon/docker-compose.yml`.
- [ ] Aplicar los mismos cambios en `upgrade/plugins.sh` si se requiere.
- [ ] Testear en una instancia FPD de preproducción.
