#!/usr/bin/env python3
import json
import subprocess
import sys
import time

ATTEMPTS = 6
RETRY_DELAY = 5


def inspect_workers():
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "weblate",
            "/app/venv/bin/celery",
            "--app=weblate.utils",
            "inspect",
            "--timeout=10",
            "--json",
            "stats",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def validate_workers(stats, variant):
    workers = {name.partition("@")[0]: values for name, values in stats.items()}

    if variant == "celery-single":
        implementation = workers["celery"]["pool"]["implementation"]
        if "solo" not in implementation:
            raise AssertionError(f"expected solo pool, got {implementation}")
        return

    notify_concurrency = workers["notify"]["pool"]["max-concurrency"]
    if not 2 <= notify_concurrency <= 4:
        raise AssertionError(
            f"notify: expected auto-scaled concurrency from 2 to 4, "
            f"got {notify_concurrency}"
        )

    heavy_concurrency = (notify_concurrency + 1) // 2
    expected = {
        "celery": (heavy_concurrency, heavy_concurrency),
        "notify": (notify_concurrency, notify_concurrency * 4),
        "translate": (heavy_concurrency, heavy_concurrency),
        "memory": (1, 1),
        "backup": (1, 1),
    }

    for name, (concurrency, prefetch_count) in expected.items():
        worker = workers[name]
        pool = worker["pool"]
        implementation = pool["implementation"]
        if "prefork" not in implementation:
            raise AssertionError(f"{name}: expected prefork pool, got {implementation}")
        if pool["max-concurrency"] != concurrency:
            raise AssertionError(
                f"{name}: expected concurrency {concurrency}, "
                f"got {pool['max-concurrency']}"
            )
        if worker["prefetch_count"] != prefetch_count:
            raise AssertionError(
                f"{name}: expected prefetch count {prefetch_count}, "
                f"got {worker['prefetch_count']}"
            )


def main():
    variant = sys.argv[1] if len(sys.argv) > 1 else "basic"

    for attempt in range(1, ATTEMPTS + 1):
        try:
            validate_workers(inspect_workers(), variant)
        except (
            AssertionError,
            KeyError,
            json.JSONDecodeError,
            subprocess.CalledProcessError,
        ) as error:
            if attempt == ATTEMPTS:
                print(
                    f"Celery workers did not reach the expected configuration: {error}",
                    file=sys.stderr,
                )
                return 1
            time.sleep(RETRY_DELAY)
        else:
            return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
