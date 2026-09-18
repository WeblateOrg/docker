import os
import subprocess
import unittest
from pathlib import Path

IMAGE = os.environ.get("TEST_CONTAINER", "weblate/weblate:test")
LOCAL_PYTHON = os.environ.get("GENERATE_SITE_PYTHON")
ROOT = Path(__file__).resolve().parents[2]


def generate_config(
    proxy_header: str = "",
    trusted_proxy_addresses: str = "",
    early_nginx: bool = False,
    anubis_url: str = "",
) -> subprocess.CompletedProcess[str]:
    if LOCAL_PYTHON:
        command = [
            LOCAL_PYTHON,
            str(ROOT / "etc/nginx/generate-site.py"),
            str(ROOT / "etc/nginx"),
        ]
    else:
        command = [
            "docker",
            "run",
            "--rm",
            "--entrypoint",
            "/app/venv/bin/python",
            IMAGE,
            "/etc/nginx/generate-site.py",
            "/etc/nginx",
        ]
    return subprocess.run(
        [
            *command,
            "",
            proxy_header,
            trusted_proxy_addresses,
            "100m",
            "",
            anubis_url,
            "test.example.com",
            "",
            "/run/granian/granian.sock",
            "",
            "1" if early_nginx else "",
        ],
        check=False,
        capture_output=True,
        text=True,
    )


class NginxConfigTest(unittest.TestCase):
    def test_early_nginx_does_not_use_application_server(self) -> None:
        result = generate_config(
            early_nginx=True, anubis_url="http://anubis.example.com"
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("access_log off;", result.stdout)
        self.assertIn("return 502;", result.stdout)
        self.assertNotIn("proxy_pass http://unix:", result.stdout)

    def test_forwarded_for_disabled(self) -> None:
        result = generate_config()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("access_log off;", result.stdout)
        self.assertNotIn("real_ip_header", result.stdout)
        self.assertNotIn("set_real_ip_from", result.stdout)

    def test_forwarded_for_without_trusted_proxy(self) -> None:
        result = generate_config("HTTP_X_FORWARDED_FOR")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("real_ip_header X-Forwarded-For;", result.stdout)
        self.assertIn("real_ip_recursive on;", result.stdout)
        self.assertNotIn("set_real_ip_from", result.stdout)
        self.assertIn("proxy_set_header X-Forwarded-For $remote_addr;", result.stdout)
        self.assertNotIn("$proxy_add_x_forwarded_for", result.stdout)
        self.assertNotIn("0.0.0.0/0", result.stdout)
        self.assertNotIn("::/0", result.stdout)

    def test_trusted_proxy_addresses(self) -> None:
        addresses = (
            "192.0.2.10 198.51.100.0/24 2001:db8::1 2001:db8:1::/48 proxy.internal"
        )
        result = generate_config("HTTP_X_FORWARDED_FOR", addresses)

        self.assertEqual(result.returncode, 0, result.stderr)
        for address in addresses.split():
            self.assertIn(f"set_real_ip_from {address};", result.stdout)

    def test_trusted_proxies_do_not_enable_forwarded_for(self) -> None:
        result = generate_config("", "192.0.2.10")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("real_ip_header", result.stdout)
        self.assertNotIn("set_real_ip_from", result.stdout)

    def test_custom_proxy_header(self) -> None:
        for header, name in (
            ("HTTP_X_REAL_IP", "X-Real-Ip"),
            ("HTTP_CF_CONNECTING_IP", "Cf-Connecting-Ip"),
            ("HTTP_TRUE_CLIENT_IP", "True-Client-Ip"),
        ):
            for early_nginx in (False, True):
                with self.subTest(header=header, early_nginx=early_nginx):
                    result = generate_config(
                        header, "192.0.2.10", early_nginx=early_nginx
                    )

                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f"real_ip_header {name};", result.stdout)
                    self.assertIn("real_ip_recursive on;", result.stdout)
                    self.assertIn("set_real_ip_from 192.0.2.10;", result.stdout)
                    self.assertIn(
                        f"proxy_set_header {name} $remote_addr;", result.stdout
                    )

    def test_custom_proxy_header_without_trusted_proxy(self) -> None:
        result = generate_config("HTTP_CF_CONNECTING_IP")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("real_ip_header Cf-Connecting-Ip;", result.stdout)
        self.assertNotIn("set_real_ip_from", result.stdout)
        self.assertIn("proxy_set_header Cf-Connecting-Ip $remote_addr;", result.stdout)

    def test_anubis_proxy_headers(self) -> None:
        for header in (
            "HTTP_X_FORWARDED_FOR",
            "HTTP_X_REAL_IP",
            "HTTP_CF_CONNECTING_IP",
        ):
            with self.subTest(header=header):
                result = generate_config(
                    header, "192.0.2.10", anubis_url="http://anubis.example.com"
                )

                self.assertEqual(result.returncode, 0, result.stderr)
                location = result.stdout.split("location /.within.website/ {", 1)[1]
                location = location.split("}", 1)[0].lower()
                name = header.removeprefix("HTTP_").replace("_", "-").lower()
                self.assertEqual(
                    location.count(f"proxy_set_header {name} $remote_addr;"), 1
                )
                self.assertIn(
                    "proxy_set_header x-forwarded-for $remote_addr;", location
                )
                self.assertNotIn("$proxy_add_x_forwarded_for", result.stdout)

    def test_invalid_proxy_header(self) -> None:
        for header in (
            "HTTP_",
            "X-Forwarded-For",
            "HTTP_X;include",
            "HTTP_X\n",
            "HTTP_X$host",
        ):
            with self.subTest(header=header):
                result = generate_config(header)

                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Invalid proxy header", result.stderr)

    def test_invalid_trusted_proxy_address(self) -> None:
        for address in (
            "192.0.2.1/24",
            "192.0.2.1/33",
            "proxy;include",
            "proxy{",
            "-proxy",
        ):
            with self.subTest(address=address):
                result = generate_config("HTTP_X_FORWARDED_FOR", address)

                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Invalid trusted proxy address", result.stderr)


if __name__ == "__main__":
    unittest.main()
