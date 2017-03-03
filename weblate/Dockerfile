FROM debian:stretch
MAINTAINER Michal Čihař <michal@cihar.com>
ENV VERSION 2.11
LABEL version=$VERSION

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate \
  && mkdir -p /home/weblate/.ssh \
  && touch /home/weblate/.ssh/authorized_keys \
  && chown -R weblate:weblate /home/weblate \
  && chmod 700 /home/weblate/.ssh

RUN install -d -o weblate -g weblate -m 755 /app/data

ADD requirements.txt /tmp/requirements.txt

# Install dependencies
RUN env DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install --no-install-recommends -y ssh curl python-pip python-lxml python-yaml python-pillow python-psycopg2 python-memcache python-dateutil python-rcssmin python-rjsmin gettext postgresql-client mercurial git git-svn subversion \
  && apt-get -y upgrade \
  && pip install -r /tmp/requirements.txt \
  && rm /tmp/requirements.txt \
  && apt-get -y purge python-pip \
  && apt-get clean

# Hub
RUN curl -L https://github.com/github/hub/releases/download/v2.2.9/hub-linux-amd64-2.2.9.tgz | tar xzv --wildcards hub-linux*/bin/hub && \
  cp hub-linux-amd64-2.2.9/bin/hub /usr/bin && \
  rm -rf hub-linux-amd64-2.2.9/bin/hub

# Examples
RUN curl https://dl.cihar.com/weblate/Weblate-$VERSION.tar.gz | tar xzf - --strip-components=1 --no-same-owner -C /app Weblate-$VERSION/examples

# Settings
ADD settings.py /app/etc/
RUN chmod a+r /app/etc/settings.py

# Entrypoint
ADD start /app/bin/
RUN chmod a+rx /app/bin/start

RUN ln -s /app/etc/settings.py /usr/local/lib/python2.7/dist-packages/weblate/settings.py
ENV DJANGO_SETTINGS_MODULE weblate.settings
ENV START_CMD "/usr/local/bin/django-admin"

VOLUME ["/app/etc", "/app/data"]
USER weblate

EXPOSE 8000
ENTRYPOINT ["/app/bin/start"]
CMD ["runserver", "0.0.0.0:8000"]
