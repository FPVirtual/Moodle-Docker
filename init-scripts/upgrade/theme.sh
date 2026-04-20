#!/bin/bash

#Uso el nombre completo del fichero tar.gz para evitar ambigüedades con el de versiones anteriores
cp /init-scripts/themes/fpdist/moove_settings_1681978750.tar.gz /var/www/html/        
moosh theme-settings-import --targettheme moove moove_settings_1681978750.tar.gz
cp /init-scripts/themes/fpdist/footer.mustache /var/www/html/theme/moove/templates
cp /init-scripts/themes/fpdist/frontpage.mustache /var/www/html/theme/moove/templates

moosh config-set displaymarketingbox 1 theme_moove
moosh config-set frontpage none

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
