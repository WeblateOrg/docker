#!/usr/bin/env python3
import ipaddress
import re
import sys
from urllib.parse import urlsplit

import django
from django.conf import settings

# Parse args
(
    TEMPLATE_DIRS,
    WEBLATE_URL_PREFIX,
    WEBLATE_IP_PROXY_HEADER,
    TRUSTED_PROXY_ADDRESSES_RAW,
    CLIENT_MAX_BODY_SIZE,
    WEBLATE_BUILTIN_SSL,
    WEBLATE_ANUBIS_URL,
    SITE_DOMAIN,
    ENABLE_HTTPS,
    GRANIAN_SOCKET,
    ENABLE_IPV6,
    EARLY_NGINX,
) = sys.argv[1:]


HOSTNAME_LABEL = re.compile(r"[A-Za-z0-9_](?:[A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?")
CLIENT_MAX_BODY_SIZE_PATTERN = re.compile(r"[0-9]+[kKmMgG]?")
URL_PREFIX_PATTERN = re.compile(r"(?:/[A-Za-z0-9_-]+)+")
ANUBIS_PATH_PATTERN = re.compile(r"(?:/[A-Za-z0-9_-]+)*/?")
NGINX_UNSAFE = re.compile(r"[\x00-\x20\x7f\s;{}#\"'`\\$]")

URL_PREFIX_EXPECTED = (
    'an empty value or slash-separated path segments beginning with "/" and '
    'containing only letters, digits, "_", or "-" '
    '(for example, "/tools/weblate")'
)
CLIENT_MAX_BODY_SIZE_EXPECTED = (
    'a non-negative integer with an optional k, m, or g suffix (for example, "200m")'
)
ANUBIS_URL_EXPECTED = (
    "an empty value or an http:// or https:// URL with a hostname or IPv4 address "
    "and an optional port and simple slash-separated path"
)
SITE_DOMAIN_EXPECTED = (
    "a hostname or IPv4 address with an optional port from 1 to 65535 "
    '(for example, "example.com:8080"); IPv6 is not supported'
)


def is_hostname(value: str) -> bool:
    value = value.removesuffix(".")
    return 0 < len(value) <= 253 and all(
        HOSTNAME_LABEL.fullmatch(label) for label in value.split(".")
    )


def invalid_value(name: str, expected: str) -> ValueError:
    return ValueError(f"Invalid {name}: expected {expected}")


def validate_nginx_value(value: str, name: str, expected: str) -> None:
    if NGINX_UNSAFE.search(value):
        raise invalid_value(name, expected)


def validate_url_prefix(value: str) -> str:
    if not value:
        return value

    if not URL_PREFIX_PATTERN.fullmatch(value):
        raise invalid_value("WEBLATE_URL_PREFIX", URL_PREFIX_EXPECTED)
    return value


def validate_client_max_body_size(value: str) -> str:
    if not CLIENT_MAX_BODY_SIZE_PATTERN.fullmatch(value):
        raise invalid_value("CLIENT_MAX_BODY_SIZE", CLIENT_MAX_BODY_SIZE_EXPECTED)
    return value


def validate_host(value: str) -> bool:
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return is_hostname(value)
    return address.version == 4


def validate_anubis_url(value: str) -> str:
    if not value:
        return value

    validate_nginx_value(value, "WEBLATE_ANUBIS_URL", ANUBIS_URL_EXPECTED)
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError:
        raise invalid_value("WEBLATE_ANUBIS_URL", ANUBIS_URL_EXPECTED) from None

    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.hostname
        or not validate_host(parsed.hostname)
        or parsed.username is not None
        or parsed.password is not None
        or not ANUBIS_PATH_PATTERN.fullmatch(parsed.path)
        or parsed.query
        or parsed.fragment
        or (port is not None and not 1 <= port <= 65535)
    ):
        raise invalid_value("WEBLATE_ANUBIS_URL", ANUBIS_URL_EXPECTED)
    return value


def validate_site_domain(value: str) -> str:
    validate_nginx_value(value, "WEBLATE_SITE_DOMAIN", SITE_DOMAIN_EXPECTED)
    if not value or value.count(":") > 1 or any(char in value for char in "/@?[]"):
        raise invalid_value("WEBLATE_SITE_DOMAIN", SITE_DOMAIN_EXPECTED)

    host, separator, port_text = value.rpartition(":")
    if not separator:
        host = value
    elif not host or not port_text.isdecimal() or not 1 <= int(port_text) <= 65535:
        raise invalid_value("WEBLATE_SITE_DOMAIN", SITE_DOMAIN_EXPECTED)

    if not validate_host(host):
        raise invalid_value("WEBLATE_SITE_DOMAIN", SITE_DOMAIN_EXPECTED)
    return value


def parse_trusted_proxy_addresses(value: str) -> list[str]:
    result = []
    for address in value.split():
        try:
            if "/" in address:
                ipaddress.ip_network(address, strict=True)
            else:
                ipaddress.ip_address(address)
        except ValueError:
            if not is_hostname(address):
                raise ValueError(
                    f"Invalid trusted proxy address: {address!r}"
                ) from None
        result.append(address)
    return result


try:
    WEBLATE_URL_PREFIX = validate_url_prefix(WEBLATE_URL_PREFIX)
    CLIENT_MAX_BODY_SIZE = validate_client_max_body_size(CLIENT_MAX_BODY_SIZE)
    WEBLATE_ANUBIS_URL = validate_anubis_url(WEBLATE_ANUBIS_URL)
    SITE_DOMAIN = validate_site_domain(SITE_DOMAIN)
    TRUSTED_PROXY_ADDRESSES = parse_trusted_proxy_addresses(TRUSTED_PROXY_ADDRESSES_RAW)
except ValueError as error:
    sys.exit(str(error))

if WEBLATE_IP_PROXY_HEADER and not re.fullmatch(
    r"HTTP_[A-Za-z0-9_-]+", WEBLATE_IP_PROXY_HEADER
):
    sys.exit(f"Invalid proxy header: {WEBLATE_IP_PROXY_HEADER!r}")
IP_PROXY_HEADER = (
    WEBLATE_IP_PROXY_HEADER.removeprefix("HTTP_").replace("_", "-").title()
)

WEBLATE_SITE_URL = "{}://{}".format(
    "https"
    if ENABLE_HTTPS and ENABLE_HTTPS.lower() not in {"0", "false", "no", "off"}
    else "http",
    SITE_DOMAIN,
)

# Configure Django
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [TEMPLATE_DIRS],
    }
]
settings.configure(TEMPLATES=TEMPLATES)
django.setup()

# Now we can use templates
from django.template.loader import get_template

template = get_template("default.tpl")
print(
    template.render(
        {
            "WEBLATE_URL_PREFIX": WEBLATE_URL_PREFIX,
            "IP_PROXY_HEADER": IP_PROXY_HEADER,
            "TRUSTED_PROXY_ADDRESSES": TRUSTED_PROXY_ADDRESSES,
            "CLIENT_MAX_BODY_SIZE": CLIENT_MAX_BODY_SIZE,
            "WEBLATE_BUILTIN_SSL": WEBLATE_BUILTIN_SSL,
            "WEBLATE_ANUBIS_URL": WEBLATE_ANUBIS_URL,
            "WEBLATE_SITE_URL": WEBLATE_SITE_URL,
            "GRANIAN_SOCKET": GRANIAN_SOCKET,
            "ENABLE_IPV6": ENABLE_IPV6,
            "EARLY_NGINX": EARLY_NGINX,
        }
    )
)
