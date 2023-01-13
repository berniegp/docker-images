# Includes:
# - PHP 7.4 fpm (Docker entrypoint)
#   - mcrypt
#   - opcache
#   - pdo_mysql
# - Nginx frontend based on the official Nginx docker image (https://hub.docker.com/_/nginx)
# - SSH server configured for the Azure App Service
#
# Configurable environment variables:
# - NGINX_DEBUG: set to run nginx in debug mode
#
# References:
# - https://github.com/Azure-App-Service/ImageBuilder/tree/285a78e5bf05a9752e065c88881221aee3b11dce/GenerateDockerFiles/php/nginx

FROM php:7.4-fpm-bullseye


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
        opcache \
        pdo_mysql \
    ; \
    yes '' | pecl install mcrypt-1.0.5; \
    docker-php-ext-enable mcrypt; \
    # Cleanup apt-get update package lists
    rm -rf /var/lib/apt/lists/*

# Use the default production configuration with some extra options
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    { \
        echo '; Make the error log visible in the Docker log stream'; \
        echo 'error_log=/dev/stderr'; \
    } >> "$PHP_INI_DIR/php.ini"

ENV PHP_OPCACHE_ENABLE="1"

# Enable this to pick up modified files by checking timestamps on each request
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"

ADD opcache.ini "$PHP_INI_DIR/conf.d/opcache.ini"


#########
# Nginx #
#########
# The installation steps from the nginx are updated from the Ngimx image to match the installation
# instructions from the Nginx manual (https://nginx.org/en/linux_packages.html#Debian).
# https://github.com/nginxinc/docker-nginx/blob/761fffeba0d867d6e80d38998073e0eaa456bb02/mainline/debian/Dockerfile
ENV NGINX_VERSION   1.23.3
ENV NJS_VERSION     0.7.9
ENV PKG_RELEASE     1~bullseye

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system --gid 101 nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates \
    && \
# Import an official nginx signing key so apt could verify the packages authenticity
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    NGINX_GPGKEY_PATH=/usr/share/keyrings/nginx-archive-keyring.gpg; \
    export GNUPGHOME="$(mktemp -d)"; \
    found=''; \
    for server in \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        gpg1 --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    gpg1 --export "$NGINX_GPGKEY" > "$NGINX_GPGKEY_PATH" ; \
    rm -rf "$GNUPGHOME"; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
    " \
    && echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/mainline/debian/ bullseye nginx" >> /etc/apt/sources.list.d/nginx.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
                        curl \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d
RUN chmod +x /docker-entrypoint.d/*.sh

EXPOSE 80


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


###########
# Startup #
###########
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
