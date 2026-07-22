#!/usr/bin/env python3
"""Run Echo Cave's static and browser suites against an isolated local server."""

from __future__ import annotations

import argparse
import contextlib
import functools
import http.server
import os
import subprocess
import sys
import threading
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
SUPPORTED_BROWSERS = ("chromium", "webkit")
PRIMARY_SUITES = ("test_echo_game.py", "test_echo_game_e2e.py")
EXTRA_SUITES = ("test_echo_game_fuzz.py", "test_rotor_fuzz.py")


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        pass


class TestServer(http.server.ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


@contextlib.contextmanager
def local_server(port: int):
    handler = functools.partial(QuietHandler, directory=str(ROOT))
    server = TestServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, name="echo-cave-tests")
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}/"

    try:
        with urllib.request.urlopen(base_url + "manifest.json", timeout=5) as response:
            if response.status != 200:
                raise RuntimeError(f"test server returned HTTP {response.status}")
            response.read()
        print(f"Test server: {base_url}", flush=True)
        yield base_url
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        print("Test server stopped.", flush=True)


def run_command(command: list[str], *, env: dict[str, str] | None = None) -> int:
    display = " ".join(command)
    print(f"\n==> {display}", flush=True)
    completed = subprocess.run(command, cwd=ROOT, env=env, check=False)
    return completed.returncode


def parse_browsers(raw: str) -> list[str]:
    browsers = [item.strip().lower() for item in raw.split(",") if item.strip()]
    if not browsers:
        raise argparse.ArgumentTypeError("at least one browser is required")
    unsupported = sorted(set(browsers) - set(SUPPORTED_BROWSERS))
    if unsupported:
        choices = ", ".join(SUPPORTED_BROWSERS)
        raise argparse.ArgumentTypeError(
            f"unsupported browser(s): {', '.join(unsupported)}; choose {choices}"
        )
    return list(dict.fromkeys(browsers))


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    default_browsers = os.environ.get(
        "ECHO_BROWSERS", os.environ.get("ECHO_BROWSER", "chromium")
    )
    parser.add_argument(
        "--browsers",
        type=parse_browsers,
        default=parse_browsers(default_browsers),
        help="comma-separated browser engines (default: ECHO_BROWSERS or chromium)",
    )
    parser.add_argument(
        "--static-only",
        action="store_true",
        help="run install-free bundle checks without starting a browser server",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="also run the gameplay and rotor fuzz suites",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("ECHO_TEST_PORT", "0")),
        help="local server port; 0 selects a free port",
    )
    parser.add_argument(
        "--fuzz-minutes",
        type=int,
        default=int(os.environ.get("ECHO_FUZZ_MINUTES", "10")),
    )
    parser.add_argument(
        "--rotor-iterations",
        type=int,
        default=int(os.environ.get("ECHO_ROTOR_ITERATIONS", "40")),
    )
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")
    if args.fuzz_minutes < 1:
        parser.error("--fuzz-minutes must be at least 1")
    if args.rotor_iterations < 1:
        parser.error("--rotor-iterations must be at least 1")
    return args


def main() -> int:
    args = arguments()
    static_result = run_command([sys.executable, str(TESTS / "test_static_assets.py")])
    if static_result or args.static_only:
        return static_result

    failures: list[tuple[str, str]] = []
    with local_server(args.port) as base_url:
        for browser in args.browsers:
            env = os.environ.copy()
            env["ECHO_BASE_URL"] = base_url
            env["ECHO_BROWSER"] = browser
            print(f"\n######## {browser.upper()} ########", flush=True)

            suites: list[tuple[str, list[str]]] = [
                (name, []) for name in PRIMARY_SUITES
            ]
            if args.all:
                suites.extend(
                    [
                        (EXTRA_SUITES[0], ["--minutes", str(args.fuzz_minutes)]),
                        (
                            EXTRA_SUITES[1],
                            ["--iterations", str(args.rotor_iterations)],
                        ),
                    ]
                )

            for suite, suite_args in suites:
                command = [sys.executable, str(TESTS / suite), *suite_args]
                if run_command(command, env=env):
                    failures.append((browser, suite))

    if failures:
        print("\nFailed browser suites:")
        for browser, suite in failures:
            print(f"  - {browser}: {suite}")
        return 1

    print("\nAll requested Echo Cave test suites passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
