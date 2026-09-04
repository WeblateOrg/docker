#!/usr/bin/env python3
import json
import subprocess
import sys
import time

ATTEMPTS = 6
RETRY_DELAY = 5
QUEUES = {"backup", "celery", "memory", "notify", "translate"}


def inspect_workers(command):
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
            command,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def validate_queues(active_queues, worker_name, expected=QUEUES):
    queues = {queue["name"] for queue in active_queues[worker_name]}
    if queues != expected:
        raise AssertionError(f"expected queues {expected}, got {queues}")


def validate_workers(stats, active_queues, variant):
    workers = {name.partition("@")[0]: values for name, values in stats.items()}
    worker_queues = {
        name.partition("@")[0]: values for name, values in active_queues.items()
    }

    if variant in {"celery-single", "celery-single-legacy"}:
        if workers.keys() != {"celery"}:
            raise AssertionError(f"expected one celery worker, got {workers.keys()}")
        implementation = workers["celery"]["pool"]["implementation"]
        if "solo" not in implementation:
            raise AssertionError(f"expected solo pool, got {implementation}")
        validate_queues(worker_queues, "celery")
        return

    if variant != "split":
        if workers.keys() != {"celery"}:
            raise AssertionError(f"expected one combined worker, got {workers.keys()}")
        worker = workers["celery"]
        pool = worker["pool"]
        implementation = pool["implementation"]
        if "prefork" not in implementation:
            raise AssertionError(f"expected prefork pool, got {implementation}")
        concurrency = pool["max-concurrency"]
        if variant == "celery-combined-options":
            if concurrency != 5:
                raise AssertionError(
                    f"expected overridden concurrency 5, got {concurrency}"
                )
        elif concurrency not in {6, 9, 12}:
            raise AssertionError(
                f"expected three times auto-scaled concurrency, got {concurrency}"
            )
        if worker["prefetch_count"] != concurrency:
            raise AssertionError(
                f"expected prefetch count {concurrency}, got {worker['prefetch_count']}"
            )
        validate_queues(worker_queues, "celery")
        return

    expected_names = {"backup", "celery", "memory", "notify", "translate"}
    if workers.keys() != expected_names:
        raise AssertionError(
            f"expected split workers {expected_names}, got {workers.keys()}"
        )
    for name in expected_names:
        validate_queues(worker_queues, name, {name})

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
            validate_workers(
                inspect_workers("stats"), inspect_workers("active_queues"), variant
            )
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
            if variant == "celery-single-legacy":
                logs = subprocess.run(
                    ["docker", "compose", "logs", "--no-color", "weblate"],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout
                warning = (
                    "CELERY_SINGLE_PROCESS is deprecated; "
                    "use CELERY_WORKER_MODE=single instead."
                )
                if warning not in logs:
                    print("Legacy Celery mode warning was not logged", file=sys.stderr)
                    return 1
            return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
