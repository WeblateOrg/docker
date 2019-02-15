#!/bin/bash
sed -e "s%{{URL_PREFIX}}%${WEBLATE_URL_PREFIX}%g" /etc/nginx/default.tpl > /etc/nginx/sites-available/default
exec /usr/sbin/nginx -g "daemon off;"