FROM debian:10.5-slim
ENV VERSION 4.2.2
ARG TARGETARCH

LABEL name="Weblate"
LABEL version=$VERSION
LABEL maintainer="Michal Čihař <michal@cihar.com>"
LABEL org.opencontainers.image.url="https://weblate.org/"
LABEL org.opencontainers.image.source="https://github.com/WeblateOrg/docker"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.vendor="Michal Čihař"
LABEL org.opencontainers.image.title="Weblate"
LABEL org.opencontainers.image.description="A web-based continuous localization system with tight version control integration"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

HEALTHCHECK --interval=5m --timeout=3s CMD /app/bin/health_check

# Add user early to get a consistent userid
# - the root group so it can run with any uid
# - the tty group for /dev/std* access
# - see https://github.com/WeblateOrg/docker/issues/326 and https://github.com/moby/moby/issues/31243#issuecomment-406879017
# - create test and app data dirs to be able to run tests
RUN set -o pipefail -x \
  && useradd --shell /bin/sh --user-group weblate --groups root,tty \
  && mkdir -p /home/weblate/.ssh \
  && touch /home/weblate/.ssh/authorized_keys \
  && chown -R weblate:weblate /home/weblate \
  && chmod 700 /home/weblate/.ssh \
  && install -d -o weblate -g weblate -m 755 /usr/local/lib/python3.7/dist-packages/data-test /usr/local/lib/python3.7/dist-packages/test-images \
  && install -d -o weblate -g weblate -m 755 /app/data

# Configure utf-8 locales to make sure Python
# correctly handles unicode filenames, configure settings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
# Home directory
ENV HOME=/home/weblate
# Use Docker specific settings
ENV DJANGO_SETTINGS_MODULE=weblate.settings_docker

COPY requirements.txt patches /usr/src/weblate/

# Install dependencies
RUN set -o pipefail -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    uwsgi \
    uwsgi-plugin-python3 \
    nginx \
    openssh-client \
    ca-certificates \
    curl \
    gir1.2-pango-1.0 \
    libxmlsec1-openssl \
    libjpeg62-turbo \
    python3-gi \
    python3-gi-cairo \
    python3-cairo \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-gdbm \
    gettext \
    postgresql-common \
    git \
    git-svn \
    gnupg \
    subversion \
    pkg-config \
    python3-dev \
    file \
    make \
    libxml2-dev \
    libacl1-dev \
    libmariadb-dev \
    libxmlsec1-dev \
    libleptonica-dev \
    libtesseract-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    libz-dev \
    libjpeg62-turbo-dev \
    libenchant1c2a \
    gcc \
    g++ \
    tesseract-ocr \
    patch \
  && echo | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh \
  && apt-get update \
  && if apt-cache show postgresql-client-12 > /dev/null 2>&1 ; then \
        apt-get install --no-install-recommends -y postgresql-client-12 ; \
    else \
        apt-get install --no-install-recommends -y postgresql-client ; \
    fi \
  && python3 -m pip install --upgrade pip \
  && python3 -m pip install "Weblate[all,MySQL]==$VERSION" -r /usr/src/weblate/requirements.txt \
  && python3 -c 'from phply.phpparse import make_parser; make_parser()' \
  && ln -s /usr/local/share/weblate/examples/ /app/ \
  && apt-get -y purge \
    python3-dev \
    pkg-config \
    libleptonica-dev \
    libtesseract-dev \
    libmariadb-dev \
    libxml2-dev \
    libffi-dev \
    libxmlsec1-dev \
    libpq-dev \
    cython \
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
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /root/.cache /tmp/* /var/lib/apt/lists/*

# Apply hotfixes on Weblate
RUN set -o pipefail -x \
  && find /usr/src/weblate -name '*.patch' -print0 | sort -z | \
  xargs -n1 -0 -r patch -p0 -d /usr/local/lib/python3.7/dist-packages/ -i

# Install Hub
RUN set -o pipefail -x \
  && curl --cacert /etc/ssl/certs/ca-certificates.crt -L https://github.com/github/hub/releases/download/v2.13.0/hub-linux-${TARGETARCH:-amd64}-2.13.0.tgz | tar xzv --wildcards hub-linux*/bin/hub && \
  cp hub-linux-*/bin/hub /usr/bin && \
  rm -rf hub-linux-*

# Install Lab
RUN set -o pipefail -x \
  && if [ ${TARGETARCH:-amd64} = "amd64" ] ; then  \
  curl --cacert /etc/ssl/certs/ca-certificates.crt -L "https://github.com/zaquestion/lab/releases/download/v0.17.2/lab_0.17.2_linux_${TARGETARCH:-amd64}.tar.gz" | tar -C /tmp/ -xzf - \
  && mv /tmp/lab /usr/bin \
  && chmod u+x /usr/bin/lab ; \
  fi

# Configuration for Weblate, nginx, uwsgi and supervisor
COPY etc /etc/

# Fix permissions and adjust files to be able to edit them as user on start
# - localtime/timezone is needed for setting system timezone based on environment
# - we generate nginx configuration based on environment
# - autorize passwd edition so we can fix weblate uid on startup
# - log, run and home directories
# - disable su for non root to avoid privilege escapation by chaging /etc/passwd
RUN set -o pipefail -x \
  && rm -f /etc/localtime && cp /usr/share/zoneinfo/Etc/UTC /etc/localtime \
  && chgrp -R 0 /etc/nginx/sites-available/ /var/log/nginx/ /var/lib/nginx /app/data /run /home/weblate /etc/timezone /etc/localtime \
  && chmod -R 770 /etc/nginx/sites-available/ /var/log/nginx/ /var/lib/nginx /app/data /run /home /home/weblate /etc/timezone /etc/localtime \
  && chmod 664 /etc/passwd /etc/group \
  && sed -i '/pam_rootok.so/a auth requisite pam_deny.so' /etc/pam.d/su

# Search path for custom modules
RUN echo "/app/data/python" > /usr/local/lib/python3.7/dist-packages/weblate-docker.pth

# Entrypoint
COPY start health_check /app/bin/
RUN chmod a+rx /app/bin/start

EXPOSE 8080 4443

# Numerical value is needed for OpenShift S2I, see
# https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html
USER 1000

ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
