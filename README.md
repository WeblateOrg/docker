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

When `WEBLATE_IP_PROXY_HEADER=HTTP_X_FORWARDED_FOR` is enabled, configure
`WEBLATE_TRUSTED_PROXY_ADDRESSES` with a whitespace-separated list of the IP
addresses, networks, or hostnames of reverse proxies allowed to supply client
addresses. The built-in nginx uses the resolved address both in its logs and
when forwarding the request to Weblate. With an empty list, it uses the
immediate TCP peer. Because nginx forwards a single normalized address, the
container uses an effective `WEBLATE_IP_PROXY_OFFSET` of `0` in this mode.

## Documentation

Detailed documentation is available in [Weblate documentation][doc].

[doc]: https://docs.weblate.org/en/latest/admin/install/docker.html
