server {
    listen 4443 ssl;

    ssl_certificate /app/data/ssl/fullchain.pem;
    ssl_certificate_key /app/data/ssl/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;

    # intermediate configuration from https://ssl-config.mozilla.org/
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    ssl_dhparam /etc/nginx/ffdhe2048.pem;

    root /app/cache/static;
    client_max_body_size 100M;
    server_tokens off;

    location ~ ^/favicon.ico$ {
        # DATA_DIR/static/favicon.ico
        alias /app/cache/static/favicon.ico;
        expires 30d;
    }

    location ${WEBLATE_URL_PREFIX}/static/ {
        # DATA_DIR/static/
        alias /app/cache/static/;
        expires 30d;
    }

    location ${WEBLATE_URL_PREFIX}/media/ {
        # DATA_DIR/media/
        alias /app/data/media/;
        expires 30d;
    }

    location / {
        include uwsgi_params;
        # Needed for long running operations in admin interface
        uwsgi_read_timeout 3600;
        # Adjust based to uwsgi configuration:
        uwsgi_pass unix:///run/uwsgi/app/weblate/socket;
    }
}

server {
    listen 8080 default_server;
    server_tokens off;
    return 301 https://$host$request_uri;
}
