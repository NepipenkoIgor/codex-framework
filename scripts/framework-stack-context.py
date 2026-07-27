#!/usr/bin/env python3
"""Resolve current stack releases or inspect an existing project without persisting snapshots."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import string
import sys
import tempfile
import urllib.parse
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCES = ROOT / "skills" / "version-sources.tsv"
USER_AGENT = "codex-framework-stack-context"
SUPPORTED_RELEASE_TRACKS = {"stable", "lts"}
PACKAGE_TECH = {
    "next": "nextjs",
    "react": "react",
    "@angular/core": "angular",
    "vue": "vue",
    "nuxt": "nuxt",
    "typescript": "typescript",
    "vite": "vite",
    "@nestjs/core": "nestjs",
    "elysia": "elysia",
    "react-native": "react-native",
    "expo": "expo",
    "firebase": "firebase",
    "stripe": "stripe",
    "openai": "openai",
    "ai": "ai-sdk",
    "@supabase/supabase-js": "supabase-js",
    "@supabase/ssr": "supabase-ssr",
    "n8n": "n8n",
}


def read_sources(path: Path) -> dict[str, dict[str, str]]:
    required = {"technology", "track", "resolver", "official_source", "action_template"}
    with path.open(newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows or set(rows[0]) != required:
        raise ValueError(f"invalid source registry columns: {path}")
    sources: dict[str, dict[str, str]] = {}
    for row in rows:
        if not all(row.values()):
            raise ValueError(f"incomplete source row: {row.get('technology', '<unknown>')}")
        name = row["technology"]
        if name in sources:
            raise ValueError(f"duplicate source row: {name}")
        if row["track"] not in SUPPORTED_RELEASE_TRACKS:
            raise ValueError(f"unsupported release track for {name}: {row['track']}")
        resolver = row["resolver"]
        if not (
            resolver.startswith("npm:")
            or resolver in {"node-lts", "dotnet-lts", "python-stable", "flutter-stable", "dart-stable"}
        ):
            raise ValueError(f"unsupported resolver: {resolver}")
        if not row["official_source"].startswith("https://"):
            raise ValueError(f"non-HTTPS official source: {name}")
        fields = {field for _, field, _, _ in string.Formatter().parse(row["action_template"]) if field}
        unknown_fields = fields - {"version", "major", "minor", "major_minor"}
        if unknown_fields:
            raise ValueError(f"unsupported action placeholder for {name}: {', '.join(sorted(unknown_fields))}")
        if re.search(r"@[v]?\d|sdk-\d|--framework\s+net\d", row["action_template"]):
            raise ValueError(f"numeric version pinned in action template: {name}")
        sources[name] = row
    return sources


def request_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read()
        if response.headers.get("Content-Encoding") == "gzip":
            raw = gzip.decompress(raw)
        return raw


def request_json(url: str) -> Any:
    return json.loads(request_bytes(url))


def version_parts(version: str) -> dict[str, str]:
    normalized = version.strip()
    match = re.fullmatch(r"v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?(?:\+[0-9A-Za-z.-]+)?", normalized)
    if not match:
        raise ValueError(f"stable/LTS resolver returned a non-release or prerelease value: {version}")
    major = match.group(1)
    minor = match.group(2) or "0"
    return {"version": version, "major": major, "minor": minor, "major_minor": f"{major}.{minor}"}


def resolve_npm(package: str) -> dict[str, Any]:
    encoded = urllib.parse.quote(package, safe="")
    metadata = request_json(f"https://registry.npmjs.org/{encoded}/latest")
    return {
        "version": metadata["version"],
        "engines": metadata.get("engines", {}),
        "peer_dependencies": metadata.get("peerDependencies", {}),
        "distribution": f"https://www.npmjs.com/package/{package}",
    }


def resolve_release(resolver: str) -> dict[str, Any]:
    if resolver.startswith("npm:"):
        return resolve_npm(resolver.removeprefix("npm:"))
    if resolver == "node-lts":
        releases = request_json("https://nodejs.org/dist/index.json")
        release = next(item for item in releases if item.get("lts"))
        return {"version": release["version"].removeprefix("v"), "lts": release["lts"], "released": release["date"]}
    if resolver == "dotnet-lts":
        data = request_json("https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json")
        release = next(
            item
            for item in data["releases-index"]
            if item.get("release-type") == "lts" and item.get("support-phase") in {"active", "maintenance"}
        )
        return {
            "version": release["latest-runtime"],
            "sdk": release["latest-sdk"],
            "channel": release["channel-version"],
            "eol": release.get("eol-date"),
        }
    if resolver == "python-stable":
        raw = request_bytes("https://www.python.org/downloads/")
        match = re.search(rb"Download Python ([0-9.]+)", raw)
        if not match:
            raise ValueError("could not resolve Python stable release")
        return {"version": match.group(1).decode()}
    if resolver in {"flutter-stable", "dart-stable"}:
        data = request_json("https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json")
        stable_hash = data["current_release"]["stable"]
        release = next(item for item in data["releases"] if item["hash"] == stable_hash)
        if resolver == "flutter-stable":
            return {"version": release["version"], "dart": release["dart_sdk_version"], "released": release["release_date"]}
        return {"version": release["dart_sdk_version"], "flutter": release["version"], "released": release["release_date"]}
    raise ValueError(f"unknown resolver: {resolver}")


def resolve_technology(row: dict[str, str]) -> dict[str, Any]:
    release = resolve_release(row["resolver"])
    parts = version_parts(release["version"])
    action = row["action_template"].format(**parts)
    return {
        "technology": row["technology"],
        "track": row["track"],
        **release,
        "official_source": row["official_source"],
        "action": action,
    }


def repository_boundary(root: Path) -> Path:
    """Use the nearest explicit VCS boundary; without one, never escape the requested root."""
    for directory in (root, *root.parents):
        if (directory / ".git").exists():
            return directory
    return root


def nearest_file(root: Path, filename: str) -> Path | None:
    boundary = repository_boundary(root)
    for directory in (root, *root.parents):
        if directory != boundary and boundary not in directory.parents:
            break
        candidate = directory / filename
        if candidate.is_file():
            return candidate
        if directory == boundary:
            break
    return None


def package_lock_versions(root: Path) -> dict[str, str]:
    lock_path = nearest_file(root, "package-lock.json")
    if lock_path is None:
        return {}
    try:
        lock = json.loads(lock_path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}
    packages = lock.get("packages", {})
    relative = root.relative_to(lock_path.parent).as_posix()
    prefix = "" if relative == "." else f"{relative}/"
    legacy = lock.get("dependencies", {})
    return {
        package: packages.get(f"{prefix}node_modules/{package}", {}).get("version", "")
        or legacy.get(package, {}).get("version", "")
        for package in PACKAGE_TECH
    }


def text_lock_versions(root: Path, declared: dict[str, str]) -> dict[str, str]:
    """Read exact package versions from pnpm, Yarn, or text Bun lockfiles."""
    resolved: dict[str, str] = {}
    pnpm = nearest_file(root, "pnpm-lock.yaml")
    if pnpm:
        text = pnpm.read_text(errors="ignore")
        importer = root.relative_to(pnpm.parent).as_posix() or "."
        block = re.search(rf"(?ms)^  ['\"]?{re.escape(importer)}['\"]?:\s*\n(?P<body>.*?)(?=^  \S.*?:\s*$|\Z)", text)
        if block:
            body = block.group("body")
            for package in declared:
                match = re.search(rf"(?ms)^      ['\"]?{re.escape(package)}['\"]?:\s*\n(?P<body>.*?)(?=^      \S.*?:\s*$|\Z)", body)
                version = re.search(r"(?m)^\s+version:\s*['\"]?([^'\"\s(]+)", match.group("body")) if match else None
                if version:
                    resolved[package] = version.group(1)
    yarn = nearest_file(root, "yarn.lock")
    if yarn:
        text = yarn.read_text(errors="ignore")
        for package, specifier in declared.items():
            match = re.search(
                rf"(?ms)^['\"]?{re.escape(package)}@(?:npm:)?{re.escape(specifier)}['\"]?:\s*\n(?P<body>(?:[ \t]+.*\n)*)",
                text,
            )
            if match:
                version = re.search(r"(?m)^\s+version(?:\s+|:\s*)['\"]?([0-9][^'\"\s]+)", match.group("body"))
                resolution = re.search(rf"(?m)^\s+resolution:\s*['\"]{re.escape(package)}@(?:npm:)?([0-9][^'\"\s]+)", match.group("body"))
                selected = version or resolution
                if selected:
                    resolved.setdefault(package, selected.group(1))
    bun = nearest_file(root, "bun.lock")
    if bun:
        text = bun.read_text(errors="ignore")
        for package in declared:
            match = re.search(
                rf"(?m)^\s*['\"]{re.escape(package)}['\"]\s*:\s*\[['\"]{re.escape(package)}@([0-9][^'\"]+)",
                text,
            )
            if match:
                resolved.setdefault(package, match.group(1))
    return resolved


def dependency_lock_versions(root: Path, declared: dict[str, str]) -> dict[str, str]:
    candidates = [path for name in ("package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lock") if (path := nearest_file(root, name))]
    if not candidates:
        return {}
    nearest = min(candidates, key=lambda path: len(root.relative_to(path.parent).parts))
    if nearest.name == "package-lock.json":
        return package_lock_versions(root)
    return text_lock_versions(root, declared)


def inspect_project(root: Path) -> dict[str, Any]:
    root = root.resolve()
    if not root.is_dir():
        raise ValueError(f"project path does not exist or is not a directory: {root}")
    detected: list[dict[str, Any]] = []
    markers = 0
    package_path = root / "package.json"
    if package_path.is_file():
        markers += 1
        package = json.loads(package_path.read_text())
        declared = {}
        for section in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
            declared.update(package.get(section, {}))
        locked = dependency_lock_versions(root, declared)
        for package_name, technology in PACKAGE_TECH.items():
            if package_name in declared:
                installed_path = root / "node_modules" / package_name / "package.json"
                installed = ""
                if installed_path.is_file():
                    try:
                        installed = json.loads(installed_path.read_text()).get("version", "")
                    except (OSError, json.JSONDecodeError):
                        pass
                locked_version = locked.get(package_name) or ""
                drift = bool(locked_version and installed and locked_version != installed)
                detected.append({
                    "technology": technology,
                    "declared": declared[package_name],
                    "resolved": locked_version or installed or None,
                    "locked": locked_version or None,
                    "installed": installed or None,
                    "authority": "lockfile" if locked_version else ("installed" if installed else "manifest-only"),
                    "blocking_drift": drift,
                    "evidence": str(package_path),
                })
        engines = package.get("engines", {})
        if engines.get("node"):
            detected.append({"technology": "nodejs", "declared": engines["node"], "resolved": None, "evidence": str(package_path)})
        manager = package.get("packageManager", "")
        if manager.startswith("bun@"):
            detected.append({"technology": "bun", "declared": manager.split("@", 1)[1], "resolved": None, "evidence": str(package_path)})
        workspaces = package.get("workspaces", [])
        if isinstance(workspaces, dict):
            workspaces = workspaces.get("packages", [])
        for pattern in workspaces if isinstance(workspaces, list) else []:
            for workspace_manifest in sorted(root.glob(f"{pattern}/package.json")):
                child = inspect_project(workspace_manifest.parent)
                detected.extend(child["detected"])
    for filename in (".nvmrc", ".node-version"):
        path = root / filename
        if path.is_file():
            markers += 1
            detected.append({"technology": "nodejs", "declared": path.read_text().strip(), "resolved": None, "evidence": str(path)})
    if (root / "bun.lock").exists() or (root / "bun.lockb").exists():
        markers += 1
        if not any(item["technology"] == "bun" for item in detected):
            lock = root / ("bun.lock" if (root / "bun.lock").exists() else "bun.lockb")
            detected.append({"technology": "bun", "declared": "lockfile present", "resolved": None, "evidence": str(lock)})
    global_json = root / "global.json"
    if global_json.is_file():
        markers += 1
        sdk = json.loads(global_json.read_text()).get("sdk", {}).get("version")
        if sdk:
            detected.append({"technology": "dotnet", "declared": sdk, "resolved": None, "evidence": str(global_json)})
    for project in sorted(root.rglob("*.csproj")):
        if any(part in {"bin", "obj", "node_modules"} for part in project.parts):
            continue
        for framework in re.findall(r"<TargetFrameworks?>([^<]+)</TargetFrameworks?>", project.read_text(errors="ignore")):
            markers += 1
            detected.append({"technology": "dotnet", "declared": framework, "resolved": None, "evidence": str(project)})
    pyproject = root / "pyproject.toml"
    if pyproject.is_file():
        markers += 1
        try:
            import tomllib

            data = tomllib.loads(pyproject.read_text())
            requires = data.get("project", {}).get("requires-python")
            if requires:
                detected.append({"technology": "python", "declared": requires, "resolved": None, "evidence": str(pyproject)})
        except (ImportError, OSError, ValueError):
            pass
    python_version = root / ".python-version"
    if python_version.is_file():
        markers += 1
        detected.append({"technology": "python", "declared": python_version.read_text().strip(), "resolved": None, "evidence": str(python_version)})
    pubspec = root / "pubspec.yaml"
    if pubspec.is_file():
        markers += 1
        text = pubspec.read_text()
        environment = re.search(r"(?ms)^environment:\s*\n(?P<body>(?:^[ \t]+.*\n?)*)", text)
        sdk = re.search(r"(?m)^\s+sdk:\s*['\"]?([^'\"\n]+)", environment.group("body")) if environment else None
        flutter = re.search(r"(?m)^\s+flutter:\s*['\"]?([^'\"\n]+)", environment.group("body")) if environment else None
        if sdk:
            detected.append({"technology": "dart", "declared": sdk.group(1).strip(), "resolved": None, "evidence": str(pubspec)})
        if flutter:
            detected.append({"technology": "flutter", "declared": flutter.group(1).strip(), "resolved": None, "evidence": str(pubspec)})
    if not markers:
        raise ValueError(f"no supported project manifest found: {root}")
    return {
        "mode": "existing-project",
        "root": str(root),
        "boundary": str(repository_boundary(root)),
        "detected": detected,
        "blocking_drift": [item["technology"] for item in detected if item.get("blocking_drift")],
    }


def render(payload: dict[str, Any], output_format: str) -> None:
    if output_format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
        return
    if payload["mode"] == "latest":
        for item in payload["technologies"]:
            print(f"- {item['technology']}: {item['version']} ({item['track']})")
            print(f"  action: {item['action']}")
            if item.get("engines"):
                print(f"  engines: {json.dumps(item['engines'], sort_keys=True)}")
            if item.get("peer_dependencies"):
                print(f"  peers: {json.dumps(item['peer_dependencies'], sort_keys=True)}")
            print(f"  source: {item['official_source']}")
    else:
        print(f"project: {payload['root']}")
        for item in payload["detected"]:
            resolved = f", resolved {item['resolved']}" if item.get("resolved") else ""
            print(f"- {item['technology']}: declared {item['declared']}{resolved} ({item['evidence']})")
            if item.get("blocking_drift"):
                print(f"  BLOCKED drift: lockfile {item['locked']} != installed {item['installed']}; lockfile remains authority")


def self_test(sources: dict[str, dict[str, str]]) -> None:
    assert sources["expo"]["action_template"].format(version="99.1.2", major="99", minor="1", major_minor="99.1").endswith("sdk-99")
    assert sources["ai-sdk"]["resolver"] == "npm:ai"
    assert sources["supabase-js"]["resolver"] == "npm:@supabase/supabase-js"
    assert sources["supabase-ssr"]["resolver"] == "npm:@supabase/ssr"
    assert sources["n8n"]["resolver"] == "npm:n8n"
    assert PACKAGE_TECH["ai"] == "ai-sdk"
    assert PACKAGE_TECH["@supabase/supabase-js"] == "supabase-js"
    assert PACKAGE_TECH["@supabase/ssr"] == "supabase-ssr"
    assert PACKAGE_TECH["n8n"] == "n8n"
    with tempfile.TemporaryDirectory(prefix="codex-stack-context-") as directory:
        root = Path(directory)
        (root / "package.json").write_text(
            json.dumps({"dependencies": {"next": "^16.0.0", "react": "^19.0.0", "ai": "^98.0.0", "@supabase/supabase-js": "^97.0.0", "@supabase/ssr": "^96.0.0", "n8n": "^95.0.0"}, "engines": {"node": ">=24"}})
        )
        (root / "package-lock.json").write_text(
            json.dumps({"packages": {"node_modules/next": {"version": "16.2.0"}, "node_modules/react": {"version": "19.2.0"}, "node_modules/ai": {"version": "98.3.1"}, "node_modules/@supabase/supabase-js": {"version": "97.4.2"}, "node_modules/@supabase/ssr": {"version": "96.3.1"}, "node_modules/n8n": {"version": "95.2.4"}}})
        )
        context = inspect_project(root)
        indexed = {item["technology"]: item for item in context["detected"] if item["technology"] != "nodejs"}
        assert indexed["nextjs"]["resolved"] == "16.2.0"
        assert indexed["react"]["resolved"] == "19.2.0"
        assert indexed["ai-sdk"]["resolved"] == "98.3.1"
        assert indexed["supabase-js"]["declared"] == "^97.0.0"
        assert indexed["supabase-js"]["resolved"] == "97.4.2"
        assert indexed["supabase-ssr"]["declared"] == "^96.0.0"
        assert indexed["supabase-ssr"]["resolved"] == "96.3.1"
        assert indexed["n8n"]["declared"] == "^95.0.0"
        assert indexed["n8n"]["resolved"] == "95.2.4"
        assert any(item["technology"] == "nodejs" and item["declared"] == ">=24" for item in context["detected"])
        installed_next = root / "node_modules" / "next"
        installed_next.mkdir(parents=True)
        (installed_next / "package.json").write_text(json.dumps({"version": "17.0.0-beta.1"}))
        drift_context = inspect_project(root)
        drift_next = next(item for item in drift_context["detected"] if item["technology"] == "nextjs")
        assert drift_next["resolved"] == "16.2.0"
        assert drift_next["installed"] == "17.0.0-beta.1"
        assert drift_next["blocking_drift"] is True
        (root / "package-lock.json").unlink()
        pnpm_root = root / "pnpm"
        pnpm_root.mkdir()
        (pnpm_root / "package.json").write_text(json.dumps({"dependencies": {"next": "^99.0.0"}}))
        (pnpm_root / "pnpm-lock.yaml").write_text(
            "importers:\n  .:\n    dependencies:\n      next:\n        specifier: ^99.0.0\n        version: 99.4.2\n"
            "packages:\n  next@18.0.0:\n    resolution: {}\n  next@99.4.2:\n    resolution: {}\n"
        )
        pnpm_context = inspect_project(pnpm_root)
        assert pnpm_context["detected"][0]["resolved"] == "99.4.2"
        bun_root = root / "bun"
        bun_root.mkdir()
        (bun_root / "package.json").write_text(json.dumps({"dependencies": {"next": "^88.0.0"}}))
        (bun_root / "bun.lock").write_text('"next": ["next@88.1.0", "", {}, "sha"]\n')
        assert inspect_project(bun_root)["detected"][0]["resolved"] == "88.1.0"
        npm_v1 = root / "npm-v1"
        npm_v1.mkdir()
        (npm_v1 / "package.json").write_text(json.dumps({"dependencies": {"react": "^77.0.0"}}))
        (npm_v1 / "package-lock.json").write_text(json.dumps({"lockfileVersion": 1, "dependencies": {"react": {"version": "77.2.0"}}}))
        assert inspect_project(npm_v1)["detected"][0]["resolved"] == "77.2.0"
        monorepo = root / "monorepo"
        app = monorepo / "apps" / "web"
        app.mkdir(parents=True)
        (monorepo / "package.json").write_text(json.dumps({"private": True, "workspaces": ["apps/*"]}))
        (app / "package.json").write_text(json.dumps({"dependencies": {"next": "^66.0.0"}}))
        (monorepo / ".git").mkdir()
        (monorepo / "package-lock.json").write_text(json.dumps({"packages": {"apps/web/node_modules/next": {"version": "66.3.0"}}}))
        monorepo_context = inspect_project(monorepo)
        assert any(item["technology"] == "nextjs" for item in monorepo_context["detected"])
        assert inspect_project(app)["detected"][0]["resolved"] == "66.3.0"
        isolated_parent = root / "unrelated-parent"
        isolated_child = isolated_parent / "child"
        isolated_child.mkdir(parents=True)
        (isolated_parent / "package-lock.json").write_text(json.dumps({"packages": {"child/node_modules/next": {"version": "99.9.9"}}}))
        (isolated_child / "package.json").write_text(json.dumps({"dependencies": {"next": "^16.0.0"}}))
        assert inspect_project(isolated_child)["detected"][0]["resolved"] is None
        try:
            inspect_project(root / "missing")
        except ValueError:
            pass
        else:
            raise AssertionError("missing project path was accepted")
        invalid_sources = root / "invalid-sources.tsv"
        invalid_sources.write_text(
            "technology\ttrack\tresolver\tofficial_source\taction_template\n"
            "nextjs\tstable\tnpm:next\thttps://nextjs.org/blog\tnpx create-next-app@{majr}\n"
        )
        try:
            read_sources(invalid_sources)
        except ValueError:
            pass
        else:
            raise AssertionError("invalid action placeholder was accepted")
        invalid_sources.write_text(
            "technology\ttrack\tresolver\tofficial_source\taction_template\n"
            "nextjs\tstable\tnpm:next\thttps://nextjs.org/blog\tnpx create-next-app@16\n"
        )
        try:
            read_sources(invalid_sources)
        except ValueError:
            pass
        else:
            raise AssertionError("numeric action pin was accepted")
        invalid_sources.write_text(
            "technology\ttrack\tresolver\tofficial_source\taction_template\n"
            "nextjs\tpreview\tnpm:next\thttps://nextjs.org/blog\tnpx create-next-app@latest\n"
        )
        try:
            read_sources(invalid_sources)
        except ValueError:
            pass
        else:
            raise AssertionError("preview release track was accepted")
        try:
            version_parts("17.0.0-beta.1")
        except ValueError:
            pass
        else:
            raise AssertionError("prerelease was accepted as stable/LTS")
        runtime_only = root / "runtime-only"
        runtime_only.mkdir()
        (runtime_only / ".nvmrc").write_text("24\n")
        assert inspect_project(runtime_only)["detected"][0]["technology"] == "nodejs"
        node_version_only = root / "node-version-only"
        node_version_only.mkdir()
        (node_version_only / ".node-version").write_text("24.1.0\n")
        assert inspect_project(node_version_only)["detected"][0]["declared"] == "24.1.0"
        bun_binary_only = root / "bun-binary-only"
        bun_binary_only.mkdir()
        (bun_binary_only / "bun.lockb").write_bytes(b"BUNLOCKB")
        assert inspect_project(bun_binary_only)["detected"][0]["evidence"].endswith("bun.lockb")
    print("stack context self-test: passed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=Path, default=DEFAULT_SOURCES)
    subparsers = parser.add_subparsers(dest="command", required=True)
    latest = subparsers.add_parser("latest")
    latest.add_argument("technologies", nargs="*")
    latest.add_argument("--format", choices=("json", "markdown"), default="json")
    project = subparsers.add_parser("project")
    project.add_argument("path", nargs="?", type=Path, default=Path.cwd())
    project.add_argument("--format", choices=("json", "markdown"), default="json")
    action = subparsers.add_parser("action")
    action.add_argument("technology")
    subparsers.add_parser("self-test")
    args = parser.parse_args()
    sources = read_sources(args.sources)
    if args.command == "self-test":
        self_test(sources)
        return
    if args.command == "project":
        render(inspect_project(args.path), args.format)
        return
    if args.command == "action":
        requested = [args.technology]
    elif args.technologies:
        requested = args.technologies
    else:
        requested = list(sources)
    unknown = [name for name in requested if name not in sources]
    if unknown:
        raise SystemExit(f"unknown technologies: {', '.join(unknown)}")
    resolved = [resolve_technology(sources[name]) for name in requested]
    if args.command == "action":
        print(resolved[0]["action"])
        return
    render({"mode": "latest", "technologies": resolved}, args.format)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, urllib.error.URLError) as error:
        print(f"stack context error: {error}", file=sys.stderr)
        raise SystemExit(1)
