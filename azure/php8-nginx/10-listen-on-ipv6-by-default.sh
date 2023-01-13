#!/bin/sh
# vim:sw=4:ts=4:et

# Copyright (C) 2011-2016 Nginx, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

ME=$(basename $0)
DEFAULT_CONF_FILE="etc/nginx/conf.d/default.conf"

# check if we have ipv6 available
if [ ! -f "/proc/net/if_inet6" ]; then
    entrypoint_log "$ME: info: ipv6 not available"
    exit 0
fi

if [ ! -f "/$DEFAULT_CONF_FILE" ]; then
    entrypoint_log "$ME: info: /$DEFAULT_CONF_FILE is not a file or does not exist"
    exit 0
fi

# check if the file can be modified, e.g. not on a r/o filesystem
touch /$DEFAULT_CONF_FILE 2>/dev/null || { entrypoint_log "$ME: info: can not modify /$DEFAULT_CONF_FILE (read-only file system?)"; exit 0; }

# check if the file is already modified, e.g. on a container restart
grep -q "listen  \[::]\:80;" /$DEFAULT_CONF_FILE && { entrypoint_log "$ME: info: IPv6 listen already enabled"; exit 0; }

if [ -f "/etc/os-release" ]; then
    . /etc/os-release
else
    entrypoint_log "$ME: info: can not guess the operating system"
    exit 0
fi

entrypoint_log "$ME: info: Getting the checksum of /$DEFAULT_CONF_FILE"

case "$ID" in
    "debian")
        CHECKSUM=$(dpkg-query --show --showformat='${Conffiles}\n' nginx | grep $DEFAULT_CONF_FILE | cut -d' ' -f 3)
        echo "$CHECKSUM  /$DEFAULT_CONF_FILE" | md5sum -c - >/dev/null 2>&1 || {
            entrypoint_log "$ME: info: /$DEFAULT_CONF_FILE differs from the packaged version"
            exit 0
        }
        ;;
    "alpine")
        CHECKSUM=$(apk manifest nginx 2>/dev/null| grep $DEFAULT_CONF_FILE | cut -d' ' -f 1 | cut -d ':' -f 2)
        echo "$CHECKSUM  /$DEFAULT_CONF_FILE" | sha1sum -c - >/dev/null 2>&1 || {
            entrypoint_log "$ME: info: /$DEFAULT_CONF_FILE differs from the packaged version"
            exit 0
        }
        ;;
    *)
        entrypoint_log "$ME: info: Unsupported distribution"
        exit 0
        ;;
esac

# enable ipv6 on default.conf listen sockets
sed -i -E 's,listen       80;,listen       80;\n    listen  [::]:80;,' /$DEFAULT_CONF_FILE

entrypoint_log "$ME: info: Enabled listen on IPv6 in /$DEFAULT_CONF_FILE"

exit 0