<a href="https://weblate.org/"><img alt="Weblate" src="https://s.weblate.org/cdn/Logo-Darktext-borders.png" height="80px" /></a>

**Weblate is libre software web-based continuous localization system,
used by over 2500 libre projects and companies in more than 165 countries.**

# Official Docker container for Weblate

[![Website](https://img.shields.io/badge/website-weblate.org-blue.svg)](https://weblate.org/)
[![Translation status](https://hosted.weblate.org/widgets/weblate/-/svg-badge.svg)](https://hosted.weblate.org/engage/weblate/?utm_source=widget)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/552/badge)](https://bestpractices.coreinfrastructure.org/projects/552)
[![Documentation](https://readthedocs.org/projects/weblate/badge/)][doc]

## Running Weblate

- [Weblate docker-compose](https://github.com/WeblateOrg/docker-compose)
- [OpenShift](https://docs.weblate.org/en/latest/admin/install/openshift.html)
- [Helm chart for Weblate](https://hub.helm.sh/charts/weblate/weblate)

## Exposed ports

The webserver is running on the port 8080.

## Reverse proxy addresses

When `WEBLATE_IP_PROXY_HEADER` is enabled, configure
`WEBLATE_TRUSTED_PROXY_ADDRESSES` with a whitespace-separated list of the IP
addresses, networks, or hostnames of reverse proxies allowed to supply client
addresses. The built-in nginx uses the resolved address both in its logs and
when forwarding the request to Weblate. With an empty list, it uses the
immediate TCP peer. Because nginx forwards a single normalized address, the
container uses an effective `WEBLATE_IP_PROXY_OFFSET` of `0` in this mode.

Specify the header using Django's request metadata format, for example
`HTTP_X_FORWARDED_FOR`, `HTTP_X_REAL_IP`, or `HTTP_CF_CONNECTING_IP`. nginx
converts this to the corresponding HTTP header name and forwards the normalized
client address in that header.

## Celery worker sizing

The default combined Celery pool targets three times `WEBLATE_WORKERS`, capped
by effective RAM capacity. Capacity is the smaller of host RAM and visible
cgroup memory limits (v1 or v2, including ancestors). Unlimited cgroups do not
increase the host capacity. This uses total capacity rather than fluctuating
free memory at startup, and excludes swap.

The cap reserves half the RAM for web workers and other services and budgets
512 MiB per Celery child, with a minimum concurrency of one. For example, with
two CPUs and a 4 GiB container limit, concurrency is four instead of six. A
nominal 4 GiB host can report slightly less usable RAM and select three.
This is a startup sizing heuristic, not protection against an unusually large
task or memory consumption by other applications.

Set `CELERY_COMBINED_OPTIONS`, for example `--concurrency 2`, to override this
calculation. `WEBLATE_WORKERS` still controls the CPU-based target but does not
bypass the memory cap. Split and single worker modes keep their existing
defaults. If memory information is unavailable, the CPU-based target is used.

## Documentation

Detailed documentation is available in [Weblate documentation][doc].

[doc]: https://docs.weblate.org/en/latest/admin/install/docker.html
