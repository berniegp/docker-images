# - php:5.6-apache image with:
#   - mcrypt
#   - opcache
#   - pdo_mysql
# - SSH server configured for the Azure App Service
#
# Configurable environment variables:
# - APACHE_DOCUMENT_ROOT: Path to Apache's DocumentRoot where the website is. Default: /var/www/html
#
# If files are served from persistent storage or a mounted storage account (e.g. an SMB Azure File Share),
# you'll probably also need to disable EnableMMAP and EnableSendfile in Apache's configuration.
# See https://stackoverflow.com/questions/73322091/laravel-in-docker-on-azure-webapp-cant-serve-images-from-mounted-file-storage

FROM php:5.6-apache


##############
# SSH server #
##############
# https://learn.microsoft.com/en-us/azure/app-service/configure-custom-container?pivots=container-linux#enable-ssh
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        openssh-server \
    ; \
    # Make sure a host key exists for all key types
    ssh-keygen -A; \
    # Azure app service requires this root password
    echo "root:Docker!" | chpasswd; \
    # Cleanup apt-get update package lists
    rm -rf /var/lib/apt/lists/*

COPY sshd_config /etc/ssh/

# Open port 2222 for SSH access
EXPOSE 2222


#######
# PHP #
#######
# Add the mcrypt extension and the PDO MySQL driver
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libmcrypt-dev \
    ; \
    docker-php-ext-install -j "$(nproc)" \
        mcrypt \
        opcache \
        pdo_mysql \
    ; \
    # Cleanup apt-get update package lists
    rm -rf /var/lib/apt/lists/*

# Use the default production configuration with some extra options
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    { \
        echo '; Make the error log visible in the Docker log stream'; \
        echo 'error_log=/dev/stderr'; \
    } >>"$PHP_INI_DIR/php.ini"

ENV PHP_OPCACHE_ENABLE="1"

# Enable this to pick up modified files by checking timestamps on each request
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"

ADD opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"


##########
# Apache #
##########
# Make the document root configurable
ENV APACHE_DOCUMENT_ROOT /var/www/html
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Enable Apache's mod_rewrite module
RUN a2enmod rewrite

# Enable Apache's trace8 LogLevel
# RUN sed -i 's!LogLevel warn!LogLevel trace8!g' /etc/apache2/apache2.conf


###########
# Startup #
###########
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
