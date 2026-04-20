# Guía de actualización de Moodle en `new-moodle`

Este documento describe paso a paso cómo actualizar Moodle a la siguiente versión estable dentro del entorno contenerizado de `new-moodle`.

> **⚠️ ADVERTENCIA IMPORTANTE**
> Nunca actualices en producción sin haber probado previamente el proceso en un entorno de desarrollo o staging.

---

## Resumen del proceso

En un despliegue basado en Docker, actualizar Moodle implica **tres acciones principales**:

1. **Actualizar el código fuente** (`moodle-code/`).
2. **Reconstruir la imagen Docker** para que incluya ese nuevo código.
3. **Ejecutar el script de upgrade** de Moodle (`admin/cli/upgrade.php`), lo cual se hace automáticamente mediante el `entrypoint.sh` cuando `INSTALL_TYPE=upgrade`.

---

## Paso 0. Hacer backup completo

Antes de tocar nada, realiza un backup coordinado de la base de datos y de `moodle-data`.

```bash
cd /var/moodle-docker-deploy/www.fpvirtualaragon.es/new-moodle
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

## Paso 2. Descargar y preparar el nuevo código de Moodle

### 2.1. Obtener la nueva versión

Descarga el paquete ZIP/TAR de la nueva versión estable desde [download.moodle.org](https://download.moodle.org) o mediante `wget`:

```bash
# Ejemplo para Moodle 4.2.x (cambia la URL por la versión objetivo)
wget https://download.moodle.org/download.php/direct/stable402/moodle-4.2.5.tgz -O /tmp/moodle-new.tgz
```

### 2.2. Extraer y reemplazar `moodle-code/`

```bash
# Mover el actual por si necesitas rollback rápido
mv moodle-code moodle-code-backup-$(date +%Y%m%d)

# Extraer el nuevo código
mkdir -p moodle-code
tar -xzf /tmp/moodle-new.tgz -C . --strip-components=1
```

> **Nota sobre `config.php`:** El archivo `config.php` del proyecto actual ya está adaptado para leer las variables de entorno (`MOODLE_DB_HOST`, `MOODLE_DB_NAME`, etc.). Si el nuevo paquete de Moodle sobrescribe `config.php`, **debes recuperar el anterior**:
> ```bash
> cp moodle-code-backup-YYYYMMDD/config.php moodle-code/config.php
> ```
> Verifica que `$CFG->dataroot` apunte a `/var/www/moodledata` y que la base de datos use `getenv()`.

---

## Paso 3. Verificar compatibilidad de plugins

Si usas plugins de terceros (instalados por `init-scripts/new-install/plugins.sh` o `init-scripts/upgrade/plugins.sh`), verifica en [moodle.org/plugins](https://moodle.org/plugins) que existan versiones compatibles con la nueva versión de Moodle.

- Actualiza la lista de plugins en `init-scripts/upgrade/plugins.sh` si es necesario.
- Elimina plugins obsoletos o que ya no tengan soporte.
- Si algún plugin personalizado está en `moodle-code/`, asegúrate de que también se haya actualizado.

---

## Paso 4. Ajustar versiones en `.env` y en scripts

Edita el archivo `.env` y actualiza la variable de versión:

```env
VERSION=4.2.5
```

Si los scripts de upgrade (`init-scripts/upgrade/`) necesitan cambios específicos para la nueva versión (por ejemplo, cambios en configuraciones o nuevos pasos de limpieza), edítalos antes de continuar.

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

Docker construirá una nueva imagen con el código actualizado y reiniciará el servicio `moodle`.

Durante el arranque, el `entrypoint.sh` hará lo siguiente:
1. Detectará que Moodle **ya está instalado** (las tablas existen en la BD).
2. Como `INSTALL_TYPE=upgrade`, ejecutará:
   ```bash
   php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable
   ```
3. Luego ejecutará `init-scripts/init.sh`, que a su vez lanzará:
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
3. **Restaurar `moodle-data`**:
   ```bash
   rm -rf moodle-data/*
   tar -xzf backups/backup_moodledata_YYYYMMDD_HHMMSS.tar.gz --strip-components=1
   ```
4. **Restaurar el código anterior**:
   ```bash
   rm -rf moodle-code
   mv moodle-code-backup-YYYYMMDD moodle-code
   ```
5. **Reconstruir y levantar con la versión anterior**:
   ```bash
   docker compose up -d --build
   ```
6. **Quitar modo mantenimiento**:
   ```bash
   docker compose exec moodle moosh -n maintenance-off
   ```

---

## Checklist resumido

- [ ] Backup de BD y `moodle-data` realizado.
- [ ] Moodle en modo mantenimiento.
- [ ] Nuevo código descargado y colocado en `moodle-code/`.
- [ ] `config.php` preservado o adaptado.
- [ ] Plugins verificados y scripts de upgrade actualizados.
- [ ] `.env` actualizado con la nueva `VERSION`.
- [ ] `INSTALL_TYPE=upgrade` en `.env`.
- [ ] `docker compose up -d --build` ejecutado.
- [ ] Logs revisados y upgrade completado sin errores.
- [ ] `INSTALL_TYPE` vuelto a `new-install`.
- [ ] Modo mantenimiento desactivado.
- [ ] Cachés purgadas y funcionalidad básica probada.

---

## Notas adicionales

- **Saltos de versión:** Moodle recomienda no saltar más de una versión mayor a la vez. Por ejemplo, si estás en 4.1, sube primero a 4.2, y luego a 4.3. Nunca directamente de 4.1 a 4.4.
- **Plugins no compatibles:** Si un plugin esencial no tiene versión para la nueva release de Moodle, pospon la actualización hasta que esté disponible, o busca una alternativa soportada.
- `moodle-code-old` del proyecto original **no se usa** en `new-moodle`. Puedes ignorarlo o eliminarlo del entorno de producción final para ahorrar espacio.
