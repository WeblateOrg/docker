"""Test the entrypoint's PostgreSQL version check with mocked psql output."""

import os
import subprocess
import unittest
from pathlib import Path

START = Path(__file__).resolve().parents[2] / "start"
SOURCE = START.read_text()
VERSION_CHECK = SOURCE.split("check_postgres_version() {", 1)[1].split(
    "\nresolve_celery_worker_mode() {", 1
)[0]
SCRIPT = (
    "set -e\n"
    "database_version_check_enabled() { return 0; }\n"
    "check_postgres_version() {"
    + VERSION_CHECK
    + '\npsql() { printf "%s\\n" "$TEST_VERSION"; }\n'
    + 'check_postgres_version\nprintf "CHECK_COMPLETE\\n"\n'
)


class PostgresVersionTest(unittest.TestCase):
    def check_version(self, version):
        return subprocess.run(
            ["bash", "-c", SCRIPT],
            env={"PATH": os.defpath, "TEST_VERSION": version},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_supported_versions(self):
        for version in ("120000", "180000", "000120000"):
            with self.subTest(version=version):
                result = self.check_version(version)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("CHECK_COMPLETE", result.stdout)

    def test_unsupported_versions(self):
        for version in ("110000", "000110000"):
            with self.subTest(version=version):
                result = self.check_version(version)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("PostgreSQL 12 or newer is required", result.stderr)
                self.assertNotIn("CHECK_COMPLETE", result.stdout)

    def test_invalid_versions_are_rejected_before_arithmetic(self):
        for version in (
            "",
            "12abc",
            " 120000",
            "X$(printf DIRECT_MARKER >&2)999999",
            "a[$(printf ARRAY_MARKER >&2)0]+999999",
        ):
            with self.subTest(version=version):
                result = self.check_version(version)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Invalid PostgreSQL server version", result.stderr)
                self.assertNotIn("MARKER", result.stderr)
                self.assertNotIn("CHECK_COMPLETE", result.stdout)


if __name__ == "__main__":
    unittest.main()
