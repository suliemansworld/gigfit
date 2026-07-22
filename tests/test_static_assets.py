#!/usr/bin/env python3
"""Install-free integrity checks for Echo Cave's offline application bundle."""

from __future__ import annotations

import json
import re
import struct
import unittest
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
INDEX_PATH = ROOT / "index.html"
MANIFEST_PATH = ROOT / "manifest.json"
SERVICE_WORKER_PATH = ROOT / "sw.js"
BUILD_SCRIPT_PATH = ROOT / "scripts" / "build-web.mjs"
VOICE_MANIFEST_PATH = ROOT / "audio" / "voice" / "manifest.json"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def local_path(raw: str) -> Path:
    """Resolve a repository-relative URL while rejecting traversal and URLs."""

    value = raw.split("?", 1)[0].split("#", 1)[0]
    posix = PurePosixPath(value)
    if posix.is_absolute() or ".." in posix.parts or "://" in value:
        raise AssertionError(f"asset path is not repository-relative: {raw!r}")
    return ROOT.joinpath(*posix.parts)


def extract_precache(service_worker: str) -> set[str]:
    match = re.search(
        r"const\s+PRECACHE\s*=\s*\[(?P<body>.*?)\]\s*;",
        service_worker,
        flags=re.DOTALL,
    )
    if not match:
        raise AssertionError("sw.js must declare a literal PRECACHE array")
    return set(re.findall(r"['\"]([^'\"]+)['\"]", match.group("body")))


def png_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"{path.relative_to(ROOT)} is not a valid PNG")
    return struct.unpack(">II", header[16:24])


class StaticBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.index = read_text(INDEX_PATH)
        cls.service_worker = read_text(SERVICE_WORKER_PATH)
        cls.build_script = read_text(BUILD_SCRIPT_PATH)
        cls.manifest = json.loads(read_text(MANIFEST_PATH))
        cls.voice_manifest = json.loads(read_text(VOICE_MANIFEST_PATH))
        cls.precache = extract_precache(cls.service_worker)

    def test_web_manifest_shape_and_icons(self) -> None:
        required = {
            "name",
            "short_name",
            "description",
            "start_url",
            "scope",
            "display",
            "background_color",
            "theme_color",
            "icons",
        }
        self.assertFalse(required - self.manifest.keys())
        self.assertEqual(self.manifest["display"], "standalone")
        self.assertTrue(self.manifest["icons"], "manifest must declare app icons")

        declared_sizes: set[tuple[int, int]] = set()
        for icon in self.manifest["icons"]:
            with self.subTest(icon=icon.get("src")):
                self.assertEqual(icon.get("type"), "image/png")
                path = local_path(icon["src"])
                self.assertTrue(path.is_file(), f"missing manifest icon: {icon['src']}")
                declared = tuple(int(part) for part in icon["sizes"].split("x", 1))
                self.assertEqual(png_dimensions(path), declared)
                declared_sizes.add(declared)

        self.assertIn((192, 192), declared_sizes)
        self.assertIn((512, 512), declared_sizes)
        self.assertRegex(
            self.index,
            r"<link\s+rel=['\"]manifest['\"]\s+href=['\"]manifest\.json['\"]",
        )

    def test_voice_manifest_entries_resolve_to_audio(self) -> None:
        self.assertIsInstance(self.voice_manifest, dict)
        self.assertGreater(len(self.voice_manifest), 0)

        for stem, entry in self.voice_manifest.items():
            with self.subTest(stem=stem):
                self.assertIsInstance(entry, dict)
                self.assertEqual(set(entry), {"text", "wav"})
                self.assertTrue(entry["text"].strip())
                self.assertRegex(entry["wav"], r"^audio/voice/[^/]+\.(?:wav|mp3)$")
                self.assertTrue(
                    local_path(entry["wav"]).is_file(),
                    f"missing voice clip: {entry['wav']}",
                )

    def test_all_literal_audio_references_exist(self) -> None:
        references = set(
            re.findall(r"['\"](audio/[^'\"?#]+)", self.index + self.service_worker)
        )
        references.discard("audio/voice/manifest.json")
        references.update(entry["wav"] for entry in self.voice_manifest.values())
        self.assertGreater(len(references), 0)

        missing = sorted(path for path in references if not local_path(path).is_file())
        self.assertEqual(missing, [], f"missing referenced audio files: {missing}")

        for reference in references:
            with self.subTest(audio=reference):
                path = local_path(reference)
                with path.open("rb") as audio_file:
                    header = audio_file.read(12)
                self.assertGreater(path.stat().st_size, 44, "audio file is empty or truncated")
                if path.suffix.lower() == ".wav":
                    self.assertEqual(header[:4], b"RIFF")
                    self.assertEqual(header[8:12], b"WAVE")
                elif path.suffix.lower() == ".mp3":
                    self.assertTrue(
                        header.startswith(b"ID3")
                        or (len(header) >= 2 and header[0] == 0xFF and header[1] & 0xE0 == 0xE0),
                        "MP3 file has no ID3 tag or MPEG frame sync",
                    )
                else:
                    self.fail(f"unsupported audio extension: {path.suffix}")

    def test_precache_entries_exist_and_cover_core_assets(self) -> None:
        missing = sorted(path for path in self.precache if not local_path(path).is_file())
        self.assertEqual(missing, [], f"missing PRECACHE files: {missing}")

        required = {
            "index.html",
            "manifest.json",
            "audio/voice/manifest.json",
            "audio/welcome-music.mp3",
        }
        required.update(icon["src"] for icon in self.manifest["icons"])
        self.assertEqual(required - self.precache, set())

        runtime_audio = set(re.findall(r"['\"](audio/[^'\"?#]+)", self.index))
        runtime_audio.discard("audio/voice/manifest.json")
        self.assertEqual(
            runtime_audio - self.precache,
            set(),
            "non-voice runtime audio must be available in the offline precache",
        )

    def test_build_tags_match(self) -> None:
        page_tags = re.findall(
            r"window\.ECHO_BUILD\s*=\s*['\"]([^'\"]+)['\"]", self.index
        )
        worker_tags = re.findall(
            r"const\s+BUILD\s*=\s*['\"]([^'\"]+)['\"]", self.service_worker
        )
        self.assertEqual(len(page_tags), 1, "index.html must declare one ECHO_BUILD")
        self.assertEqual(len(worker_tags), 1, "sw.js must declare one BUILD")
        self.assertRegex(page_tags[0], r"^[A-Za-z0-9._-]+$")
        self.assertEqual(page_tags[0], worker_tags[0])

    def test_service_worker_cache_contract(self) -> None:
        self.assertRegex(
            self.service_worker,
            r"const\s+CACHE_PREFIX\s*=\s*['\"]echo-cave-['\"]",
        )
        self.assertRegex(
            self.service_worker,
            r"const\s+CACHE\s*=\s*`\$\{CACHE_PREFIX\}\$\{BUILD\}`",
        )
        self.assertRegex(
            self.service_worker,
            r"keys\.filter\(k\s*=>\s*k\.startsWith\(CACHE_PREFIX\)\s*&&\s*k\s*!==\s*CACHE\)",
        )
        self.assertIn("caches.delete(k)", self.service_worker)
        self.assertIn("ignoreSearch: true", self.service_worker)
        self.assertIn("url.pathname.includes('/audio/voice/')", self.service_worker)
        self.assertRegex(
            self.index,
            r"navigator\.serviceWorker\.register\(['\"]sw\.js['\"]\)",
        )
        self.assertRegex(
            self.build_script,
            r"copy\(['\"]sw\.js['\"]\)",
            "the standalone web bundle must include its registered service worker",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
