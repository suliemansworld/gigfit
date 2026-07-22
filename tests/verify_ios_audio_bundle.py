#!/usr/bin/env python3
"""Verify that an iOS/web bundle preserves every source audio file exactly."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_AUDIO = ROOT / "audio"
DEFAULT_BUNDLES = (
    ROOT / "www" / "audio",
    ROOT / "ios" / "App" / "App" / "public" / "audio",
)
EXPECTED_SOURCE_COUNTS = {".wav": 636, ".mp3": 103, ".json": 1}
EXPECTED_NARRATION_ENTRIES = 689


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "bundle_roots",
        nargs="*",
        type=Path,
        help="audio directories to verify; defaults to www/audio and native public/audio",
    )
    parser.add_argument(
        "--afinfo",
        action="store_true",
        help="also ask Apple's afinfo to decode every shipped WAV and MP3",
    )
    return parser.parse_args()


def files_under(root: Path) -> dict[Path, Path]:
    return {
        path.relative_to(root): path
        for path in root.rglob("*")
        if path.is_file()
    }


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def validate_source(source_files: dict[Path, Path]) -> dict[Path, str]:
    counts = Counter(path.suffix.lower() for path in source_files)
    require(
        dict(counts) == EXPECTED_SOURCE_COUNTS,
        f"source audio inventory changed: expected {EXPECTED_SOURCE_COUNTS}, got {dict(counts)}",
    )

    manifest_path = SOURCE_AUDIO / "voice" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    require(
        len(manifest) == EXPECTED_NARRATION_ENTRIES,
        f"expected {EXPECTED_NARRATION_ENTRIES} narration entries, got {len(manifest)}",
    )
    for stem, entry in manifest.items():
        raw_path = entry.get("wav", "")
        require(raw_path.startswith("audio/voice/"), f"unsafe narration path for {stem}: {raw_path}")
        relative = Path(raw_path).relative_to("audio")
        require(relative in source_files, f"missing narration source for {stem}: {raw_path}")
        if relative.suffix.lower() == ".mp3":
            wav_alternative = relative.with_suffix(".wav")
            require(
                wav_alternative not in source_files,
                f"manifest must prefer the licensed WAV when it exists: {wav_alternative}",
            )

    return {relative: sha256(path) for relative, path in source_files.items()}


def validate_build_info(bundle_root: Path) -> None:
    build_info_path = bundle_root.parent / "build-info.json"
    require(build_info_path.is_file(), f"missing build-info.json beside {bundle_root}")
    build_info = json.loads(build_info_path.read_text(encoding="utf-8"))
    require(build_info.get("preservedSourceAudio") is True, "build does not declare preserved source audio")
    require(build_info.get("narrationFiles") == EXPECTED_NARRATION_ENTRIES, "wrong narration count")
    require(build_info.get("sourceWavFiles") == EXPECTED_SOURCE_COUNTS[".wav"], "wrong WAV count")
    require(build_info.get("sourceAudioFiles") == sum(EXPECTED_SOURCE_COUNTS.values()), "wrong audio tree count")


def validate_bundle(
    bundle_root: Path,
    source_files: dict[Path, Path],
    source_hashes: dict[Path, str],
    *,
    use_afinfo: bool,
) -> None:
    require(bundle_root.is_dir(), f"missing generated audio directory: {bundle_root}")
    bundle_files = files_under(bundle_root)
    missing = sorted(source_files.keys() - bundle_files.keys())
    extra = sorted(bundle_files.keys() - source_files.keys())
    require(not missing, f"{bundle_root} omits source audio: {missing[:10]}")
    require(not extra, f"{bundle_root} contains substituted/extra audio: {extra[:10]}")
    require(not any(path.suffix.lower() == ".m4a" for path in bundle_files), "M4A substitution is forbidden")

    for relative, built_path in bundle_files.items():
        require(
            sha256(built_path) == source_hashes[relative],
            f"audio bytes changed in {bundle_root}: {relative}",
        )

    validate_build_info(bundle_root)

    if use_afinfo:
        afinfo = shutil.which("afinfo")
        require(afinfo is not None, "--afinfo requires Apple's afinfo executable")
        for relative, built_path in bundle_files.items():
            if relative.suffix.lower() not in {".wav", ".mp3"}:
                continue
            result = subprocess.run(
                [afinfo, str(built_path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
                timeout=15,
                check=False,
            )
            require(result.returncode == 0, f"afinfo rejected {relative}: {result.stderr.strip()}")

    print(
        f"Verified {bundle_root}: {len(bundle_files)} exact files, "
        f"{EXPECTED_SOURCE_COUNTS['.wav']} original WAVs, "
        f"{EXPECTED_NARRATION_ENTRIES} narration entries."
    )


def main() -> int:
    args = arguments()
    source_files = files_under(SOURCE_AUDIO)
    try:
        source_hashes = validate_source(source_files)
        bundle_roots = tuple(path.resolve() for path in args.bundle_roots) or DEFAULT_BUNDLES
        for bundle_root in bundle_roots:
            validate_bundle(
                bundle_root,
                source_files,
                source_hashes,
                use_afinfo=args.afinfo,
            )
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Audio bundle verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
