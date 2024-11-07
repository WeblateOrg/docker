FROM weblate/dev:2024.45.5 AS build

ARG TARGETARCH

ENV WEBLATE_VERSION=5.8.3
ENV WEBLATE_EXTRAS=all,MySQL,zxcvbn

SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]

COPY --link requirements.txt /app/src/

# Install dependencies
# hadolint ignore=DL3008,DL3013,SC2046,DL3003
RUN --mount=type=cache,target=/.uv-cache \
  export UV_CACHE_DIR=/.uv-cache UV_LINK_MODE=copy \
  && uv venv /app/venv \
  && . /app/venv/bin/activate \
  && case "$WEBLATE_VERSION" in \
    *+* ) \
      uv pip install \
        --compile-bytecode \
        -r /app/src/requirements.txt \
        "https://github.com/translate/translate/archive/master.zip" \
        "https://github.com/WeblateOrg/language-data/archive/main.zip" \
        "https://github.com/WeblateOrg/weblate/archive/$WEBLATE_DOCKER_GIT_REVISION.zip#egg=Weblate[$WEBLATE_EXTRAS]" \
        ;; \
    * ) \
      uv pip install \
        --compile-bytecode \
        -r /app/src/requirements.txt \
        "Weblate[$WEBLATE_EXTRAS]==$WEBLATE_VERSION" \
      ;; \
  esac \
  && uv cache prune --ci
RUN /app/venv/bin/python -c 'from phply.phpparse import make_parser; make_parser()'
RUN ln -s /app/venv/share/weblate/examples/ /app/


FROM weblate/base:2024.45.5 AS final

ENV WEBLATE_VERSION=5.8.3

LABEL name="Weblate"
LABEL version=$WEBLATE_VERSION
LABEL maintainer="Michal Čihař <michal@cihar.com>"
LABEL org.opencontainers.image.url="https://weblate.org/"
LABEL org.opencontainers.image.documentation="https://docs.weblate.org/en/latest/admin/install/docker.html"
LABEL org.opencontainers.image.source="https://github.com/WeblateOrg/docker"
LABEL org.opencontainers.image.version=$WEBLATE_VERSION
LABEL org.opencontainers.image.author="Michal Čihař <michal@weblate.org>"
LABEL org.opencontainers.image.vendor="Weblate"
LABEL org.opencontainers.image.title="Weblate"
LABEL org.opencontainers.image.description="A web-based continuous localization system with tight version control integration"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# Increased start period for migrations run
HEALTHCHECK --interval=30s --timeout=3s --start-period=5m CMD /app/bin/health_check

# Use Docker specific settings
ENV DJANGO_SETTINGS_MODULE=weblate.settings_docker

# Copy built environment
COPY --from=build /app /app

# Configuration for Weblate, nginx and supervisor
COPY --link etc /etc/

# Fix permissions and adjust files to be able to edit them as user on start
# - localtime is needed for setting system timezone based on environment
# - timezone is removed to avoid dpkg handling localtime updates
# - we generate nginx configuration based on environment
# - autorize passwd edition so we can fix weblate uid on startup
# - log, run and home directories
# - disable su for non root to avoid privilege escapation by chaging /etc/passwd
RUN rm -f /etc/localtime /etc/timezone \
  && ln -s /tmp/localtime /etc/localtime \
  && cp /usr/share/zoneinfo/Etc/UTC /tmp/localtime \
  && mkdir /tmp/nginx \
  && chgrp -R 0 /var/log/nginx/ /var/lib/nginx /app/data /app/cache /run /home/weblate /tmp/localtime /tmp/nginx /etc/supervisor/conf.d \
  && chmod -R 770 /var/log/nginx/ /var/lib/nginx /app/data /app/cache /run /home /home/weblate /tmp/localtime /tmp/nginx /etc/supervisor/conf.d \
  && rm -f /etc/nginx/sites-available/default \
  && ln -s /tmp/nginx/weblate-site.conf /etc/nginx/sites-available/default \
  && rm -f /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && chmod 664 /etc/passwd /etc/group \
  && sed -i '/pam_rootok.so/a auth requisite pam_deny.so' /etc/pam.d/su

# Customize Python:
# - Search path for custom modules
RUN \
    echo "/app/data/python" > "/app/venv/lib/python${PYVERSION}/site-packages/weblate-docker.pth" && \
    mkdir -p /app/data/python/customize && \
    touch /app/data/python/customize/__init__.py && \
    touch /app/data/python/customize/models.py && \
    chown -R weblate:weblate /app/data/python

# Entrypoint
COPY --link --chmod=0755 start health_check /app/bin/

EXPOSE 8080
VOLUME /app/data
VOLUME /app/cache
VOLUME /tmp
VOLUME /run

# Numerical value is needed for OpenShift S2I, see
# https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html
USER 1000

ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
