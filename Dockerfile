FROM ubuntu:14.10
MAINTAINER Wichert Akkerman <wichert@wiggy.net>

# Add user early to get a consistent userid
RUN useradd --shell /bin/sh --user-group weblate

RUN apt-get update
RUN env DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ssh curl python-virtualenv python-lxml python-pillow python-psycopg2 git

WORKDIR /app
RUN python -m virtualenv --system-site-packages .
ADD requirements.txt /tmp/requirements.txt
RUN bin/pip install -r /tmp/requirements.txt

WORKDIR /tmp

RUN install -d -o weblate -g weblate -m 755 /app/data
RUN install -d -o root -g root -m 755 /app/etc
RUN mv /app/lib/python2.7/site-packages/weblate/settings.py /app/etc
RUN ln -s /app/etc/settings.py /app/lib/python2.7/site-packages/weblate/settings.py
ENV DJANGO_SETTINGS_MODULE weblate.settings

VOLUME ["/app/etc", "/app/data"]
USER weblate

EXPOSE 8000
ENTRYPOINT ["/app/bin/django-admin"]
CMD ["runserver", "0.0.0.0:8000"]
