## 1. Análisis del proyecto y los scripts

### Arquitectura general
El proyecto es un despliegue **Docker Compose** de Moodle 4.1.3 preparado para diferentes tipos de centros educativos (IES, CEIP, CPEPA, CPI, FPD, etc.). Se compone de:

| Componente | Descripción |
|------------|-------------|
| **Servicios Docker** | `redis` (caché/sesiones), `web` (nginx:latest) y `moodle` (PHP-FPM basado en `cateduac/moodle:4.1.3-nginx-fpm-unoconv`). |
| **Código fuente** | Carpeta `./moodle-code/` (montada en nginx y en el contenedor PHP-FPM). |
| **Datos de Moodle** | Carpeta `./moodle-data/` (montada en `/var/www/moodledata`). |
| **Base de datos** | **No está definida en el `docker-compose.yml`**. Se asume una BD externa (MariaDB/MySQL) accesible mediante las variables de entorno. |
| **Proxy inverso** | Usa una red externa `nginx-proxy_frontend`, lo que indica que hay un proxy (p. ej. `nginx-proxy` o Traefik) gestionando el tráfico HTTPS y los certificados. |
| **Configuraciones** | `./nginx/default.conf`, `./fpm-conf/`, `./php-conf/` (opcache, uploads, desactivación de APCu). |
| **Inicialización** | `./init-scripts/` contiene la lógica de primer arranque y actualizaciones. |

### Flujo de los scripts de inicialización
El `docker-compose.yml` monta `./init-scripts` en `/init-scripts` del contenedor Moodle. La imagen base (`cateduac/moodle`) ejecuta automáticamente `init.sh` en su entrypoint al arrancar.

**`init.sh`** (orquestador):
- Lee las variables `INSTALL_TYPE` (`new-install` o `upgrade`) y `SCHOOL_TYPE` (`IES`, `CEIP`, `FPD`, `VACIO`…).
- Ejecuta secuencialmente estos scripts (solo si tienen permiso de ejecución):
  1. `moodle.sh` → configura el sitio.
  2. `plugins.sh` → instala plugins vía `moosh`.
  3. `import_${SCHOOL_TYPE}_categories_and_courses.sh` → restaura las categorías y los cursos desde los archivos `.mbz`.
  4. `theme.sh` → configura el tema Moove con personalizaciones específicas.

#### Scripts de `new-install/` (se ejecutan la primera vez)
- **`moodle.sh`**: Configura todo el sitio mediante `moosh` (SMTP, webservices, idiomas, usuarios de prueba, roles personalizados como `gestora` o `familiar`, notificaciones, app móvil, políticas de privacidad, etc.). Diferencia comportamiento entre FPD y el resto de centros.
- **`plugins.sh`**: Instala automáticamente plugins desde el repositorio oficial de Moodle (`format_tiles`, `mod_board`, `local_mail`, `block_xp`, `mod_pdfannotator`, etc.) y los configura.
- **`import_*_categories_and_courses.sh`**: Crea la jerarquía de categorías y restaura decenas de cursos desde `./init-scripts/mbzs/`. Por ejemplo, para `IES` crea categorías de ESO, Bachillerato, PMAR, etc., y restaura más de 170 cursos.
- **`theme.sh`**: Importa ajustes del tema Moove, copia fuentes (Boo), mustaches personalizadas (`frontpage.mustache`, `footer.mustache`) y añade CSS/SCSS custom.

#### Scripts de `upgrade/` (se ejecutan al actualizar)
- **`moodle.sh`**: Lanza `admin/cli/upgrade.php` con `expect` para automatizar la respuesta, y aplica ajustes post-upgrade (formato por defecto, desactivar analytics, etc.).
- **`plugins.sh`**: Reinstala o actualiza plugins, desinstala los obsoletos.
- **`theme.sh`**: Reaplica la configuración del tema.

#### Otros scripts útiles
- **`backup_to_mbz_moodle_courses.sh`**: Exporta **todos** los cursos de la plataforma a archivos `.mbz` usando `moosh course-backup`. Útil para migraciones o backups masivos.

---

## 2. Pasos para crear una instancia de Moodle ahora

Para levantar una instancia nueva desde cero con este proyecto:

1. **Revisar/crear el archivo `.env`**  
   Debe contener al menos:
   ```env
   VIRTUAL_HOST=miinstancia.ejemplo.es
   SSL_EMAIL=admin@ejemplo.es
   MOODLE_URL=https://miinstancia.ejemplo.es
   MOODLE_DB_HOST=IP_O_HOST_DB
   MOODLE_DB_NAME=moodle
   MOODLE_MYSQL_USER=moodleuser
   MOODLE_MYSQL_PASSWORD=...
   MOODLE_ADMIN_USER=admin
   MOODLE_ADMIN_PASSWORD=...
   MOODLE_ADMIN_EMAIL=...
   MOODLE_LANG=es
   MOODLE_SITE_NAME="Mi Moodle"
   MOODLE_SITE_FULLNAME="Mi Moodle Completo"
   SSL_PROXY=true
   INSTALL_TYPE=new-install
   SCHOOL_TYPE=IES        # o CEIP, FPD, VACIO, etc.
   VERSION=4.1.3
   # ... resto de variables SMTP, contraseñas de gestor, etc.
   ```

2. **Asegurar la red externa del proxy**  
   ```bash
   docker network create nginx-proxy_frontend
   ```

3. **Asegurar que la base de datos está accesible**  
   La BD debe existir, estar vacía y ser accesible desde el host donde correrá el contenedor `moodle`. Asegúrate de que el usuario tenga permisos de lectura/escritura.

4. **Poner permisos de ejecución a los scripts necesarios**  
   ```bash
   chmod +x init-scripts/new-install/*.sh
   # o para upgrade:
   # chmod +x init-scripts/upgrade/*.sh
   ```

5. **Levantar los contenedores**  
   ```bash
   docker compose up -d
   ```

6. **Verificar la instalación**  
   Sigue los logs del contenedor `moodle`:
   ```bash
   docker compose logs -f moodle
   ```
   Verás cómo se ejecutan los scripts de `new-install`. Este proceso puede tardar varios minutos porque descarga e instala plugins y restaura todos los cursos desde los `.mbz`.

7. **Post-instalación**  
   Los scripts se desactivan automáticamente al perder el permiso de ejecución (comentario en `init.sh`). Sin embargo, como los volúmenes son *bind mounts*, el cambio de permisos persiste en tu disco local. Si reinicias el contenedor, no volverán a ejecutarse salvo que les vuelvas a dar `chmod +x`.

---

## 3. Pasos para transformar esta instalación completa a un contenedor

La instalación ya usa Docker, pero depende de **bind mounts** locales (`moodle-code`, `moodle-data`, `init-scripts`). Si lo que buscas es una imagen **autocontenida y portable** (o incluso un único contenedor), tienes dos enfoques:

### Opción A: Docker Compose completo y reproducible (Recomendado)
El enfoque profesional es incluir la base de datos en el propio `docker-compose.yml` y construir una **imagen propia** que incluya el código y los scripts, eliminando la dependencia de carpetas locales.

**Pasos a seguir:**

1. **Crear un `Dockerfile`** en la raíz del proyecto:
   ```dockerfile
   FROM cateduac/moodle:4.1.3-nginx-fpm-unoconv
   
   # Copiar el código de Moodle ya configurado
   COPY moodle-code /var/www/html
   
   # Copiar los scripts de inicialización
   COPY init-scripts /init-scripts
   
   # Copiar configuraciones de PHP-FPM y PHP
   COPY fpm-conf /usr/local/etc/php-fpm.d
   COPY php-conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
   COPY php-conf/uploads.ini /usr/local/etc/php/conf.d/uploads.ini
   COPY php-conf/zzz-disable-apcu.ini /usr/local/etc/php/conf.d/zzz-disable-apcu.ini
   
   # Ajustar permisos
   RUN chown -R www-data:www-data /var/www/html /var/www/moodledata /init-scripts
   ```

2. **Añadir el servicio de base de datos al `docker-compose.yml`**:
   ```yaml
   services:
     db:
       image: mariadb:10.6
       environment:
         MYSQL_ROOT_PASSWORD: rootpass
         MYSQL_DATABASE: moodle
         MYSQL_USER: moodleuser
         MYSQL_PASSWORD: moodlepass
       volumes:
         - db_data:/var/lib/mysql
       networks:
         - moodle-internal
   
     moodle:
       build: .          # Usa el Dockerfile que acabas de crear
       # ... resto de configuración ...
       environment:
         MOODLE_DB_HOST: db
       networks:
         - moodle-internal
         - nginx-proxy_frontend
   ```
   Y usar un volumen Docker nombrado para `moodle-data` en lugar del bind mount:
   ```yaml
   volumes:
     - moodle_data:/var/www/moodledata
   ```

3. **Eliminar bind mounts innecesarios**  
   Sustituye `./moodle-code:/var/www/html` y `./init-scripts:/init-scripts` por la imagen construida. Solo mantén bind mounts para configuraciones que cambies frecuentemente (nginx) o usa `configs` de Docker Swarm/Compose.

4. **Empaquetar y distribuir**  
   ```bash
   docker compose build
   docker tag proyecto-moodle:latest mi-registry/moodle:prod
   docker push mi-registry/moodle:prod
   ```

### Opción B: Contenedor monolítico (Todo-en-uno)
Si necesitas que todo corra en **un único contenedor** (por ejemplo, para un entorno de demostración offline), puedes hacerlo, aunque es un *anti-pattern* en contenedores.

**Pasos a seguir:**

1. **Crear un `Dockerfile` multicomponente**:
   - Base: Debian/Ubuntu o la imagen actual de `cateduac/moodle`.
   - Instalar `mariadb-server` y `supervisor`.
   - Copiar `moodle-code`, `moodle-data` y un dump SQL de la base de datos.
   - Configurar `supervisord` para levantar 3 procesos: MariaDB, PHP-FPM y Nginx.

2. **Incluir un script de entrypoint** que:
   - Inicie MariaDB.
   - Cree la base de datos si no existe (importando el dump).
   - Ejecute los scripts de `init-scripts` si es la primera vez.
   - Lance `supervisord`.

3. **Limitaciones**:
   - El rendimiento será inferior.
   - La escalabilidad es nula.
   - Los datos de la BD dentro del contenedor no persisten salvo que uses volúmenes.

### Resumen recomendado
| Escenario | Enfoque recomendado |
|-----------|---------------------|
| **Producción / Escalable** | Opción A: Construir una imagen propia con el código + scripts, añadir `db` al `docker-compose.yml` y usar volúmenes Docker para datos y BD. |
| **Demo / Offline / Portátil** | Opción B: Contenedor monolítico con `supervisord`, pero teniendo claro que es solo para pruebas. |

Si me indicas cuál es tu objetivo final (producción en la nube, demo local, migración a Kubernetes, etc.), puedo detallarte el `Dockerfile` y el `docker-compose.yml` exactos que necesitas.