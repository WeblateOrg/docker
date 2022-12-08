FROM python:3.11.1-slim-bullseye
ENV PYVERSION 3.11
ENV VERSION 4.14.2
ENV WEBLATE_EXTRAS all,MySQL,zxcvbn
ARG TARGETARCH

LABEL name="Weblate"
LABEL version=$VERSION
LABEL maintainer="Michal Čihař <michal@cihar.com>"
LABEL org.opencontainers.image.url="https://weblate.org/"
LABEL org.opencontainers.image.documentation="https://docs.weblate.org/en/latest/admin/install/docker.html"
LABEL org.opencontainers.image.source="https://github.com/WeblateOrg/docker"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.vendor="Michal Čihař"
LABEL org.opencontainers.image.title="Weblate"
LABEL org.opencontainers.image.description="A web-based continuous localization system with tight version control integration"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

HEALTHCHECK --interval=30s --timeout=3s CMD /app/bin/health_check

SHELL ["/bin/bash", "-o", "pipefail", "-x", "-c"]

# Add user early to get a consistent userid
# - the root group so it can run with any uid
# - the tty group for /dev/std* access
# - see https://github.com/WeblateOrg/docker/issues/326 and https://github.com/moby/moby/issues/31243#issuecomment-406879017
# - create test and app data dirs to be able to run tests
RUN \
  useradd --shell /bin/sh --user-group weblate --groups root,tty \
  && mkdir -p /home/weblate/.ssh \
  && touch /home/weblate/.ssh/authorized_keys \
  && chown -R weblate:weblate /home/weblate \
  && chmod 700 /home/weblate/.ssh \
  && install -d -o weblate -g weblate -m 755 "/usr/local/lib/python${PYVERSION}/site-packages/data-test" "/usr/local/lib/python${PYVERSION}/site-packages/test-images" \
  && install -d -o weblate -g weblate -m 755 /app/data \
  && install -d -o weblate -g weblate -m 755 /app/cache

# Configure utf-8 locales to make sure Python
# correctly handles unicode filenames, configure settings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
# Home directory
ENV HOME=/home/weblate
# Use Docker specific settings
ENV DJANGO_SETTINGS_MODULE=weblate.settings_docker
# Avoid Python buffering stdout and delaying logs
ENV PYTHONUNBUFFERED=1

COPY requirements.txt patches /usr/src/weblate/

# Install dependencies
# hadolint ignore=DL3008,DL3013,SC2046
RUN \
  export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    nginx \
    openssh-client \
    ca-certificates \
    curl \
    gir1.2-pango-1.0 \
    libxmlsec1-openssl \
    libjpeg62-turbo \
    gettext \
    git \
    git-svn \
    gnupg \
    subversion \
    pkg-config \
    file \
    make \
    libcairo2-dev \
    libxml2-dev \
    libacl1-dev \
    libmariadb3 \
    libmariadb-dev \
    libxmlsec1-dev \
    libleptonica-dev \
    libtesseract-dev \
    libsasl2-dev \
    libldap2-dev \
    libldap-common \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    zlib1g-dev \
    libjpeg62-turbo-dev \
    libenchant-2-2 \
    libgirepository1.0-dev \
    libcairo-gobject2 \
    gcc \
    g++ \
    tesseract-ocr \
    patch \
    unzip \
    xz-utils \
  && c_rehash \
  && echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && curl -L https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update \
  && if apt-cache show postgresql-client-15 > /dev/null 2>&1 ; then \
        apt-get install --no-install-recommends -y postgresql-client-15 ; \
    else \
        apt-get install --no-install-recommends -y postgresql-client ; \
    fi \
  && pip install --no-cache-dir --upgrade $(grep -E '^(pip|wheel|setuptools)==' /usr/src/weblate/requirements.txt) \
  && pip install --no-cache-dir --no-binary :all: $(grep -E '^(cffi|lxml)==' /usr/src/weblate/requirements.txt) \
  && case "$VERSION" in \
    *+* ) \
      sed -Ei '/^(translate-toolkit|aeidon)/D' /usr/src/weblate/requirements.txt; \
      pip install \
        --no-cache-dir \
        -r /usr/src/weblate/requirements.txt \
        "https://github.com/translate/translate/archive/master.zip" \
        "https://github.com/WeblateOrg/language-data/archive/main.zip" \
        "https://github.com/WeblateOrg/weblate/archive/$WEBLATE_DOCKER_GIT_REVISION.zip#egg=Weblate[$WEBLATE_EXTRAS]" \
        ;; \
    * ) \
      pip install \
        --no-cache-dir \
        -r /usr/src/weblate/requirements.txt \
        "Weblate[$WEBLATE_EXTRAS]==$VERSION" \
      ;; \
  esac \
  && python -c 'from phply.phpparse import make_parser; make_parser()' \
  && ln -s /usr/local/share/weblate/examples/ /app/ \
  && apt-get -y purge \
    pkg-config \
    libleptonica-dev \
    libtesseract-dev \
    libmariadb-dev \
    libgirepository1.0-dev \
    libxml2-dev \
    libffi-dev \
    libxmlsec1-dev \
    libcairo2-dev \
    libpq-dev \
    gcc \
    g++ \
    file \
    make \
    libsasl2-dev \
    libacl1-dev \
    libldap2-dev \
    libssl-dev \
    libz-dev   \
    libjpeg62-turbo-dev \
  && apt-get -y purge --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean \
  && rm -rf /root/.cache /tmp/* /var/lib/apt/lists/*

# Apply hotfixes on Weblate
RUN find /usr/src/weblate -name '*.patch' -print0 | sort -z | \
  xargs -n1 -0 -r patch -p0 -d "/usr/local/lib/python${PYVERSION}/site-packages/" -i

# Configuration for Weblate, nginx and supervisor
COPY etc /etc/

# Fix permissions and adjust files to be able to edit them as user on start
# - localtime is needed for setting system timezone based on environment
# - timezone is removed to avoid dpkg handling localtime updates
# - we generate nginx configuration based on environment
# - autorize passwd edition so we can fix weblate uid on startup
# - log, run and home directories
# - disable su for non root to avoid privilege escapation by chaging /etc/passwd
RUN rm -f /etc/localtime /etc/timezone && cp /usr/share/zoneinfo/Etc/UTC /etc/localtime \
  && chgrp -R 0 /etc/nginx/sites-available/ /var/log/nginx/ /var/lib/nginx /app/data /app/cache /run /home/weblate /etc/localtime /etc/supervisor/conf.d \
  && chmod -R 770 /etc/nginx/sites-available/ /var/log/nginx/ /var/lib/nginx /app/data /app/cache /run /home /home/weblate /etc/localtime /etc/supervisor/conf.d \
  && chmod 664 /etc/passwd /etc/group \
  && sed -i '/pam_rootok.so/a auth requisite pam_deny.so' /etc/pam.d/su

# Search path for custom modules
RUN echo "/app/data/python" > "/usr/local/lib/python${PYVERSION}/site-packages/weblate-docker.pth"
RUN \
    mkdir -p /app/data/python/customize && \
    touch /app/data/python/customize/__init__.py && \
    touch /app/data/python/customize/models.py && \
    chown -R weblate:weblate /app/data/python

# Entrypoint
COPY start health_check /app/bin/
RUN chmod a+rx /app/bin/start

EXPOSE 8080
VOLUME /app/data
VOLUME /app/cache

# Numerical value is needed for OpenShift S2I, see
# https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html
USER 1000

ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
