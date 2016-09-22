# weblate-docker

[![Build Status](https://travis-ci.org/WeblateOrg/docker.svg?branch=master)](https://travis-ci.org/WeblateOrg/docker)

[![Docker Layers](https://images.microbadger.com/badges/image/nijel/weblate.svg)](https://microbadger.com/images/nijel/weblate "Get your own image badge on microbadger.com")

[![Docker Badge](https://images.microbadger.com/badges/version/nijel/weblate.svg)](https://microbadger.com/images/nijel/weblate "Get your own version badge on microbadger.com")

Docker container for Weblate

## Documentation

Detailed documentation is available in Weblate documentation:

https://docs.weblate.org/en/latest/admin/deployments.html#docker

## Getting started

1. Create a `docker-compose.override.yml` file with your settings.

    ```yml
    version: '2'
    services:
      weblate:
        ports:
          - "80:8000"
        environment:
          - WEBLATE_EMAIL_HOST=email.com
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
