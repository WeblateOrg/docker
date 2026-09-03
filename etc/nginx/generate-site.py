#!/usr/bin/env python3
import ipaddress
import re
import sys

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


def is_hostname(value: str) -> bool:
    value = value.removesuffix(".")
    return 0 < len(value) <= 253 and all(
        HOSTNAME_LABEL.fullmatch(label) for label in value.split(".")
    )


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
    TRUSTED_PROXY_ADDRESSES = parse_trusted_proxy_addresses(TRUSTED_PROXY_ADDRESSES_RAW)
except ValueError as error:
    sys.exit(str(error))

USE_X_FORWARDED_FOR = WEBLATE_IP_PROXY_HEADER == "HTTP_X_FORWARDED_FOR"

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
            "USE_X_FORWARDED_FOR": USE_X_FORWARDED_FOR,
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
