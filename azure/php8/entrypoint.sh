#!/bin/sh
service ssh start
exec docker-php-entrypoint "$@"