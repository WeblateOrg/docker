#!/usr/bin/env python3
import django
import sys
from django.conf import settings

# Parse args
(
    TEMPLATE_DIRS,
    WEBLATE_URL_PREFIX,
    WEBLATE_REALIP,
    CLIENT_MAX_BODY_SIZE,
    WEBLATE_BUILTIN_SSL,
    WEBLATE_ANUBIS_URL,
    SITE_DOMAIN,
    ENABLE_HTTPS,
) = sys.argv[1:]

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
from django.template.loader import get_template  # noqa: E402

template = get_template("default.tpl")
print(
    template.render(
        {
            "WEBLATE_URL_PREFIX": WEBLATE_URL_PREFIX,
            "WEBLATE_REALIP": WEBLATE_REALIP,
            "CLIENT_MAX_BODY_SIZE": CLIENT_MAX_BODY_SIZE,
            "WEBLATE_BUILTIN_SSL": WEBLATE_BUILTIN_SSL,
            "WEBLATE_ANUBIS_URL": WEBLATE_ANUBIS_URL,
            "WEBLATE_SITE_URL": WEBLATE_SITE_URL,
        }
    )
)
