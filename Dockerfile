# Dockerfile para Moodle FPD basado en imágenes oficiales de Docker
# Base: PHP-FPM 8.1 (oficial) - compatible con Moodle 4.1.x

FROM php:8.1-fpm

# Instalar dependencias del sistema y extensiones PHP necesarias para Moodle
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libldap2-dev \
    libsasl2-dev \
    zlib1g-dev \
    libmemcached-dev \
    git \
    unzip \
    curl \
    vim \
    nano \
    wget \
    cron \
    ghostscript \
    libfontconfig1 \
    libfreetype6 \
    libjpeg62-turbo \
    libpng16-16 \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxrender1 \
    xfonts-75dpi \
    xfonts-base \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Configurar locales
RUN sed -i 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

# Instalar extensiones PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) mysqli pdo_mysql intl mbstring xml zip curl exif soap opcache ldap

# Instalar redis (para sesiones y caché)
RUN pecl install redis && docker-php-ext-enable redis

# Instalar ioncube loader (opcional pero a veces requerido por plugins antiguos)
# Omitido para mantener la imagen limpia y oficial

# Instalar Composer (oficial)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Instalar Moosh (gestor de Moodle vía CLI)
RUN git clone https://github.com/tmuras/moosh.git /opt/moosh \
    && cd /opt/moosh \
    && composer install --no-dev --prefer-dist \
    && ln -s /opt/moosh/moosh.php /usr/local/bin/moosh \
    && chmod +x /usr/local/bin/moosh

# Crear directorio de datos de Moodle
RUN mkdir -p /var/www/moodledata && chown -R www-data:www-data /var/www/moodledata

# Descargar Moodle 4.1.19 oficial desde GitHub
ARG MOODLE_VERSION=4.1.19
RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz | tar xz -C /tmp \
    && mv /tmp/moodle-* /usr/src/moodle \
    && cp -r /usr/src/moodle/* /var/www/html/ \
    && chown -R www-data:www-data /var/www/html /usr/src/moodle

# Instalar plugins de terceros desde git (ramas compatibles con Moodle 4.1)
# Nota: Se clonan desde repos oficiales/mantenidos. Verificar compatibilidad en moodle.org/plugins
RUN cd /var/www/html/mod && git clone --depth 1 --branch MOODLE_401_STABLE https://github.com/danmarsden/moodle-mod_attendance.git attendance \
    && cd /var/www/html/mod && git clone --depth 1 https://github.com/basbruss/moodle-mod_board.git board \
    && cd /var/www/html/mod && git clone --depth 1 --branch main https://github.com/davosmith/moodle-mod_checklist.git checklist \
    && cd /var/www/html/mod && git clone --depth 1 https://github.com/ndunand/moodle-mod_choicegroup.git choicegroup \
    && cd /var/www/html/mod && git clone --depth 1 https://github.com/gerardkcohen/moodle-mod_googlemeet.git googlemeet \
    && cd /var/www/html/mod && git clone --depth 1 https://github.com/rwirth/moodle-mod_pdfannotator.git pdfannotator \
    && cd /var/www/html/blocks && git clone --depth 1 --branch MOODLE_401_STABLE https://github.com/deraadt/Moodle-block_completion_progress.git completion_progress \
    && cd /var/www/html/blocks && git clone --depth 1 --branch master https://github.com/remotelearner/Moodle-block_grade_me.git grade_me \
    && cd /var/www/html/blocks && git clone --depth 1 https://github.com/fruitl00p/Moodle-block_sharing_cart.git sharing_cart \
    && cd /var/www/html/blocks && git clone --depth 1 https://github.com/FMCorz/moodle-block_xp.git xp \
    && cd /var/www/html/local && git clone --depth 1 https://github.com/Syxton/moodle-local_mail.git mail \
    && cd /var/www/html/local && git clone --depth 1 https://github.com/Isuru-Madusanka/moodle-local_reminders.git reminders \
    && cd /var/www/html/theme && git clone --depth 1 --branch MOODLE_401_STABLE https://github.com/willianmano/moodle-theme_moove.git moove \
    && cd /var/www/html/report && git clone --depth 1 https://github.com/jleyva/moodle-report_coursestats.git coursestats \
    && cd /var/www/html/question/type && git clone --depth 1 https://github.com/gbateson/moodle-qtype_gapfill.git gapfill \
    && cd /var/www/html/mod/quiz/accessrule && git clone --depth 1 https://github.com/safatman/moodle-quizaccess_onesession.git onsession \
    && cd /var/www/html/lib/editor/atto/plugins && git clone --depth 1 https://github.com/dthies/moodle-atto_c4l.git c4l \
    && cd /var/www/html/lib/editor/atto/plugins && git clone --depth 1 https://github.com/dthies/moodle-atto_fullscreen.git fullscreen \
    && cd /var/www/html/availability/condition && git clone --depth 1 https://github.com/FMCorz/moodle-availability_xp.git xp \
    && cd /var/www/html/course/format && git clone --depth 1 --branch main https://github.com/deferredreward/moodle-format_tiles.git tiles \
    && cd /var/www/html/blocks && git clone --depth 1 https://github.com/jleyva/moodle-block_configurablereports.git configurable_reports \
    && cd /var/www/html/lib/editor/atto/plugins && git clone --depth 1 https://github.com/andrewnicols/moodle-atto_fontsize.git fontsize \
    && cd /var/www/html/lib/editor/atto/plugins && git clone --depth 1 https://github.com/andrewnicols/moodle-atto_fontfamily.git fontfamily \
    && chown -R www-data:www-data /var/www/html

# Copiar scripts/aplicaciones PHP custom que viven en la raíz del documento web
COPY custom/decalogo /var/www/html/decalogo
COPY custom/faqs /var/www/html/faqs
COPY custom/private-reports /var/www/html/private-reports
COPY custom/soporte /var/www/html/soporte
COPY custom/userpix /var/www/html/userpix
RUN chown -R www-data:www-data /var/www/html/decalogo /var/www/html/faqs \
    /var/www/html/private-reports /var/www/html/soporte /var/www/html/userpix

# Copiar scripts de inicialización
COPY init-scripts /init-scripts
RUN chmod +x /init-scripts/init.sh \
    && chmod +x /init-scripts/new-install/*.sh \
    && chmod +x /init-scripts/upgrade/*.sh

# Copiar configuraciones de PHP-FPM y PHP
COPY fpm-conf /usr/local/etc/php-fpm.d
COPY php-conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY php-conf/uploads.ini /usr/local/etc/php/conf.d/uploads.ini
COPY php-conf/zzz-disable-apcu.ini /usr/local/etc/php/conf.d/zzz-disable-apcu.ini

# Entrypoint propio
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html
EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
