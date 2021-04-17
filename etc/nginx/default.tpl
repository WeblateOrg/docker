server {
    listen 8080 default_server;
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
