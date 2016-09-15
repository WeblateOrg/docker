FROM debian:jessie-backports
MAINTAINER Michal Čihař <michal@cihar.com>

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate

RUN env DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install --no-install-recommends -y ssh curl python-lxml python-pillow python-psycopg2 python-six python-memcache gettext postgresql-client \
  && apt-get install --no-install-recommends -y -t jessie-backports mercurial git python-django-compressor git-svn \
  && apt-get -y upgrade \
  && apt-get clean

WORKDIR /app
ADD requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt
RUN rm /tmp/requirements.txt

ADD settings.py /app/etc/
RUN chmod a+r /app/etc/settings.py
ADD start /app/bin/
RUN chmod a+rx /app/bin/start

WORKDIR /tmp

RUN install -d -o weblate -g weblate -m 755 /app/data
RUN ln -s /app/etc/settings.py /app/local/lib/python2.7/site-packages/weblate/settings.py
ENV DJANGO_SETTINGS_MODULE weblate.settings
ENV START_CMD "/app/bin/django-admin"

VOLUME ["/app/etc", "/app/data"]
USER weblate

EXPOSE 8000
ENTRYPOINT ["/app/bin/start"]
CMD ["runserver", "0.0.0.0:8000"]
