FROM debian:buster-slim
MAINTAINER Michal Čihař <michal@cihar.com>
ENV VERSION 3.6.1
LABEL version=$VERSION

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate \
  && mkdir -p /home/weblate/.ssh \
  && touch /home/weblate/.ssh/authorized_keys \
  && chown -R weblate:weblate /home/weblate \
  && chmod 700 /home/weblate/.ssh \
  && install -d -o weblate -g weblate -m 755 /usr/local/lib/python3.7/dist-packages/data-test \
  && install -d -o weblate -g weblate -m 755 /app/data

# Configure utf-8 locales to make sure Python
# correctly handles unicode filenames
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

COPY requirements.txt patches /usr/src/weblate/

# Install dependencies
RUN set -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
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
    python3-gdbm \
    python3-psycopg2 \
    python3-rcssmin \
    python3-rjsmin \
    gettext \
    postgresql-client \
    mercurial \
    git \
    git-svn \
    subversion \
    pkg-config \
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
  && pip3 install Weblate==$VERSION -r /usr/src/weblate/requirements.txt \
  && python3 -c 'from phply.phpparse import make_parser; make_parser()' \
  && ln -s /usr/local/share/weblate/examples/ /app/ \
  && rm -rf /root/.cache /tmp/* \
  && apt-get -y purge \
    python3-dev \
    pkg-config \
    libleptonica-dev \
    libtesseract-dev \
    libxml2-dev \
    libxmlsec1-dev \
    cython \
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

# Configuration for Weblate, nginx, uwsgi and supervisor
COPY etc /etc/
RUN chmod a+r /etc/weblate/settings.py && \
  ln -s /etc/weblate/settings.py /usr/local/lib/python3.7/dist-packages/weblate/settings.py

# Apply hotfixes
RUN find /usr/src/weblate -name '*.patch' -print0 | \
    xargs -n1 -0 -r patch -p1 -d /usr/local/lib/python3.7/dist-packages/ -i

# Entrypoint
COPY start /app/bin/
RUN chmod a+rx /app/bin/start

EXPOSE 80
ENTRYPOINT ["/app/bin/start"]
CMD ["runserver"]
