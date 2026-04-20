#!/bin/bash
# Configuración del tema para FPD

echo "Configuring theme..."

moosh config-set theme moove

# FPD specific theme configuration
echo "... for FPD..."
cp /init-scripts/themes/fpdist/moove*tar.gz /var/www/html/
moosh theme-settings-import --targettheme moove moove*tar.gz

# Forzar configuraciones que no se comportan bien en la importación
moosh config-set displaymarketingbox 1 theme_moove

# Copiar imágenes, logos y plantillas
cp -R /init-scripts/themes/fpdist/style /var/www/html/theme/moove
cp /init-scripts/themes/fpdist/footer.mustache /var/www/html/theme/moove/templates
cp /init-scripts/themes/fpdist/frontpage.mustache /var/www/html/theme/moove/templates

# Política de privacidad
cp /init-scripts/themes/fpdist/politica-privacidad.php /var/www/html/politica-privacidad.php

# Configurar página principal
moosh config-set frontpage none

# Soporte
mkdir -p /var/www/html/soporte/
cp -R /init-scripts/themes/fpdist/soporte /var/www/html/soporte
cp /init-scripts/themes/fpdist/soporte/secret-sample.php /var/www/html/soporte/secret.php 

# FAQs
mkdir -p /var/www/html/faqs/
cp -R /init-scripts/themes/fpdist/faqs /var/www/html/faqs

# SCSS personalizado
moosh config-set scss "
input[value|='CC'] {
    display: none !important;
}

input[value|='Para'] {
    display: none !important;
}

input[value|='Responder Todos'] {
    display: none !important;
}

.madeby {
    display: none;
}
.contact {
    display: none;
}
.socialnetworks {
    display: none;
}
.path-login {
    #page {
        max-width: 100%;
    }
    .login-container {
        .login-logo {
            justify-content: center;
        }
    }
    .login-identityprovider-btn.facebook {
        background-color: \$facebook-color;
        color: #fff;
    }
}
" theme_moove

echo >&2 "Theme configured."
