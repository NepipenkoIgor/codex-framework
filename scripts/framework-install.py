#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


def manifest_entries(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]


def load_state(path: Path) -> dict[str, object]:
    if not path.exists():
        return {"schemaVersion": 1, "managed": {}, "packs": []}
    state = json.loads(path.read_text())
    if state.get("schemaVersion") != 1 or not isinstance(state.get("managed"), dict):
        raise ValueError(f"unsupported install state: {path}")
    return state


def link_target(path: Path) -> Path | None:
    if not path.is_symlink():
        return None
    raw = Path(os.readlink(path))
    return (path.parent / raw).resolve(strict=False) if not raw.is_absolute() else raw.resolve(strict=False)


def source_digest(root: Path, manifests: list[Path]) -> str:
    digest = hashlib.sha256()
    for manifest in manifests:
        relative = manifest.relative_to(root).as_posix().encode()
        content = manifest.read_bytes()
        digest.update(relative + b"\0" + content + b"\0")
    return digest.hexdigest()


def desired_skills(root: Path, core: Path | None, packs: list[str]) -> tuple[dict[str, Path], list[Path]]:
    names: list[str] = []
    manifests: list[Path] = []
    if core:
        manifests.append(core)
        names.extend(manifest_entries(core))
    for pack in packs:
        manifest = root / "skills" / "packs" / f"{pack}.txt"
        if not manifest.is_file():
            raise ValueError(f"unknown skill pack: {pack}")
        manifests.append(manifest)
        names.extend(manifest_entries(manifest))
    desired: dict[str, Path] = {}
    for name in names:
        target = (root / "skills" / name).resolve()
        if not (target / "SKILL.md").is_file():
            raise ValueError(f"manifest references missing skill: {name}")
        if name in desired and desired[name] != target:
            raise ValueError(f"conflicting skill target: {name}")
        desired[name] = target
    return desired, manifests


def preflight(
    skills_root: Path,
    desired: dict[str, Path],
    previous: dict[str, str],
    legacy_roots: list[Path],
    allowed_sources: set[Path],
) -> list[Path]:
    errors: list[str] = []
    for name, target in desired.items():
        path = skills_root / name
        if not path.exists() and not path.is_symlink():
            continue
        current = link_target(path)
        recorded = Path(previous[name]).resolve(strict=False) if name in previous else None
        if recorded is not None and current == recorded:
            continue
        errors.append(f"user-owned collision: {path}")
    for name, recorded_text in previous.items():
        if name in desired:
            continue
        path = skills_root / name
        if not path.exists() and not path.is_symlink():
            continue
        if link_target(path) != Path(recorded_text).resolve(strict=False):
            errors.append(f"managed skill was replaced by user content: {path}")

    legacy_links: list[Path] = []
    for legacy_root in legacy_roots:
        if not legacy_root.exists() and not legacy_root.is_symlink():
            continue
        if legacy_root.is_symlink():
            errors.append(f"legacy namespace must not be a symlink: {legacy_root}")
            continue
        if not legacy_root.is_dir():
            errors.append(f"legacy namespace is not a directory: {legacy_root}")
            continue
        for entry in sorted(legacy_root.rglob("*")):
            if entry.is_symlink():
                target = link_target(entry)
                if target is None or target.parent not in allowed_sources:
                    errors.append(f"unknown entry in legacy namespace: {entry}")
                else:
                    legacy_links.append(entry)
            elif not entry.is_dir():
                errors.append(f"unknown entry in legacy namespace: {entry}")
    if errors:
        raise ValueError("install preflight failed; no writes performed:\n- " + "\n- ".join(errors))
    return legacy_links


def sync(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    skills_root = Path(args.skills_root).expanduser().resolve()
    state_path = Path(args.state).expanduser().resolve()
    core = Path(args.core).resolve() if args.core else None
    packs = sorted(set(args.pack))
    desired, manifests = desired_skills(root, core, packs)
    state = load_state(state_path)
    previous = {str(name): str(target) for name, target in state.get("managed", {}).items()}
    allowed_sources = {(root / "skills").resolve()}
    previous_root = state.get("sourceRoot")
    if isinstance(previous_root, str):
        allowed_sources.add((Path(previous_root) / "skills").resolve(strict=False))
    # Keep the lexical namespace path. Resolving the final component would turn
    # a user-owned symlink into the external directory it points at and make the
    # migration delete outside the declared legacy namespace.
    legacy_roots = [Path(os.path.abspath(Path(item).expanduser())) for item in args.legacy_root]
    legacy_links = preflight(skills_root, desired, previous, legacy_roots, allowed_sources)

    skills_root.mkdir(parents=True, exist_ok=True)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    for entry in legacy_links:
        entry.unlink()
    for legacy_root in legacy_roots:
        if legacy_root.is_dir():
            for directory in sorted(
                (item for item in legacy_root.rglob("*") if item.is_dir()),
                key=lambda item: len(item.parts),
                reverse=True,
            ):
                if not any(directory.iterdir()):
                    directory.rmdir()
        if legacy_root.is_dir() and not any(legacy_root.iterdir()):
            legacy_root.rmdir()
            parent = legacy_root.parent
            if parent.name == "skills" and parent.is_dir() and not any(parent.iterdir()):
                parent.rmdir()

    for name, recorded_text in previous.items():
        if name not in desired:
            path = skills_root / name
            if path.is_symlink() and link_target(path) == Path(recorded_text).resolve(strict=False):
                path.unlink()
    for name, target in desired.items():
        path = skills_root / name
        if path.is_symlink() and link_target(path) == target:
            continue
        if path.is_symlink():
            path.unlink()
        path.symlink_to(target, target_is_directory=True)

    payload = {
        "schemaVersion": 1,
        "sourceRoot": str(root),
        "skillsRoot": str(skills_root),
        "manifestDigest": source_digest(root, manifests),
        "packs": packs,
        "managed": {name: str(target) for name, target in sorted(desired.items())},
    }
    temporary = state_path.with_name(f"{state_path.name}.tmp.{os.getpid()}")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    temporary.replace(state_path)
    print(f"synchronized {len(desired)} framework-managed skills in {skills_root}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--skills-root", required=True)
    parser.add_argument("--state", required=True)
    parser.add_argument("--core")
    parser.add_argument("--pack", action="append", default=[])
    parser.add_argument("--legacy-root", action="append", default=[])
    args = parser.parse_args()
    try:
        return sync(args)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.exit(1, f"framework install error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
