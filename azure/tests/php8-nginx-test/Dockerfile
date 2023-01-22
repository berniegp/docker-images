# Test image for php with an Nginx frontend on port 80 and a phpinfo() index page

FROM berniegp/azure:php8-nginx

ADD default.conf.template /etc/nginx/templates/

ENV DOCUMENT_ROOT /var/www/html/
ADD --chown=www-data site "${DOCUMENT_ROOT}"
