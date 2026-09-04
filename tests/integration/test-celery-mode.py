import os
import subprocess
import sys


def run_container(*environment):
    image = os.environ.get("TEST_CONTAINER", "weblate/weblate:test")
    command = ["docker", "run", "--rm", "--env", "WEBLATE_SITE_DOMAIN="]
    for value in environment:
        command.extend(("--env", value))
    command.append(image)
    return subprocess.run(command, check=False, capture_output=True, text=True)


def require_output(result, expected):
    output = result.stdout + result.stderr
    if expected not in output:
        print(f"Missing {expected!r} in output:\n{output}", file=sys.stderr)
        return False
    return True


def main():
    invalid = run_container("CELERY_WORKER_MODE=invalid")
    if invalid.returncode == 0:
        print("Invalid CELERY_WORKER_MODE unexpectedly succeeded", file=sys.stderr)
        return 1
    if not require_output(invalid, "expected combined, split, or single"):
        return 1

    conflict = run_container(
        "CELERY_WORKER_MODE=combined",
        "CELERY_SINGLE_PROCESS=1",
        "CELERY_MAIN_OPTIONS=--concurrency 2",
    )
    if not require_output(
        conflict,
        "CELERY_SINGLE_PROCESS is deprecated and ignored because "
        "CELERY_WORKER_MODE is set",
    ):
        return 1
    if not require_output(
        conflict,
        "CELERY_WORKER_MODE=combined ignores split worker options: "
        "CELERY_MAIN_OPTIONS; use CELERY_COMBINED_OPTIONS",
    ):
        return 1

    single = run_container(
        "CELERY_WORKER_MODE=single", "CELERY_NOTIFY_OPTIONS=--concurrency 2"
    )
    if not require_output(
        single,
        "CELERY_WORKER_MODE=single ignores split worker options: "
        "CELERY_NOTIFY_OPTIONS; use CELERY_SINGLE_OPTIONS",
    ):
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
