# weblate-docker

[![Build Status](https://travis-ci.org/WeblateOrg/docker.svg?branch=master)](https://travis-ci.org/WeblateOrg/docker)

Docker container for Weblate

## Docker hub tags

You can use following tags on Docker hub:

* `latest` - latest stable release
* `edge` - bleeding edge docker image (contains stable Weblate, but the Docker image changes might not yet be fully tested)

## Documentation

Detailed documentation is available in Weblate documentation:

https://docs.weblate.org/en/latest/admin/deployments.html#docker

## Getting started

1. Create a `docker-compose.override.yml` file with your settings.

    ```yml
    version: '2'
    services:
      weblate:
        environment:
          - WEBLATE_EMAIL_HOST=smtp.example.com
          - WEBLATE_EMAIL_HOST_USER=user
          - WEBLATE_EMAIL_HOST_PASSWORD=pass
          - WEBLATE_ALLOWED_HOSTS=your hosts
          - WEBLATE_ADMIN_PASSWORD=password for admin user
    ```

2. Build the instances

        docker-compose build

3. Start up

        docker-compose up

4. For more detailed instructions visit https://docs.weblate.org/en/latest/admin/deployments.html#docker

## Maintenance tasks

There are some cron jobs to run. You should set `WEBLATE_OFFLOAD_INDEXING=1` when these are setup

    */5 * * * * cd /usr/share/weblate/; docker-compose run --rm weblate update_index
    @daily cd /usr/share/weblate/; docker-compose run --rm weblate cleanuptrans
    @hourly cd /usr/share/weblate-docker/; docker-compose run --rm weblate commit_pending --all --age=96

## Rebuilding the weblate docker image

The `docker-compose` files can be found in the `master` branch of https://github.com/WeblateOrg/docker.
The weblate docker image is built from the `docker` branch of https://github.com/WeblateOrg/docker.
