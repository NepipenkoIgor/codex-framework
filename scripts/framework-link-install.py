#!/usr/bin/env python3
"""Synchronize arbitrary framework-owned symlinks without adopting user links."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def target_of(path: Path) -> Path | None:
    if not path.is_symlink():
        return None
    raw = Path(os.readlink(path))
    return (path.parent / raw).resolve(strict=False) if not raw.is_absolute() else raw.resolve(strict=False)


def load_state(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    value = json.loads(path.read_text())
    if value.get("schemaVersion") != 1 or not isinstance(value.get("managed"), dict):
        raise ValueError(f"unsupported link state: {path}")
    return {str(link): str(target) for link, target in value["managed"].items()}


def parse_link(value: str) -> tuple[Path, Path]:
    if "=" not in value:
        raise ValueError(f"invalid --link value: {value}")
    link_text, target_text = value.split("=", 1)
    link = Path(os.path.abspath(Path(link_text).expanduser()))
    target = Path(target_text).expanduser().resolve(strict=True)
    return link, target


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--link", action="append", default=[])
    args = parser.parse_args()
    try:
        state_path = Path(os.path.abspath(Path(args.state).expanduser()))
        previous = load_state(state_path)
        desired = dict(parse_link(item) for item in args.link)
        errors: list[str] = []
        for link, target in desired.items():
            if not link.exists() and not link.is_symlink():
                continue
            recorded = Path(previous[str(link)]).resolve(strict=False) if str(link) in previous else None
            if recorded is None or target_of(link) != recorded:
                errors.append(f"user-owned collision: {link}")
        for link_text, recorded_text in previous.items():
            link = Path(link_text)
            if link in desired or (not link.exists() and not link.is_symlink()):
                continue
            if target_of(link) != Path(recorded_text).resolve(strict=False):
                errors.append(f"managed link was replaced by user content: {link}")
        if errors:
            raise ValueError("link preflight failed; no writes performed:\n- " + "\n- ".join(errors))
        if args.preflight:
            print(f"framework link preflight passed: {len(desired)} links")
            return 0
        if args.check:
            expected = {str(link): str(target) for link, target in desired.items()}
            if previous != expected or any(target_of(link) != target for link, target in desired.items()):
                raise ValueError("framework link state does not match requested links")
            print(f"framework links are synchronized: {len(desired)} links")
            return 0
        for link_text, recorded_text in previous.items():
            link = Path(link_text)
            if link not in desired and link.is_symlink() and target_of(link) == Path(recorded_text).resolve(strict=False):
                link.unlink()
        for link, target in desired.items():
            link.parent.mkdir(parents=True, exist_ok=True)
            if link.is_symlink() and target_of(link) == target:
                continue
            if link.is_symlink():
                link.unlink()
            link.symlink_to(target, target_is_directory=target.is_dir())
        payload = {"schemaVersion": 1, "managed": {str(k): str(v) for k, v in sorted(desired.items(), key=lambda x: str(x[0]))}}
        state_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = state_path.with_name(f"{state_path.name}.tmp.{os.getpid()}")
        temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        temporary.replace(state_path)
        print(f"synchronized {len(desired)} framework-owned links")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.exit(1, f"framework link install error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
