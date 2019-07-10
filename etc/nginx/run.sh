#!/bin/bash
envsubst < /etc/nginx/default.tpl > /etc/nginx/sites-available/default;
exec /usr/sbin/nginx -g "daemon off;"
