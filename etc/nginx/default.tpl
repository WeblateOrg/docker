server {
{% if WEBLATE_BUILTIN_SSL %}
    listen 4443 ssl;

    ssl_certificate /app/data/ssl/fullchain.pem;
    ssl_certificate_key /app/data/ssl/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;

    # generated 2025-05-07, Mozilla Guideline v5.7, nginx 1.26.3, OpenSSL 3.4.1, intermediate config
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ecdh_curve X25519:prime256v1:secp384r1;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    ssl_dhparam /etc/nginx/ffdhe2048.pem;
{% else %}
    listen 8080 default_server;
{% endif %}
    root /app/cache/static;
    client_max_body_size {{ CLIENT_MAX_BODY_SIZE }};
    server_tokens off;
    port_in_redirect off;

    {{ WEBLATE_REALIP }}

{% if WEBLATE_ANUBIS_URL %}
    location /.within.website/x/cmd/anubis/static/img/ {
        alias /app/cache/static/anubis/;
    }

    location /.within.website/ {
        proxy_pass {{ WEBLATE_ANUBIS_URL }};
        auth_request off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_pass_request_body off;
        proxy_set_header content-length "";
    }

    location @redirectToAnubis {
        return 307 {{ WEBLATE_SITE_URL }}/.within.website/?redir=$scheme://$host$request_uri;
        auth_request off;
    }
{% endif %}

    location ~ ^/favicon.ico$ {
        # DATA_DIR/static/favicon.ico
        alias /app/cache/static/favicon.ico;
        expires 30d;
    }

    location {{ WEBLATE_URL_PREFIX }}/static/ {
        # DATA_DIR/static/
        alias /app/cache/static/;
        expires 30d;
    }

    location {{ WEBLATE_URL_PREFIX }}/media/ {
        # DATA_DIR/media/
        alias /app/data/media/;
        expires 30d;
    }

{% if WEBLATE_BUILTIN_SSL %}
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
{% endif %}
    proxy_set_header Host $http_host;
    proxy_read_timeout 3600;
    proxy_connect_timeout 3600;

{% if WEBLATE_ANUBIS_URL %}
    location ~ ^{{ WEBLATE_URL_PREFIX }}(/widget/|/exports/rss/|/healthz/|/hooks/|/accounts/complete/) {
        proxy_pass http://127.0.0.1:8081;
    }
{% endif %}

    location {{ WEBLATE_URL_PREFIX }}/ {
{% if WEBLATE_ANUBIS_URL %}
        auth_request /.within.website/x/cmd/anubis/api/check;
        error_page 401 = @redirectToAnubis;
{% endif %}
        proxy_pass http://127.0.0.1:8081;
    }
}

{% if WEBLATE_BUILTIN_SSL %}
server {
    listen 8080 default_server;
    server_tokens off;
    return 301 https://$host$request_uri;
}
{% endif %}
