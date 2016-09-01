# weblate-docker

[![Build Status](https://travis-ci.org/WeblateOrg/docker.svg?branch=master)](https://travis-ci.org/WeblateOrg/docker)

[![Docker Layers](https://images.microbadger.com/badges/image/nijel/weblate.svg)](http://microbadger.com/images/nijel/weblate "Get your own image badge on microbadger.com")

[![Docker Badge](https://images.microbadger.com/badges/version/nijel/weblate.svg)](http://microbadger.com/images/nijel/weblate "Get your own version badge on microbadger.com")

Docker container for Weblate

Documentation is available in Weblate documentation:

https://docs.weblate.org/en/latest/admin/deployments.html#docker

## Getting started

1. Create a `docker-compose.override.yml` file with your settings.
See [weblate/environment]() for a full list of environment vars

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

        docker-compose run --rm weblate migrate
        docker-compose run --rm weblate collectstatic
        docker-compose run --rm weblate createadmin
    
4. Start up

        docker-compose up

## Maintenance tasks

There are some cron jobs to run. You should set `WEBLATE_OFFLOAD_INDEXING=1` when these are setup

    */5 * * * * cd /usr/share/weblate/; docker-compose run --rm weblate update_index
    @daily cd /usr/share/weblate/; docker-compose run --rm weblate cleanuptrans
    @hourly cd /usr/share/weblate-docker/; docker-compose run --rm weblate commit_pending --all --age=96
    
