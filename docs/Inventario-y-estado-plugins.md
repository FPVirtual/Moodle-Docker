# Inventario y estado de plugins — Moodle FPD

> Fecha de elaboración: 2026-05-15
> Moodle base: 4.5.11 (`php:8.2-apache`)
> Catálogo: `plugins.json` (fuente única de verdad)
> Objetivo: Documentar todos los plugins de terceros, su origen, estado de mantenimiento y riesgo.

---

## 1. Resumen ejecutivo

| Estado | Cantidad | Significado |
|--------|----------|-------------|
| ✅ Activo / Con soporte | 15 | Plugin con releases recientes (< 1 año) y mantenedor responsive. |
| ⚠️ Poco activo / En riesgo | 5 | Última release > 1 año, mantenedor incierto o transición tecnológica pendiente. |
| 🔴 Obsoleto / Deprecado | 3 | Sin soporte oficial, riesgo alto de incompatibilidad en upgrades. |

> **Recomendación prioritaria**: Revisar `block_configurable_reports` (deprecado julio 2026), `report_coursestats` (sin actualizaciones desde 2020) y migrar plugins Atto a TinyMCE en futuros upgrades mayores.

---

## 2. Plugins del catálogo (`plugins.json`)

### 2.1. Temas y formato de curso

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `theme_moove` | Tema | Willian Mano | ✅ Activo | `MOODLE_405_STABLE` | Compatible Moodle 5.x. Tiene versión premium. Principal tema del proyecto. |
| `format_tiles` | Formato curso | David Watson / learnweb | ✅ Activo | `main` | Muy mantenido. Fork `learnweb` activo para versiones recientes. |

### 2.2. Gamificación y XP

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `block_xp` | Bloque | Frédéric Massart (FMCorz) | ✅ Activo | `master` | Plugin de gamificación más popular. Compatible 5.1. |
| `availability_xp` | Condición disponibilidad | Frédéric Massart (FMCorz) | ✅ Activo | `master` | Requiere `block_xp`. Mantiene mismo ritmo. |

### 2.3. Comunicación y mensajería

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `local_mail` | Local | Albert Gasset, Marc Català (IOC) | ✅ Activo | `master` | Webmail-like messaging. Release reciente en moodle.org. |

### 2.4. Informes y estadísticas

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `block_configurable_reports` | Bloque | Juan Leyva / Lesterhuis | 🔴 Deprecado | `MOODLE_4x_STABLE` | Open LMS anunció fin de soporte julio 2026. **Deshabilitado por defecto.** Evaluar `report_customsql` o `tool_reportbuilder` (core 4.0+). |
| `report_coursestats` | Informe | DIRED-UFLA | 🔴 Obsoleto | `main` | Sin actualizaciones desde 2020. Funcionalidad limitada. **Deshabilitado por defecto.** |

### 2.5. Cuestionarios y evaluación

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `quizaccess_onesession` | Regla acceso cuestionario | vadimonus | ⚠️ En riesgo | `master` | Plugin simple (bloquea sesiones concurrentes). Sin info clara de releases recientes. Funciona pero sin soporte garantizado. |
| `qtype_gapfill` | Tipo pregunta | Marcus Green | ✅ Activo | `main` | Compatible Moodle 5.2. Desarrollo muy activo. |

### 2.6. Actividades (mod)

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `mod_choicegroup` | Actividad | Nicolas Dunand | ✅ Activo | `master` | Estable, mantenimiento regular. |
| `mod_board` | Actividad | Brickfield Education Labs | ✅ Activo | `MOODLE_405_STABLE` | Compatible hasta Moodle 5.0. Actividad tipo "post-it board". |
| `mod_pdfannotator` | Actividad | RWTH Aachen | ✅ Activo | `main` | Desarrollo activo en GitHub de la universidad alemana. |
| `mod_attendance` | Actividad | Dan Marsden | ✅ Activo | `MOODLE_405_STABLE` | Compatible Moodle 5.1. Desarrollo muy activo. |
| `mod_checklist` | Actividad | Davo Smith | ✅ Activo | `master` | Compatible Moodle 5.2. Muy activo. |
| `mod_jitsi` | Actividad | Sergio Comerón | ✅ Activo | `master` | Compatible Moodle 5.x. **Deshabilitado por defecto.** Habilitar si se usa Jitsi. |

### 2.7. Bloques

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `block_grade_me` | Bloque | RemoteLearner | ⚠️ En riesgo | `MOODLE_405_STABLE` | Hay issues abiertos en GitHub sobre mantenimiento. Última actividad incierta. |
| `block_completion_progress` | Bloque | Michael / Jonathan de Raadt | ✅ Activo | `master` | Reemplazo oficial del antiguo `block_progress`. Mantenimiento regular. |
| `block_sharing_cart` | Bloque | Don Hinkelman / Catalyst | ✅ Activo | `master` | Refactorización total en 2024-2025. Muy útil. **Deshabilitado por defecto.** |

### 2.8. Editor Atto

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `atto_fontsize` | Editor Atto | Andrew Nicols | ⚠️ Poco activo | `main` | Funcionalidad básica. Poco riesgo pero sin evolución. |
| `atto_fontfamily` | Editor Atto | projectestac | ⚠️ Poco activo | `master` | Estable pero sin novedades. |
| `atto_fullscreen` | Editor Atto | Daniel Thies | ✅ Activo | `master` | Mantenimiento regular. |
| `atto_c4l` | Editor Atto | Roger Segú | ⚠️ Poco activo | `main` | Componentes visuales para Atto. Existe versión para TinyMCE (`tiny_c4l`). **Deshabilitado por defecto.** |

> **Nota sobre Atto vs TinyMCE**: Moodle está migrando progresivamente de Atto a TinyMCE como editor por defecto. Los plugins de Atto (`atto_*`) podrían requerir reemplazo por equivalentes `tiny_*` en upgrades mayores (4.6+).

### 2.9. Local

| Plugin | Tipo | Mantenedor | Estado | Rama git | Observaciones |
|--------|------|------------|--------|----------|---------------|
| `local_reminders` | Local | Isuru Madushanka | ✅ Activo | `master` | Compatible Moodle 5. Envía recordatorios por email. **Deshabilitado por defecto.** |

---

## 3. Plugins eliminados del catálogo

| Plugin | Motivo |
|--------|--------|
| `mod_googlemeet` | Repositorio eliminado de GitHub. Plugin obsoleto. Requiere OAuth 2 de Google. |
| `local_educaaragon` | Plugin interno sin repositorio público conocido. No se incluye en build genérico. |

---

## 4. Riesgos y recomendaciones por upgrade

### 4.1. Upgrade Moodle 4.5 → 4.6+ (futuro)

| Plugin | Riesgo | Acción recomendada |
|--------|--------|-------------------|
| `block_configurable_reports` | 🔴 Alto | Buscar alternativa antes de julio 2026. Opciones: `report_customsql`, `tool_reportbuilder` (core 4.0+). |
| `report_coursestats` | 🔴 Alto | Reemplazar por consultas SQL propias o desactivar. Sin soporte desde 2020. |
| `quizaccess_onesession` | 🟡 Medio | Verificar compatibilidad. Plugin simple, probablemente funcione. |
| `atto_fontsize`, `atto_fontfamily`, `atto_c4l` | 🟡 Medio | Evaluar migración a equivalentes TinyMCE. |
| `block_grade_me` | 🟡 Medio | Confirmar si RemoteLearner sigue manteniendo el plugin. |
| `block_sharing_cart` | 🟢 Bajo | Habilitar si no lo está. Plugin muy activo y útil. |
| `local_reminders` | 🟢 Bajo | Habilitar si se necesita recordatorios. Plugin activo y compatible. |

### 4.2. Plugins críticos para FPD

Los siguientes plugins son **esenciales** para el funcionamiento del sitio FPD y deben probarse exhaustivamente en staging antes de cualquier upgrade:

- `theme_moove` — Tema principal con personalizaciones FPD.
- `format_tiles` — Formato de curso usado masivamente.
- `local_mail` — Sistema de mensajería interna.
- `mod_board` — Actividad colaborativa tipo pizarra.
- `mod_attendance` — Control de asistencia.
- `mod_checklist` — Listas de tareas.
- `block_completion_progress` — Seguimiento de progreso visual.

---

## 5. Verificación de URLs

Las URLs de los repositorios git fueron verificadas con `curl` el 2026-05-11:
- **23 plugins** en catálogo.
- **13 URLs corregidas** (repos movidos, renombrados o ramas cambiadas).
- Todas las URLs activas retornan HTTP 200/301.

Script de verificación (para mantenimiento periódico):
```bash
jq -r '.plugins[].git_url' plugins.json | while read url; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "$status $url"
done
```

---

## 6. Fuentes y enlaces de referencia

- Moodle Plugins Directory: https://moodle.org/plugins
- Repositorios GitHub definidos en `plugins.json`
- Foros de Moodle en inglés y comunidades de mantenedores
- Open LMS Plugin Matrix y anuncios de fin de soporte (Configurable Reports)

---

## 7. Historial de cambios

| Fecha | Autor | Cambio |
|-------|-------|--------|
| 2026-05-11 | Kimi Code CLI | Creación inicial del inventario (Moodle 4.1.x) |
| 2026-05-15 | Kimi Code CLI | Actualización a Moodle 4.5.11, PHP 8.2, ramas git actualizadas, URLs verificadas, eliminación de mod_googlemeet |
