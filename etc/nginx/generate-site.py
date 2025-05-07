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
) = sys.argv[1:]

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
        }
    )
)
