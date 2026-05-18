# Auditoría de plugins para Moodle 4.5.x

> Fecha: 2026-05-18  
> Moodle destino: 4.5.11 (php:8.2-apache)  
> Objetivo: documentar problemas de compatibilidad detectados al migrar desde la pila anterior y proponer repos/ramas corregidas.

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| Plugins corregidos / actualizados en `plugins.json` | 3 |
| Plugins compatibles sin cambios | 18 |
| Plugins obsoletos / con advertencias | 3 |

---

## Cambios aplicados a `plugins.json`

### 1. `format_tiles` — repo obsoleto, causa fallo de instalación fatal

**Problema detectado**
- Repo anterior: `https://github.com/learnweb/moodle-format_tiles.git` (rama `main`)
- Versión que traía: `2019052114` (Moodle 3.9 RC)
- Error: `Class "format_base" not found` durante `install_database.php` y posteriormente en cada llamada a Moosh que crea cursos.
- Causa: Moodle 4.5 refactorizó por completo el subsistema de formatos de curso. El plugin de Moodle 3.9 no carga la clase base ni es registrable por el componente installer.

**Solución aplicada**
- Nuevo repo: `https://github.com/TechnologyEnhancedLearning/moodle-format_tiles.git` (rama `main`)
- Versión confirmada: `2026012200` — release `4.5.0.27`, requires `2024100100` (Moodle 4.5)
- `supported = [405, 405]`

### 2. `report_coursestats_v2` — path de instalación incorrecto

**Problema detectado**
- En `plugins.json` estaba declarado como:
  - `name`: `report_coursestats`
  - `component`: `report_coursestats`
  - `moodle_path`: `report/coursestats`
- El repositorio clona el código de `moodle-report_coursestats_v2.git`, cuyo `version.php` declara `$plugin->component = 'report_coursestats_v2'`.
- Moodle detectaba el componente `report_coursestats_v2` en la ruta `report/coursestats` y abortaba la instalación con:
  > "La extensión report_coursestats_v2 está instalada en la ubicación incorrecta ... la ubicación prevista es report/coursestats_v2"

**Solución aplicada**
- Corregidos `name`, `component` y `moodle_path` a valores con sufijo `_v2`:
  - `name`: `report_coursestats_v2`
  - `component`: `report_coursestats_v2`
  - `moodle_path`: `report/coursestats_v2`

**Advertencias persisten**
- Durante la instalación sigue emitiendo:
  - `Invalid get_string() identifier: 'sortcategoriesbyname'`
  - `Duplicate admin page name: report_coursestats_v2`
- Estos son defectos del propio plugin (sin actualizaciones desde 2020). No impiden la instalación pero ensucian los logs.
- **Recomendación**: mantener `default_enabled: false` y no activar en producción a menos que se forkée y repare.

### 3. `local_mail` — repo abandonado

**Problema detectado**
- Repo anterior: `https://github.com/IOC/moodle-local_mail.git` (rama `master`)
- Último commit: 2019-03-22
- Versión: `2017121404`, requires `2015111600` (Moodle 3.0)
- Riesgo: en Moodle 4.5 pueden fallar las APIs de privacidad, messaging y filestorage que usa este plugin.

**Solución aplicada**
- Nuevo repo: `https://github.com/uaiblaine/moodle-local_mail.git` (rama `main`)
- Versión confirmada: `2026051500`, requires `2022112800` (Moodle 4.1)
- Commit reciente: mayo 2026

---

## Plugins verificados y compatibles (sin cambios necesarios)

| Plugin | Repo | Rama | Versión | Requires |
|--------|------|------|---------|----------|
| `theme_moove` | willianmano/moodle-theme_moove | MOODLE_405_STABLE | — | — |
| `block_xp` | FMCorz/moodle-block_xp | master | 2026042001 | 4.1 |
| `availability_xp` | FMCorz/moodle-availability_xp | master | 2026042000 | muy bajo |
| `block_configurable_reports` | jleyva/moodle-block_configurablereports | MOODLE_4x_STABLE | 2027050401 | 4.0 |
| `quizaccess_onesession` | vadimonus/moodle-quizaccess_onesession | master | 2024032400 | 4.2 |
| `mod_choicegroup` | ndunand/moodle-mod_choicegroup | master | 2026013100 | 4.3 |
| `mod_board` | brickfield/moodle-mod_board | MOODLE_405_STABLE | — | — |
| `mod_pdfannotator` | rwthmoodle/moodle-mod_pdfannotator | main | 2025121500 | 3.11 |
| `block_grade_me` | remotelearner/Moodle-block_grade_me | MOODLE_405_STABLE | — | — |
| `block_completion_progress` | deraadt/moodle-block_completion_progress | master | 2026042700 | **4.5** |
| `atto_fontsize` | andrewnicols/moodle-atto_fontsize | main | 2023091901 | 2.7 |
| `atto_fontfamily` | projectestac/moodle-atto_fontfamily | master | 2024110400 | 3.5 |
| `atto_fullscreen` | dthies/moodle-atto_fullscreen | master | 2015122021* | 2.7 |
| `qtype_gapfill` | marcusgreen/moodle-qtype_gapfill | main | 2026040300 | **4.5** |
| `mod_attendance` | danmarsden/moodle-mod_attendance | MOODLE_405_STABLE | — | — |
| `mod_checklist` | davosmith/moodle-checklist | master | 2026042400 | 4.1 |
| `mod_jitsi` | SergioComeron/moodle-mod_jitsi | master | 2026051701 | **4.5** |
| `block_sharing_cart` | donhinkelman/moodle-block_sharing_cart | master | 2025092900 | 4.2 |
| `local_reminders` | isuru89/moodle-local_reminders | master | 2025082400 | 3.5 |
| `atto_c4l` | rogersegu/moodle-atto_c4l | main | 2024122900 | 3.8 |

> *Nota: `atto_fullscreen` tiene `version.php` con fecha 2015, pero el repo recibe commits de mantenimiento CI hasta 2026. Funciona en 4.5 porque Atto sigue presente (aunque deprecado).

---

## Problemas adicionales detectados en scripts de inicialización

### `entrypoint.sh` — opción obsoleta de CLI de Moodle

**Problema:** `install_database.php` se invocaba con `--non-interactive`.  
En Moodle 4.5.x esa opción **no existe**; el script muestra `Unrecognised options: --non-interactive` y retorna error, por lo que la BD quedaba vacía y todo el init posterior fallaba.

**Corrección:** eliminar `--non-interactive` de la línea de `install_database.php`.

### `import_FPD_categories_and_courses.sh` — parsing de IDs de Moosh

**Problema:** varios comandos Moosh devuelven texto descriptivo (ej. `"Created category X with id: 7."`) y el script almacenaba la cadena completa en lugar del número.

**Impacto:**
- Las variables de categoría contenían texto en vez de IDs numéricos.
- `moosh course-create --category "Created category ... with id: 7."` fallaba con `invalidrecord` en `course_categories`.

**Corrección:** añadir filtros `grep -oP '\d+' | tail -1` a:
- `moosh category-create`
- `moosh course-create`
- `moosh role-create` (requería `tail -1` porque devuelve un array + ID)

---

## Recomendaciones para producción

1. **Deshabilitar plugins obsoletos**:
   - `report_coursestats_v2` (`default_enabled: false` ya está bien)
   - `block_configurable_reports` (deprecado por Open LMS, retiro julio 2026)
   - `atto_*` (Atto está deprecado; valorar migrar a TinyMCE equivalents)

2. **Validar `format_tiles` en cursos reales**:
   - Aunque el repo `TechnologyEnhancedLearning` indica compatibilidad 4.5, conviene crear un curso de prueba, cambiar al formato "Tiles" y verificar que la navegación por secciones y los iconos funcionan correctamente.

3. **Revisar `local_mail` tras cambio de repo**:
   - El nuevo repo `uaiblaine/moodle-local_mail` no es un fork del original IOC; es una continuación independiente. Verificar que las tablas y la lógica de adjuntos se comportan igual que en la versión anterior usada por FPD.

4. **Actualizar `AGENTS.md` si se modifican convenciones**:
   - Si se adopta la práctica de verificar `$plugin->requires >= 2024100700` antes de añadir un plugin al catálogo, documentar esa regla.

---

## Cómo regenerar la imagen tras cambios en `plugins.json`

```bash
# 1. Limpiar estado previo (si la instalación falló)
docker compose --profile with-db down -v
rm -rf moodle-data/* moodle-data/.*

# 2. Reconstruir imagen (docker-clone-plugins.sh se ejecuta en build)
docker compose --profile with-db up -d --build

# 3. Verificar logs
docker compose logs -f moodle
```

---

## Problema adicional detectado post-instalación (2026-05-18)

### `load_usuarios.sh` — separador de campos incorrecto

**Síntoma:** los usuarios definidos en `usuarios.csv` (`admin2`, `profinspector`, `prof_cd_daw`, `estudiante1..10`) no se creaban durante la instalación. El log mostraba:

```
/init-scripts/new-install/load_usuarios.sh: line 22: : invalid variable name
WARNING: admin2 no encontrado, omitiendo siteadmins
WARNING: prof_cd_daw no encontrado, no se matriculará en cursos cd_daw
```

**Causa:** el script usaba `IFS=','` para leer el CSV, pero `read_csv.php` convierte el CSV a **tabuladores** (`\t`). Esto provocaba que la variable `password_env` quedara vacía y la indirección `${!password_env}` fallara.

**Corrección:** cambiar `IFS=','` por `IFS=$'\t'` en el bucle `while read`.

**Nota:** los usuarios `prof_je_*` (jefaturas de estudios) sí se crearon correctamente porque `import_FPD_categories_and_courses.sh` ya usaba `IFS=$'\t'`.
