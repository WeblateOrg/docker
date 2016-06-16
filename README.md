# weblate-docker

[![Build Status](https://travis-ci.org/nijel/weblate-docker.svg?branch=master)](https://travis-ci.org/nijel/weblate-docker)

Docker container for Weblate

Documentation is available in Weblate documentation:

https://docs.weblate.org/en/latest/admin/deployments.html#docker

## Getting started

1. Create a `docker-compose.override.yml` file with your settings.

    weblate:
      ports:
        - "80:8000"
      environment:
        - WEBLATE_EMAIL_HOST=email.com
        - WEBLATE_EMAIL_HOST_USER=user
        - WEBLATE_EMAIL_HOST_PASSWORD=pass
        - WEBLATE_SECRET_KEY=something more secret
        - WEBLATE_ALLOWED_HOSTS=your hosts

2. Build the instances

    docker-compose build
    
3. Setup the environment

    docker-compose run weblate migrate
    docker-compose run weblate collectstatic
    docker-compose run weblate createadmin
    
4. Start up

    docker-compose up

## Maintenance tasks

There are some cron jobs to run. You should set `WEBLATE_OFFLOAD_INDEXING=1` when these are setup

    */5 * * * * cd /usr/share/weblate/; docker-compose run --rm weblate update_index
    @daily cd /usr/share/weblate/; docker-compose run --rm weblate cleanuptrans
    @hourly cd /usr/share/weblate-docker/; docker-compose run --rm weblate commit_pending --all --age=96
    
