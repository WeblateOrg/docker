FROM debian:jessie
MAINTAINER Michal Čihař <michal@cihar.com>

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate

RUN apt-get update
RUN env DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ssh curl python-virtualenv python-lxml python-pillow python-psycopg2 python-mysqldb git mercurial

WORKDIR /app
RUN python -m virtualenv --system-site-packages .
ADD requirements.txt /tmp/requirements.txt
RUN bin/pip install -r /tmp/requirements.txt
RUN rm /tmp/requirements.txt

WORKDIR /tmp

RUN install -d -o weblate -g weblate -m 755 /app/data
RUN install -d -o root -g root -m 755 /app/etc
RUN cp /app/lib/python2.7/site-packages/weblate/settings_example.py /app/etc/settings.py
RUN ln -s /app/etc/settings.py /app/lib/python2.7/site-packages/weblate/settings.py
ENV DJANGO_SETTINGS_MODULE weblate.settings

VOLUME ["/app/etc", "/app/data"]
USER weblate

EXPOSE 8000
ENTRYPOINT ["/app/bin/django-admin"]
CMD ["runserver", "0.0.0.0:8000"]
