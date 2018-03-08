FROM debian:stretch
MAINTAINER Michal Čihař <michal@cihar.com>
ENV VERSION 2.19.1
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

ADD requirements.txt /tmp/requirements.txt

# Install dependencies
RUN set -x && env DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get -y upgrade \
  && apt-get install --no-install-recommends -y \
    sudo \
    uwsgi \
    uwsgi-plugin-python \
    netcat-openbsd \
    nginx \
    supervisor \
    openssh-client \
    curl \
    python-pip \
    python-lxml \
    python-yaml \
    python-pillow \
    python-setuptools \
    python-wheel \
    python-psycopg2 \
    python-dateutil \
    python-rcssmin \
    python-rjsmin \
    python-django-auth-ldap \
    python-mysqldb \
    gettext \
    postgresql-client \
    mysql-client \
    mercurial \
    git \
    git-svn \
    subversion \
    python-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libleptonica-dev \
    libtesseract-dev \
    cython \
    gcc \
    g++ \
    tesseract-ocr \
  && pip install Weblate==$VERSION -r /tmp/requirements.txt \
  && ln -s /usr/local/share/weblate/examples/ /app/ \
  && rm /tmp/requirements.txt \
  && rm -rf /root/.cache \
  && apt-get -y purge python-dev libleptonica-dev libtesseract-dev libxml2-dev libxmlsec1-dev cython gcc g++ \
  && apt-get -y autoremove \
  && apt-get clean

# Hub
RUN curl -L https://github.com/github/hub/releases/download/v2.2.9/hub-linux-amd64-2.2.9.tgz | tar xzv --wildcards hub-linux*/bin/hub && \
  cp hub-linux-amd64-2.2.9/bin/hub /usr/bin && \
  rm -rf hub-linux-amd64-2.2.9

# Settings
ADD settings.py /app/etc/
RUN chmod a+r /app/etc/settings.py && \
  ln -s /app/etc/settings.py /usr/local/lib/python2.7/dist-packages/weblate/settings.py

# Configuration for nginx, uwsgi and supervisor
COPY weblate.nginx.conf /etc/nginx/sites-available/default
COPY weblate.uwsgi.ini /etc/uwsgi/apps-enabled/weblate.ini
COPY supervisor.conf /etc/supervisor/conf.d/

# Entrypoint
ADD start /app/bin/
RUN chmod a+rx /app/bin/start

ENV DJANGO_SETTINGS_MODULE weblate.settings

EXPOSE 80
ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
