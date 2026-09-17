#!/usr/bin/env python3
"""Synchronize framework-owned links and copied files without adopting user content."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import runpy
from pathlib import Path
import tempfile


def target_of(path: Path) -> Path | None:
    if not path.is_symlink():
        return None
    raw = Path(os.readlink(path))
    return (path.parent / raw).resolve(strict=False) if not raw.is_absolute() else raw.resolve(strict=False)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def atomic_write(path: Path, content: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_text = tempfile.mkstemp(prefix=f".{path.name}.tmp.", dir=path.parent)
    temporary = Path(temporary_text)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        temporary.chmod(mode)
        temporary.replace(path)
    finally:
        if temporary.exists() or temporary.is_symlink():
            temporary.unlink()


def load_state(path: Path) -> tuple[dict[str, str], dict[str, dict[str, str]]]:
    if not path.exists():
        return {}, {}
    value = json.loads(path.read_text())
    if value.get("schemaVersion") != 1 or not isinstance(value.get("managed"), dict):
        raise ValueError(f"unsupported link state: {path}")
    files = value.get("managedFiles", {})
    if not isinstance(files, dict) or any(
        not isinstance(item, dict)
        or not isinstance(item.get("source"), str)
        or not isinstance(item.get("sha256"), str)
        for item in files.values()
    ):
        raise ValueError(f"unsupported managed file state: {path}")
    return (
        {str(link): str(target) for link, target in value["managed"].items()},
        {
            str(destination): {"source": str(item["source"]), "sha256": str(item["sha256"])}
            for destination, item in files.items()
        },
    )


def parse_link(value: str) -> tuple[Path, Path]:
    if "=" not in value:
        raise ValueError(f"invalid --link value: {value}")
    link_text, target_text = value.split("=", 1)
    link = Path(os.path.abspath(Path(link_text).expanduser()))
    target = Path(target_text).expanduser().resolve(strict=True)
    return link, target


def parse_file(value: str) -> tuple[Path, Path]:
    if "=" not in value:
        raise ValueError(f"invalid --file value: {value}")
    destination_text, source_text = value.split("=", 1)
    destination = Path(os.path.abspath(Path(destination_text).expanduser()))
    source = Path(source_text).expanduser().resolve(strict=True)
    if not source.is_file():
        raise ValueError(f"managed file source is not a regular file: {source}")
    return destination, source


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--preflight", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--link", action="append", default=[])
    parser.add_argument("--file", action="append", default=[])
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--guidance")
    args = parser.parse_args()
    try:
        state_path = Path(os.path.abspath(Path(args.state).expanduser()))
        previous_links, previous_files = load_state(state_path)
        desired_links = dict(parse_link(item) for item in args.link)
        source_api = runpy.run_path(str(Path(__file__).with_name("framework-install-source.py")))
        installation_source = None
        if args.source_root:
            installation_source = source_api["identity"](args.source_root, args.development)
            if not args.check:
                source_api["validate"](installation_source)
            if args.check:
                recorded_source = json.loads(state_path.read_text()).get("sourceIdentity")
                if recorded_source is None:
                    raise ValueError("installation source identity is missing; reinstall explicitly")
                installation_source["mode"] = recorded_source.get("mode")
                print(source_api["describe"](installation_source))
                if installation_source != recorded_source:
                    raise ValueError("installed source drift: Git identity or working files changed since installation")
            if not args.check:
                print(source_api["describe"](installation_source))
        if args.guidance:
            guidance, guidance_source = parse_link(args.guidance)
            # Legacy setup created this exact link without recording it. Adopt only
            # with a recorded framework root AND its still-matching actual link.
            framework_link = state_path.parent / "codex-framework"
            old_root = previous_links.get(str(framework_link))
            legacy_owned = (
                old_root is not None and target_of(framework_link) == Path(old_root).resolve()
                and target_of(guidance) == (Path(old_root) / "templates/global/AGENTS.md").resolve()
            )
            merged_guidance = (
                guidance.is_file()
                and not guidance.is_symlink()
                and guidance_source.read_bytes() in guidance.read_bytes()
            )
            if str(guidance) in previous_links or legacy_owned or (not guidance.exists() and not guidance.is_symlink()):
                desired_links[guidance] = guidance_source
                if legacy_owned and not args.check and str(guidance) not in previous_links:
                    previous_links[str(guidance)] = str(target_of(guidance))
            elif merged_guidance:
                print(f"strict global guidance is active in preserved user-owned file: {guidance}")
            else:
                raise ValueError(
                    "strict global guidance is not active; user-owned collision preserved: "
                    f"{guidance}. Merge the framework agreement into that file or move it aside, then rerun setup"
                )
        desired_files = dict(parse_file(item) for item in args.file)
        desired_file_contents = {
            destination: source.read_bytes() for destination, source in desired_files.items()
        }
        overlap = set(desired_links).intersection(desired_files)
        if overlap:
            raise ValueError(f"path requested as both link and file: {sorted(map(str, overlap))[0]}")
        errors: list[str] = []
        for link, target in desired_links.items():
            if not link.exists() and not link.is_symlink():
                continue
            recorded = Path(previous_links[str(link)]).resolve(strict=False) if str(link) in previous_links else None
            if recorded is None or target_of(link) != recorded:
                errors.append(f"user-owned collision: {link}")
        for destination, source in desired_files.items():
            if not destination.exists() and not destination.is_symlink():
                continue
            previous_file = previous_files.get(str(destination))
            previous_link = previous_links.get(str(destination))
            managed_file_unchanged = (
                previous_file is not None
                and destination.is_file()
                and not destination.is_symlink()
                and digest(destination) == previous_file["sha256"]
            )
            managed_link_unchanged = (
                previous_link is not None
                and destination.is_symlink()
                and target_of(destination) == Path(previous_link).resolve(strict=False)
                and Path(previous_link).resolve(strict=False) == source
            )
            if not managed_file_unchanged and not managed_link_unchanged:
                errors.append(f"user-owned collision: {destination}")
        desired_paths = set(desired_links).union(desired_files)
        for link_text, recorded_text in previous_links.items():
            link = Path(link_text)
            if link in desired_paths or (not link.exists() and not link.is_symlink()):
                continue
            if target_of(link) != Path(recorded_text).resolve(strict=False):
                errors.append(f"managed link was replaced by user content: {link}")
        for destination_text, recorded in previous_files.items():
            destination = Path(destination_text)
            if destination in desired_paths or not destination.exists():
                continue
            if destination.is_symlink() or not destination.is_file() or digest(destination) != recorded["sha256"]:
                errors.append(f"managed file was replaced by user content: {destination}")
        if errors:
            raise ValueError("install preflight failed; no writes performed:\n- " + "\n- ".join(errors))
        if args.preflight:
            print(
                f"framework install preflight passed: {len(desired_links)} links, "
                f"{len(desired_files)} files"
            )
            return 0
        if args.check:
            expected_links = {str(link): str(target) for link, target in desired_links.items()}
            expected_files = {
                str(destination): {
                    "source": str(source),
                    "sha256": digest_bytes(desired_file_contents[destination]),
                }
                for destination, source in desired_files.items()
            }
            files_match = all(
                destination.is_file()
                and not destination.is_symlink()
                and destination.read_bytes() == desired_file_contents[destination]
                for destination, source in desired_files.items()
            )
            if (
                previous_links != expected_links
                or previous_files != expected_files
                or any(target_of(link) != target for link, target in desired_links.items())
                or not files_match
            ):
                raise ValueError("framework install state does not match requested links and files")
            print(
                f"framework installation is synchronized: {len(desired_links)} links, "
                f"{len(desired_files)} files"
            )
            return 0
        for link_text, recorded_text in previous_links.items():
            link = Path(link_text)
            if link not in desired_paths and link.is_symlink() and target_of(link) == Path(recorded_text).resolve(strict=False):
                link.unlink()
        for destination_text, recorded in previous_files.items():
            destination = Path(destination_text)
            if (
                destination not in desired_paths
                and destination.is_file()
                and not destination.is_symlink()
                and digest(destination) == recorded["sha256"]
            ):
                destination.unlink()
        for link, target in desired_links.items():
            link.parent.mkdir(parents=True, exist_ok=True)
            if link.is_symlink() and target_of(link) == target:
                continue
            if link.is_symlink():
                link.unlink()
            link.symlink_to(target, target_is_directory=target.is_dir())
        for destination, source in desired_files.items():
            destination.parent.mkdir(parents=True, exist_ok=True)
            content = desired_file_contents[destination]
            if (
                destination.is_file()
                and not destination.is_symlink()
                and destination.read_bytes() == content
            ):
                continue
            atomic_write(destination, content)
        payload = {
            "schemaVersion": 1,
            "managed": {
                str(k): str(v) for k, v in sorted(desired_links.items(), key=lambda x: str(x[0]))
            },
            "managedFiles": {
                str(destination): {
                    "source": str(source),
                    "sha256": digest_bytes(desired_file_contents[destination]),
                }
                for destination, source in sorted(desired_files.items(), key=lambda x: str(x[0]))
            },
        }
        if installation_source is not None:
            payload["sourceIdentity"] = installation_source
        state_path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(state_path, (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode())
        print(
            f"synchronized {len(desired_links)} framework-owned links and "
            f"{len(desired_files)} copied files"
        )
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.exit(1, f"framework link install error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
