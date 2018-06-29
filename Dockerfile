FROM debian:stretch
MAINTAINER Michal Čihař <michal@cihar.com>
ENV VERSION 3.0.1
LABEL version=$VERSION

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate \
  && mkdir -p /home/weblate/.ssh \
  && touch /home/weblate/.ssh/authorized_keys \
  && chown -R weblate:weblate /home/weblate \
  && chmod 700 /home/weblate/.ssh \
  && install -d -o weblate -g weblate -m 755 /app/data

# Configure utf-8 locales
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

COPY requirements.txt crontab.txt /tmp/
COPY 0001-Invalidate-per-project-cache-on-start.patch 0002-Make-userdata-migration-keep-even-non-existing-langu.patch 0003-Allow-to-install-multi-addon-multiple-times.patch 0004-Remove-unique-constraint-on-addons.patch 0005-Fix-permission-check-for-auto-translate.patch /tmp/

# Install dependencies
RUN set -x && env DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get -y upgrade \
  && apt-get install --no-install-recommends -y \
    sudo \
    uwsgi \
    uwsgi-plugin-python3 \
    netcat-openbsd \
    nginx \
    supervisor \
    openssh-client \
    curl \
    python3-pip \
    python3-lxml \
    python3-yaml \
    python3-pillow \
    python3-setuptools \
    python3-wheel \
    python3-psycopg2 \
    python3-dateutil \
    python3-rcssmin \
    python3-rjsmin \
    python3-levenshtein \
    python3-hiredis \
    gettext \
    postgresql-client \
    mercurial \
    git \
    git-svn \
    subversion \
    python3-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libleptonica-dev \
    libtesseract-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    cython \
    gcc \
    g++ \
    tesseract-ocr \ 
    patch \
    cron \
  && pip3 install Weblate==$VERSION -r /tmp/requirements.txt \
  && crontab -u weblate /tmp/crontab.txt \
  && cd /usr/local/lib/python3.5/dist-packages/ \
  && patch -p1 < /tmp/0001-Invalidate-per-project-cache-on-start.patch \
  && patch -p1 < /tmp/0002-Make-userdata-migration-keep-even-non-existing-langu.patch \
  && patch -p1 < /tmp/0003-Allow-to-install-multi-addon-multiple-times.patch \
  && patch -p1 < /tmp/0004-Remove-unique-constraint-on-addons.patch \
  && patch -p1 < /tmp/0005-Fix-permission-check-for-auto-translate.patch \
  && ln -s /usr/local/share/weblate/examples/ /app/ \
  && rm -rf /root/.cache /tmp/* \
  && apt-get -y purge \
    python3-dev \
    libleptonica-dev \
    libtesseract-dev \
    libxml2-dev \
    libxmlsec1-dev \
    cython \
    patch \
    gcc \
    g++ \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
  && apt-get -y autoremove \
  && apt-get clean

# Hub
RUN curl -L https://github.com/github/hub/releases/download/v2.2.9/hub-linux-amd64-2.2.9.tgz | tar xzv --wildcards hub-linux*/bin/hub && \
  cp hub-linux-amd64-2.2.9/bin/hub /usr/bin && \
  rm -rf hub-linux-amd64-2.2.9

# Settings
COPY settings.py /app/etc/
RUN chmod a+r /app/etc/settings.py && \
  ln -s /app/etc/settings.py /usr/local/lib/python3.5/dist-packages/weblate/settings.py

# Configuration for nginx, uwsgi and supervisor
COPY weblate.nginx.conf /etc/nginx/sites-available/default
COPY weblate.uwsgi.ini /etc/uwsgi/apps-enabled/weblate.ini
COPY supervisor.conf /etc/supervisor/conf.d/

# Entrypoint
COPY start /app/bin/
RUN chmod a+rx /app/bin/start

ENV DJANGO_SETTINGS_MODULE weblate.settings

EXPOSE 80
ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
