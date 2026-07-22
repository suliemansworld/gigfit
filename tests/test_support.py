"""Shared configuration for Echo Cave's browser-driven tests."""

from __future__ import annotations

import os
from urllib.parse import urlsplit, urlunsplit


SUPPORTED_BROWSERS = ("chromium", "webkit")


def _base_url() -> str:
    raw = os.environ.get("ECHO_BASE_URL", "http://127.0.0.1:8080/").strip()
    parts = urlsplit(raw)
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        raise RuntimeError(
            "ECHO_BASE_URL must be an absolute http(s) URL, for example "
            "http://127.0.0.1:8080/"
        )
    if parts.query or parts.fragment:
        raise RuntimeError("ECHO_BASE_URL cannot contain a query string or fragment")

    path = parts.path or "/"
    if not path.endswith("/"):
        path += "/"
    return urlunsplit((parts.scheme, parts.netloc, path, "", ""))


BASE_URL = _base_url()
GAME_URL = f"{BASE_URL}?fresh=1&nogate=1"
BROWSER_NAME = os.environ.get("ECHO_BROWSER", "chromium").strip().lower()

if BROWSER_NAME not in SUPPORTED_BROWSERS:
    choices = ", ".join(SUPPORTED_BROWSERS)
    raise RuntimeError(f"Unsupported ECHO_BROWSER={BROWSER_NAME!r}; choose {choices}")


async def launch_browser(playwright):
    """Launch the configured Playwright browser."""

    return await getattr(playwright, BROWSER_NAME).launch()
