#!/usr/bin/env python3
"""Exercise memory detection and startup sizing without starting the image."""

import os
import runpy
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEMORY_CAPACITY = runpy.run_path(str(ROOT / "memory_limit.py"))["memory_capacity"]
GIB = 1024**3


class MemoryCapacityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.proc = self.root / "proc"
        self.write(self.proc / "meminfo", f"MemTotal: {8 * GIB // 1024} kB\n")

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(str(content))

    def cgroup(self, version="cgroup2", group="/child", root="/"):
        mount = self.root / "cgroup space"
        escaped = str(mount).replace(" ", r"\040")
        membership = "0::" if version == "cgroup2" else "4:memory:"
        self.write(self.proc / "self/cgroup", membership + group)
        self.write(
            self.proc / "self/mountinfo",
            f"1 0 0:1 {root} {escaped} rw - {version} cgroup rw,memory\n",
        )
        return mount

    def test_host_without_cgroups(self):
        self.assertEqual(MEMORY_CAPACITY(self.proc), 8192)

    def test_v2_inherited_limit(self):
        mount = self.cgroup()
        self.write(mount / "child/memory.max", 6 * GIB)
        self.write(mount / "memory.max", 4 * GIB)
        self.assertEqual(MEMORY_CAPACITY(self.proc), 4096)

    def test_private_namespace(self):
        mount = self.cgroup(group="/", root="/docker/container")
        self.write(mount / "memory.max", 2 * GIB)
        self.assertEqual(MEMORY_CAPACITY(self.proc), 2048)

    def test_subtree_mount(self):
        mount = self.cgroup(group="/docker/container/child", root="/docker/container")
        self.write(mount / "child/memory.max", GIB)
        self.assertEqual(MEMORY_CAPACITY(self.proc), 1024)

    def test_unlimited_or_malformed_limit(self):
        mount = self.cgroup()
        for value in ("max", "invalid", 16 * GIB):
            with self.subTest(value=value):
                self.write(mount / "child/memory.max", value)
                self.assertEqual(MEMORY_CAPACITY(self.proc), 8192)

    def test_v1_limit_and_unlimited_sentinel(self):
        mount = self.cgroup(version="cgroup")
        self.write(mount / "memory.limit_in_bytes", 9223372036854771712)
        self.write(mount / "child/memory.limit_in_bytes", 4 * GIB)
        self.assertEqual(MEMORY_CAPACITY(self.proc), 4096)

    def test_missing_information(self):
        self.assertIsNone(MEMORY_CAPACITY(self.root / "missing"))

    def test_zero_limit(self):
        mount = self.cgroup()
        self.write(mount / "memory.max", 0)
        self.assertEqual(MEMORY_CAPACITY(self.proc), 0)


class WorkerSizingTest(unittest.TestCase):
    def calculate(self, memory, cpus=2, **overrides):
        source = (ROOT / "start").read_text()
        function = source.split("calculate_worker_defaults() {", 1)[1].split(
            "\nstart_supervisord() {", 1
        )[0]
        script = (
            "set -e\ncalculate_worker_defaults() {"
            + function
            + '\nnproc() { echo "$TEST_CPUS"; }\n'
            + 'python() { echo "$TEST_MEMORY"; }\n'
            + 'calculate_worker_defaults\nprintf "%s\\n" "$CELERY_COMBINED_OPTIONS"'
        )
        result = subprocess.run(
            ["bash", "-c", script],
            env={
                "PATH": os.defpath,
                "TEST_CPUS": str(cpus),
                "TEST_MEMORY": str(memory),
                **overrides,
            },
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.splitlines()[-1]

    def test_memory_cap(self):
        for memory, expected in ((0, 1), (512, 1), (2048, 2), (4096, 4), (8192, 6)):
            with self.subTest(memory=memory):
                self.assertEqual(self.calculate(memory), f"--concurrency {expected}")

    def test_cpu_target_preserved(self):
        self.assertEqual(self.calculate(32768, cpus=4), "--concurrency 12")

    def test_missing_memory(self):
        self.assertEqual(self.calculate(""), "--concurrency 6")

    def test_explicit_options(self):
        self.assertEqual(
            self.calculate(2048, CELERY_COMBINED_OPTIONS="--concurrency 5"),
            "--concurrency 5",
        )

    def test_worker_target_still_capped(self):
        self.assertEqual(self.calculate(4096, WEBLATE_WORKERS="8"), "--concurrency 4")

    def test_dedicated_combined_service(self):
        self.assertEqual(
            self.calculate(4096, WEBLATE_SERVICE="celery-combined"), "--concurrency 4"
        )

    def test_other_modes_unchanged(self):
        for mode in ("split", "single"):
            with self.subTest(mode=mode):
                self.assertEqual(
                    self.calculate(2048, CELERY_WORKER_MODE=mode), "--concurrency 6"
                )


if __name__ == "__main__":
    unittest.main()
