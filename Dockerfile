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
    libaio1 \
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

# Copiar código fuente de Moodle
COPY moodle-code /var/www/html
RUN chown -R www-data:www-data /var/www/html

# Copiar también a /usr/src/moodle como backup para bind mounts vacíos
COPY moodle-code /usr/src/moodle
RUN chown -R www-data:www-data /usr/src/moodle

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
