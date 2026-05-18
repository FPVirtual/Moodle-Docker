# Guía de actualización de Moodle en `new-moodle`

Este documento describe paso a paso cómo actualizar Moodle a la siguiente versión estable dentro del entorno contenerizado de `new-moodle` (rama `apache-moodle`).

> **⚠️ ADVERTENCIA IMPORTANTE**
> Nunca actualices en producción sin haber probado previamente el proceso en un entorno de desarrollo o staging.

---

## Resumen del proceso

En un despliegue basado en Docker con imagen autocontenida, actualizar Moodle implica **tres acciones principales**:

1. **Actualizar la versión en el `Dockerfile`** (`ARG MOODLE_VERSION`).
2. **Verificar compatibilidad de plugins** en `plugins.json` (ramas git, URLs).
3. **Reconstruir la imagen Docker** y ejecutar el upgrade automático cuando `INSTALL_TYPE=upgrade`.

> Diferencia clave respecto a despliegues anteriores: ya no se actualiza código en `moodle-code/`. El código se descarga durante el build.

---

## Paso 0. Hacer backup completo

Antes de tocar nada, realiza un backup coordinado de la base de datos y de `moodle-data`.

```bash
cd /var/moodle-docker-deploy/moodle-docker-test/Moodle-Docker
./scripts/backup.sh
```

Esto generará dos archivos en `./backups/`:
- `backup_db_YYYYMMDD_HHMMSS.sql`
- `backup_moodledata_YYYYMMDD_HHMMSS.tar.gz`

Guarda estos archivos en un lugar seguro.

---

## Paso 1. Poner Moodle en modo mantenimiento

Evita que los usuarios accedan mientras se actualiza:

```bash
docker compose exec moodle moosh -n maintenance-on
```

---

## Paso 2. Actualizar versión en el Dockerfile

Edita el `Dockerfile` y cambia la versión de Moodle:

```dockerfile
# Antes:
ARG MOODLE_VERSION=4.5.11

# Después (ejemplo para 4.5.12):
ARG MOODLE_VERSION=4.5.12
```

> **Nota sobre Moodle 4.5 LTS**: Moodle 4.5 es una versión LTS (Long Term Support). Los upgrades dentro de 4.5.x son parches de seguridad y bugfixes que no requieren cambios en plugins.
> Si saltas a una nueva versión mayor (ej. 4.6), asegúrate de seguir la "Regla de oro" al final de este documento.

---

## Paso 3. Verificar compatibilidad de plugins

Revisa `plugins.json` y verifica en [moodle.org/plugins](https://moodle.org/plugins) que los plugins tengan versiones compatibles con la nueva versión de Moodle.

- Actualiza `git_branch` en `plugins.json` si es necesario (ej. de `MOODLE_405_STABLE` a `MOODLE_406_STABLE`).
- Elimina plugins obsoletos o que ya no tengan soporte.
- Si algún plugin personalizado está en `custom/`, asegúrate de que también se haya actualizado.

Puedes verificar rápidamente las URLs de los repositorios:

```bash
jq -r '.plugins[].git_url' plugins.json | while read url; do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "$status $url"
done
```

---

## Paso 4. Ajustar versiones en `.env`

Edita el archivo `.env` y actualiza la variable de versión:

```env
VERSION=4.5.12
```

Si los scripts de upgrade (`init-scripts/upgrade/`) necesitan cambios específicos para la nueva versión, edítalos antes de continuar.

---

## Paso 5. Cambiar `INSTALL_TYPE` a `upgrade`

El `entrypoint.sh` del contenedor `moodle` detecta este valor y ejecutará el proceso de upgrade automáticamente.

```bash
# Edita .env y cambia:
INSTALL_TYPE=upgrade
```

---

## Paso 6. Reconstruir y levantar los contenedores

```bash
docker compose up -d --build
```

Docker construirá una nueva imagen descargando el código actualizado de Moodle y reiniciará el servicio `moodle`.

Durante el arranque, el `entrypoint.sh` hará lo siguiente:
1. Detectará que Moodle **ya está instalado** (las tablas existen en la BD).
2. Como `INSTALL_TYPE=upgrade`, ejecutará:
   ```bash
   php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable
   ```
3. Luego ejecutará `/init-scripts/init.sh`, que a su vez lanzará:
   - `init-scripts/upgrade/moodle.sh`
   - `init-scripts/upgrade/plugins.sh`
   - `init-scripts/upgrade/theme.sh`

### Seguimiento del proceso

Puedes ver el progreso en tiempo real:

```bash
docker compose logs -f moodle
```

Es **normal** que el upgrade tarde varios minutos dependiendo del tamaño de la base de datos. Verás mensajes como:
- `Ejecutando actualización de Moodle...`
- `moodle.sh done`
- `Plugins installed!`
- `Theme configured.`

---

## Paso 7. Volver a `new-install` para evitar reejecuciones

Una vez que el contenedor haya terminado el upgrade y esté estable, **vuelve a cambiar** `INSTALL_TYPE` a `new-install`:

```env
INSTALL_TYPE=new-install
```

Esto es importante porque si el contenedor `moodle` se reinicia (por un fallo, un redeploy o un reinicio del servidor), no quieres que vuelva a ejecutar el upgrade.

No es necesario hacer `docker compose up -d` solo por este cambio, pero si prefieres ser estricto:

```bash
docker compose up -d
```

---

## Paso 8. Verificaciones post-upgrade

### 8.1. Quitar modo mantenimiento

```bash
docker compose exec moodle moosh -n maintenance-off
```

### 8.2. Comprobar versión instalada

Accede a la URL de administración de Moodle:
```
https://tu-dominio.es/admin/index.php
```
O ejecuta:
```bash
docker compose exec moodle php /var/www/html/admin/cli/check_database_schema.php
```

### 8.3. Revisar notificaciones de Moodle

Ve a **Administración del sitio → Notificaciones** y comprueba que no haya advertencias de plugins desactualizados o problemas de esquema de base de datos.

### 8.4. Limpiar cachés

```bash
docker compose exec moodle php /var/www/html/admin/cli/purge_caches.php
```

### 8.5. Probar funcionalidad crítica

- Inicio de sesión de usuarios.
- Acceso a cursos.
- Subida de archivos.
- Funcionalidades de plugins principales (tema Moove, format_tiles, etc.).

---

## Rollback (en caso de problemas graves)

Si algo sale mal y necesitas volver atrás **antes de que los usuarios hayan entrado**:

1. **Poner modo mantenimiento** (si no lo está ya).
2. **Restaurar el backup de la base de datos**:
   ```bash
   docker compose exec -T db mysql -u root -p${MYSQL_ROOT_PASSWORD} ${MOODLE_DB_NAME} < backups/backup_db_YYYYMMDD_HHMMSS.sql
   ```
   > Si usas BD externa, ajusta el comando según tu configuración.
3. **Restaurar `moodle-data`**:
   ```bash
   rm -rf moodle-data/*
   tar -xzf backups/backup_moodledata_YYYYMMDD_HHMMSS.tar.gz --strip-components=1
   ```
4. **Volver a la imagen anterior**:
   ```bash
   # Si etiquetaste la imagen anterior:
   docker compose down
   docker tag new-moodle-moodle:anterior new-moodle-moodle:latest
   docker compose up -d
   ```
   > O simplemente revierte el `MOODLE_VERSION` en el Dockerfile y reconstruye.
5. **Quitar modo mantenimiento**:
   ```bash
   docker compose exec moodle moosh -n maintenance-off
   ```

---

## Checklist resumido

- [ ] Backup de BD y `moodle-data` realizado.
- [ ] Moodle en modo mantenimiento.
- [ ] `MOODLE_VERSION` actualizada en `Dockerfile`.
- [ ] Plugins verificados en `plugins.json` (ramas git, URLs).
- [ ] `.env` actualizado con la nueva `VERSION`.
- [ ] `INSTALL_TYPE=upgrade` en `.env`.
- [ ] `docker compose up -d --build` ejecutado.
- [ ] Logs revisados y upgrade completado sin errores.
- [ ] `INSTALL_TYPE` vuelto a `new-install`.
- [ ] Modo mantenimiento desactivado.
- [ ] Cachés purgadas y funcionalidad básica probada.

---

## Notas adicionales

- **Saltos de versión:** Moodle recomienda no saltar más de una versión mayor a la vez. Por ejemplo, si estás en 4.5, sube primero a 4.6, y luego a 4.7. Nunca directamente de 4.5 a 4.8.
- **Plugins no compatibles:** Si un plugin esencial no tiene versión para la nueva release de Moodle, pospon la actualización hasta que esté disponible, o busca una alternativa soportada.
- **Imagen autocontenida:** Como el código ya no se monta desde `moodle-code/`, el rollback es más sencillo: solo necesitas cambiar el `MOODLE_VERSION` en el Dockerfile y reconstruir.
