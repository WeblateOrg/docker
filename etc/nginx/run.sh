#!/bin/bash
if [ -f /app/data/ssl/privkey.pem ] ; then
    envsubst < /etc/nginx/ssl.tpl > /etc/nginx/sites-available/default;
else
    envsubst < /etc/nginx/default.tpl > /etc/nginx/sites-available/default;
fi
exec /usr/sbin/nginx -g "daemon off;"
