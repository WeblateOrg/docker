#!/bin/sh

# Simple test that Weblate is serving it's files
# Execute in docker-compose.yml directory

echo "Starting up containers..."
docker-compose up -d || exit 1
CONTAINER=`docker-compose ps | grep _weblate_ | sed 's/[[:space:]].*//'`
IP=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER`
echo "Checking '$CONTAINER', IP address '$IP'"
TIMEOUT=0; while ! curl --fail --silent --output /dev/null "http://$IP/" ; do sleep 1 ; TIMEOUT=$(($TIMEOUT + 1)); if [ $TIMEOUT -gt 60 ] ; then break ;fi ; done
curl --fail "http://$IP/about/" | grep 'Powered by.*Weblate'
RET=$?
curl --fail --output /dev/null "http://$IP/static/weblate-128.png"
if [ $? -ne 0 -o $RET -ne 0 ] ; then
    docker-compose logs
    exit 1
fi
echo "Shutting down containers..."
docker-compose down

echo "Runing testsuite..."
docker-compose run -e WEBLATE_LOGLEVEL=CRITICAL --rm weblate test --noinput weblate.accounts weblate.trans weblate.lang weblate.api weblate.gitexport weblate.screenshots weblate.utils || exit 1

echo "Creating admin..."
docker-compose run --rm weblate createadmin || exit 1
