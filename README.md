<a href="https://weblate.org/"><img alt="Weblate" src="https://s.weblate.org/cdn/Logo-Darktext-borders.png" height="80px" /></a>

**Weblate is a copylefted libre software web-based continuous localization system,
used by over 2500 libre projects and companies in more than 165 countries.**

# Official Docker container for Weblate

[![Website](https://img.shields.io/badge/website-weblate.org-blue.svg)](https://weblate.org/)
[![Translation status](https://hosted.weblate.org/widgets/weblate/-/svg-badge.svg)](https://hosted.weblate.org/engage/weblate/?utm_source=widget)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/552/badge)](https://bestpractices.coreinfrastructure.org/projects/552)
[![Docker Layers](https://images.microbadger.com/badges/image/weblate/weblate.svg)](https://microbadger.com/images/weblate/weblate "Get your own image badge on microbadger.com")
[![Documenation][doc]

## Running Weblate

- [Weblate docker-compose](https://github.com/WeblateOrg/docker-compose)
- [OpenShift](https://docs.weblate.org/en/latest/admin/install/openshift.html)
- [Helm chart for Weblate](https://hub.helm.sh/charts/weblate/weblate)

## Exposed ports

In July 2019 (starting with the 3.7.1-6 tag), the containers is not running as
root. As a consequence this has lead to changed exposed port from 80 to 8080.

## Documentation

Detailed documentation is available in [Weblate documentation][doc].

[doc]: https://docs.weblate.org/en/latest/admin/install/docker.html
