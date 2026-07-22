"""Shared configuration for Echo Cave's browser-driven tests."""

from __future__ import annotations

import os
from urllib.parse import urlsplit, urlunsplit


SUPPORTED_BROWSERS = ("chromium", "webkit")

TOUCH_HELPER_SCRIPT = r"""
(() => {
  window.echoTestTouch = Object.freeze({
    point(target, x, y, identifier = 1) {
      return Object.freeze({
        identifier,
        target,
        clientX: x,
        clientY: y,
        pageX: x,
        pageY: y,
        screenX: x,
        screenY: y,
        radiusX: 1,
        radiusY: 1,
        rotationAngle: 0,
        force: 1,
      });
    },
    dispatch(target, type, touches, changedTouches = touches) {
      const event = new Event(type, { bubbles: true, cancelable: true, composed: true });
      Object.defineProperties(event, {
        touches: { value: touches },
        changedTouches: { value: changedTouches },
        targetTouches: { value: touches },
      });
      return target.dispatchEvent(event);
    },
  });
})();
"""


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


async def install_touch_test_helper(page) -> None:
    """Install a standards-neutral synthetic touch shim before app scripts run.

    WebKit exposes ``Touch`` but does not allow page JavaScript to construct it.
    A generic cancelable Event with the touch-list properties used by Echo Cave
    exercises the same handlers in both Playwright browser engines.
    """

    await page.add_init_script(script=TOUCH_HELPER_SCRIPT)
