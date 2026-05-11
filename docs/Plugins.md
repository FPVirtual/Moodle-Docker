# Inventario y estado de plugins — Moodle FPD

> Fecha de elaboración: 2026-05-11
> Moodle base: 4.1.x (php:8.1-fpm)
> Objetivo: Documentar todos los plugins de terceros que utiliza el proyecto, su origen, estado de mantenimiento y riesgo para futuros upgrades.

---

## 1. Resumen ejecutivo

| Estado | Cantidad | Significado |
|--------|----------|-------------|
| ✅ Activo / Con soporte | 14 | Plugin con releases recientes (< 1 año) y mantenedor responsive. |
| ⚠️ Poco activo / En riesgo | 7 | Última release > 1 año, mantenedor incierto o transición tecnológica pendiente. |
| 🔴 Obsoleto / Deprecado | 3 | Sin soporte oficial, riesgo alto de incompatibilidad en upgrades. |

> **Recomendación prioritaria**: Revisar `block_configurable_reports`, `report_coursestats` y `mod_googlemeet` antes de cualquier upgrade a Moodle 4.2+.

---

## 2. Plugins instalados vía scripts (`init-scripts/`)

Estos plugins aparecen en los arrays de `init-scripts/new-install/plugins.sh` y `init-scripts/upgrade/plugins.sh`.

### 2.1. Temas y formato de curso

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `theme_moove` | Tema | Willian Mano | ✅ Activo | ~2 semanas (nov 2025) | 25.733 | Compatible Moodle 5.x. Tiene versión premium. Principal tema del proyecto. |
| `format_tiles` | Formato curso | David Watson | ✅ Activo | ~6 días (ene 2026) | 20.657 | Muy mantenido. Compatible hasta Moodle 5.x. |

### 2.2. Gamificación y XP

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `block_xp` | Bloque | Frédéric Massart (FMCorz) | ✅ Activo | Oct 2025 | 30.000+ | Plugin de gamificación más popular de Moodle. Compatible 5.1. |
| `availability_xp` | Condición disponibilidad | Frédéric Massart (FMCorz) | ✅ Activo | ~4 meses | 2.275 | Requiere `block_xp`. Mantiene mismo ritmo de actualización. |

### 2.3. Comunicación y mensajería

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `local_mail` | Local | Albert Gasset, Marc Català | ✅ Activo | May 2025 | — | Webmail-like messaging. Release reciente en moodle.org. |

### 2.4. Informes y estadísticas

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `block_configurable_reports` | Bloque | Juan Leyva / Lesterhuis | 🔴 Deprecado | ~14 meses (abr 2024) | 15.289 | Moodle HQ discontinuó soporte en 2021. Open LMS anunció fin de soporte julio 2026. **Riesgo de seguridad y compatibilidad.** |
| `report_coursestats` | Informe | Paulo Júnior (UFLA) | 🔴 Obsoleto | 2020 (v3.0) | — | Sin actualizaciones desde 2020. Funcionalidad limitada. Evaluar reemplazo por reportes custom o `ad_hoc_database_queries`. |

### 2.5. Cuestionarios y evaluación

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `quizaccess_onesession` | Regla acceso cuestionario | — | ⚠️ En riesgo | Desconocida | — | Plugin simple (bloquea sesiones concurrentes). No hay información clara de mantenedor ni releases recientes en moodle.org. Funciona pero sin soporte garantizado. |
| `qtype_gapfill` | Tipo pregunta | Marcus Green | ✅ Activo | Abr 2026 (v2.31) | 4.258 | Compatible Moodle 5.2. Desarrollo muy activo. |

### 2.6. Actividades (mod)

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `mod_choicegroup` | Actividad | Nicolas Dunand | ✅ Activo | ~9 meses | 7.785 | Estable, mantenimiento regular. |
| `mod_board` | Actividad | Brickfield Education Labs / Mike Churchward | ✅ Activo | ~2 meses | 3.843 | Compatible hasta Moodle 5.0. Actividad tipo "post-it board". |
| `mod_pdfannotator` | Actividad | RWTH Aachen (rwthmoodle) | ✅ Activo | Feb 2026 | — | Desarrollo activo en GitHub de la universidad alemana. |
| `mod_attendance` | Actividad | Dan Marsden | ✅ Activo | Abr 2026 (3 semanas) | 21.131 | Compatible Moodle 5.1. Desarrollo muy activo. |
| `mod_checklist` | Actividad | Davo Smith | ✅ Activo | Abr 2026 (8 semanas) | 8.140 | Compatible Moodle 5.2. Muy activo. |

### 2.7. Bloques

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `block_grade_me` | Bloque | RemoteLearner | ⚠️ En riesgo | ~11-18 meses | 3.552 | Hay issues abiertos en GitHub preguntando si sigue mantenido. Última actividad incierta. |
| `block_completion_progress` | Bloque | Michael / Jonathan de Raadt | ✅ Activo | Oct 2025 | — | Reemplazo oficial del antiguo `block_progress`. Mantenimiento regular. |

### 2.8. Editor Atto

| Plugin | Tipo | Mantenedor | Estado | Última release | Sitios | Observaciones |
|--------|------|------------|--------|----------------|--------|---------------|
| `atto_fontsize` | Editor Atto | Andrew Nicols | ⚠️ Poco activo | ~2 años | 4.814 | Funcionalidad básica. Poco riesgo pero sin evolución. |
| `atto_fontfamily` | Editor Atto | — (projectestac fork) | ⚠️ Poco activo | ~15-16 meses | 4.605 | Similar a fontsize. Estable pero sin novedades. |
| `atto_fullscreen` | Editor Atto | Daniel Thies | ✅ Activo | Abr 2025 | — | Mantenimiento regular. |

> **Nota sobre Atto vs TinyMCE**: Moodle está migrando progresivamente de Atto a TinyMCE como editor por defecto. Los plugins de Atto (`atto_*`) podrían requerir reemplazo por equivalentes `tiny_*` en upgrades mayores (4.2+).

---

## 3. Plugins detectados en `moodle-code` pero NO en scripts de instalación

Estos plugins están presentes en el código copiado del contenedor anterior pero **no figuran en los arrays `PLUGINS` de `new-install/plugins.sh` ni `upgrade/plugins.sh`.

| Plugin | Tipo | ¿En scripts? | Mantenedor | Estado | Última release | Observaciones |
|--------|------|--------------|------------|--------|----------------|---------------|
| `mod_googlemeet` | Actividad | ❌ No | Rone Santos | 🔴 Obsoleto | ~2 años (2023) | Solo 1 versión disponible. Requiere OAuth 2 de Google. Alto riesgo de obsolescencia. |
| `block_sharing_cart` | Bloque | ❌ No | donhinkelman / Catalyst | ✅ Activo | Sept 2025 (v5.0 r6) | Refactorización total en 2024-2025. Muy útil para copiar contenido entre cursos. **Se recomienda añadir a los scripts.** |
| `local_educaaragon` | Local | ❌ No | Interno Aragón | ⚠️ Desconocido | — | Plugin interno. No disponible en moodle.org. Origen y mantenimiento desconocidos. |
| `local_reminders` | Local | ❌ No | Isuru Madushanka | ✅ Activo | Ago 2025 (v2.7.4) | Compatible Moodle 5. Envía recordatorios por email de eventos de calendario. **Se recomienda añadir a los scripts.** |
| `atto_c4l` | Editor Atto | ❌ No | Roger Segú / IOC | ⚠️ Poco activo | ~16 meses | Componentes visuales para Atto. Existe versión para TinyMCE (`tiny_c4l`) más reciente. |

---

## 4. Plugins referenciados en `actions_asociated_to_plugin` pero no instalados

El script `new-install/plugins.sh` contiene configuración para estos plugins pero **no están en el array `PLUGINS`**:

| Plugin | Tipo | Estado | Observaciones |
|--------|------|--------|---------------|
| `mod_jitsi` | Actividad | ✅ Activo | Mantenido por Sergio Comerón. Muy activo (abr 2026). Compatible Moodle 5.x. Tiene configuración en `actions_asociated_to_plugin` pero **no se instala automáticamente**. Si se usa, debe añadirse al array `PLUGINS`. |

---

## 5. Riesgos y recomendaciones por upgrade

### 5.1. Upgrade Moodle 4.1 → 4.2 (o superior)

| Plugin | Riesgo | Acción recomendada |
|--------|--------|-------------------|
| `block_configurable_reports` | 🔴 Alto | Buscar alternativa antes de julio 2026. Opciones: `report_customsql`, `tool_reportbuilder` (core 4.0+), o informes propios. |
| `report_coursestats` | 🔴 Alto | Reemplazar por consultas SQL propias o desactivar. Sin soporte desde 2020. |
| `mod_googlemeet` | 🔴 Alto | Evaluar si se usa. Si es necesario, buscar alternativa o mantener versión congelada. Google cambia frecuentemente sus APIs. |
| `quizaccess_onesession` | 🟡 Medio | Verificar compatibilidad con la nueva versión de Moodle antes del upgrade. Es un plugin simple, probablemente funcione, pero sin garantía. |
| `atto_fontsize`, `atto_fontfamily`, `atto_c4l` | 🟡 Medio | Evaluar migración a equivalentes TinyMCE (`tiny_fontsize`, `tiny_fontfamily`, `tiny_c4l`). |
| `block_grade_me` | 🟡 Medio | Confirmar si RemoteLearner sigue manteniendo el plugin. Si no, buscar fork comunitario o alternativa. |
| `local_educaaragon` | 🟡 Medio | Auditar código interno. Verificar compatibilidad con la nueva versión de Moodle antes del upgrade. |
| `block_sharing_cart` | 🟢 Bajo | Añadir a los scripts de instalación. Plugin muy activo y útil. |
| `local_reminders` | 🟢 Bajo | Añadir a los scripts de instalación. Plugin activo y compatible. |

### 5.2. Plugins críticos para FPD

Los siguientes plugins son **esenciales** para el funcionamiento del sitio FPD y deben probarse exhaustivamente en staging antes de cualquier upgrade:

- `theme_moove` — Tema principal con personalizaciones FPD.
- `format_tiles` — Formato de curso usado masivamente.
- `local_mail` — Sistema de mensajería interna.
- `mod_board` — Actividad colaborativa tipo pizarra.
- `mod_attendance` — Control de asistencia.
- `mod_checklist` — Listas de tareas.
- `block_completion_progress` — Seguimiento de progreso visual.

---

## 6. Fuentes y enlaces de referencia

- Moodle Plugins Directory: https://moodle.org/plugins
- Repositorios GitHub mencionados en `Estudio-moodle-code-to-container.md`
- Foros de Moodle en inglés y comunidades de mantenedores
- Open LMS Plugin Matrix y anuncios de fin de soporte (Configurable Reports)

---

## 7. Historial de cambios

| Fecha | Autor | Cambio |
|-------|-------|--------|
| 2026-05-11 | Kimi Code CLI | Creación inicial del inventario a partir de revisión de scripts y búsqueda en moodle.org |
