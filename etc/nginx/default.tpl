server {
    listen 8080 default_server;
    root /app/cache/static;
    client_max_body_size ${CLIENT_MAX_BODY_SIZE};
    server_tokens off;

    ${WEBLATE_REALIP}

    include snippets/weblate-static.conf;

    location / {
        include snippets/weblate-gunicorn.conf;
    }
}
