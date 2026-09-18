#!/usr/bin/env python3
"""Fail closed when the official Codex release/documentation review is stale or incomplete."""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import re
import subprocess
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
LEDGER = ROOT / "docs" / "native-capability-ledger.json"
MAX_AGE = dt.timedelta(days=7)
DECISIONS = {"adopted", "replaced", "removed", "retained", "permission-gated"}
SOURCE_KINDS = {"manual", "changelog", "release"}
OFFICIAL_HOSTS = {"developers.openai.com", "learn.chatgpt.com", "github.com", "api.github.com"}
TOP_KEYS = {
    "schemaVersion", "reviewedAt", "codexVersion", "baselineReleaseTag", "latestReleaseTag",
    "changelogReviewedThrough", "sources", "releaseCoverage", "capabilities",
}
CAPABILITY_KEYS = {"id", "nativeFeature", "decision", "localOverlap", "action", "evidence"}
RELEASE_KEYS = {"tag", "publishedAt", "capabilityIds"}


def command_text(*command: str) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    return (result.stdout or result.stderr).strip() if result.returncode == 0 else ""


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def release_version(tag: str) -> tuple[int, int, int]:
    match = re.fullmatch(r"rust-v(\d+)\.(\d+)\.(\d+)", tag)
    if not match:
        raise ValueError(f"invalid stable release tag: {tag}")
    return tuple(int(value) for value in match.groups())


STABLE_RELEASE_TAG = re.compile(r"(?:rust|python)-v\d+\.\d+\.\d+")


def changelog_dates(body: str) -> list[dt.date]:
    values = set(re.findall(r"(?<!\d)(\d{4}-[01]\d-[0-3]\d)(?!\d)", body))
    dates: list[dt.date] = []
    for value in values:
        try:
            dates.append(dt.date.fromisoformat(value))
        except ValueError:
            continue
    return sorted(dates)


class MainContent(HTMLParser):
    """Canonical documentation content, excluding site chrome and executable assets."""
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.inside = 0
        self.skip = 0
        self.parts: list[str] = []
        self.found = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "main":
            self.inside += 1
            self.found = True
        if not self.inside:
            return
        if tag in {"script", "style", "nav", "footer", "header"}:
            self.skip += 1
        if not self.skip:
            if tag in {"a", "img"}:
                for key, value in attrs:
                    if key in {"href", "src", "alt"} and value:
                        self.parts.append(f"{tag}:{key}={value}")
            if tag in {"p", "li", "pre", "code", "h1", "h2", "h3", "h4", "tr", "td", "th"}:
                self.parts.append(f"<{tag}>")

    def handle_endtag(self, tag: str) -> None:
        if self.inside and tag in {"script", "style", "nav", "footer", "header"}:
            self.skip = max(0, self.skip - 1)
        if tag == "main":
            self.inside = max(0, self.inside - 1)

    def handle_data(self, data: str) -> None:
        if self.inside and not self.skip and data.strip():
            self.parts.append(data)


def document_snapshot(raw: bytes) -> bytes:
    parser = MainContent()
    parser.feed(raw.decode("utf-8", errors="strict"))
    if not parser.found or not parser.parts:
        raise ValueError("official documentation response has no main content")
    return json.dumps(parser.parts, ensure_ascii=False, separators=(",", ":")).encode()


def release_snapshot(value: object) -> bytes:
    if not isinstance(value, dict):
        raise ValueError("release API response is not an object")
    stable = {
        key: value.get(key)
        for key in ("tag_name", "name", "body", "published_at", "target_commitish", "html_url")
    }
    return json.dumps(stable, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def source_url(data: dict[str, object], kind: str) -> str:
    for source in data.get("sources", []):
        if isinstance(source, dict) and source.get("kind") == kind and isinstance(source.get("url"), str):
            return source["url"]
    raise ValueError(f"missing source URL: {kind}")


def validate(data: dict[str, object], now: dt.datetime | None = None) -> list[str]:
    failures: list[str] = []
    now = now or dt.datetime.now(dt.timezone.utc)
    if set(data) != TOP_KEYS or data.get("schemaVersion") != 3:
        failures.append("ledger top-level schema is missing or unexpected")
    try:
        reviewed_at = dt.datetime.fromisoformat(str(data["reviewedAt"]))
        if reviewed_at.tzinfo is None:
            raise ValueError("timezone missing")
        age = now - reviewed_at.astimezone(dt.timezone.utc)
        if age < dt.timedelta(0) or age > MAX_AGE:
            failures.append("official Codex capability review is outside the seven-day freshness window")
    except (KeyError, TypeError, ValueError):
        failures.append("reviewedAt is missing or invalid")
    current_codex = command_text("codex", "--version")
    if not current_codex or data.get("codexVersion") != current_codex:
        failures.append("ledger codexVersion does not match the active Codex runtime")
    release_tag = data.get("latestReleaseTag")
    if not isinstance(release_tag, str) or not release_tag.startswith("rust-v") \
            or current_codex.removeprefix("codex-cli ") not in release_tag:
        failures.append("latestReleaseTag does not match the reviewed Codex runtime")
    baseline_tag = data.get("baselineReleaseTag")
    try:
        baseline_valid = isinstance(baseline_tag, str) and isinstance(release_tag, str) \
            and release_version(baseline_tag) < release_version(release_tag)
    except ValueError:
        baseline_valid = False
    if not baseline_valid:
        failures.append("baselineReleaseTag is missing, invalid, or does not precede the reviewed release")
    try:
        through = dt.date.fromisoformat(str(data["changelogReviewedThrough"]))
        if through > now.date():
            failures.append("changelogReviewedThrough is in the future")
    except (KeyError, TypeError, ValueError):
        failures.append("changelogReviewedThrough is missing or invalid")

    sources = data.get("sources")
    seen_kinds: set[str] = set()
    if not isinstance(sources, list) or len(sources) < 3:
        failures.append("manual, changelog, and release sources are required")
    else:
        for source in sources:
            if not isinstance(source, dict) or set(source) != {"kind", "url", "sha256"}:
                failures.append("source entry is malformed")
                continue
            kind = source.get("kind")
            url = source.get("url")
            if kind not in SOURCE_KINDS:
                failures.append(f"unsupported source kind: {kind}")
            else:
                seen_kinds.add(str(kind))
            if not isinstance(url, str) or urlparse(url).scheme != "https" or urlparse(url).hostname not in OFFICIAL_HOSTS:
                failures.append(f"source is not an allowed official HTTPS URL: {url}")
            fingerprint = source.get("sha256")
            if not isinstance(fingerprint, str) or not re.fullmatch(r"[0-9a-f]{64}", fingerprint):
                failures.append(f"source fingerprint is malformed: {kind}")
        if seen_kinds != SOURCE_KINDS:
            failures.append("source coverage must include manual, changelog, and release")

    capabilities = data.get("capabilities")
    identifiers: set[str] = set()
    decisions: set[str] = set()
    if not isinstance(capabilities, list) or not capabilities:
        failures.append("capability decisions are missing")
    else:
        for capability in capabilities:
            if not isinstance(capability, dict) or set(capability) != CAPABILITY_KEYS:
                failures.append("capability entry is malformed")
                continue
            identifier = capability.get("id")
            if not isinstance(identifier, str) or not identifier or identifier in identifiers:
                failures.append(f"capability id is missing or duplicated: {identifier}")
            else:
                identifiers.add(identifier)
            decision = capability.get("decision")
            if decision not in DECISIONS:
                failures.append(f"unsupported capability decision: {decision}")
            else:
                decisions.add(str(decision))
            for key in ("nativeFeature", "localOverlap", "action"):
                if not isinstance(capability.get(key), str) or not str(capability[key]).strip():
                    failures.append(f"{identifier}.{key} is empty")
            evidence = capability.get("evidence")
            if not isinstance(evidence, list) or not evidence:
                failures.append(f"{identifier}.evidence is empty")
                continue
            for value in evidence:
                if not isinstance(value, str) or Path(value).is_absolute() or not (ROOT / value).exists():
                    failures.append(f"{identifier} has missing or external evidence: {value}")
        if not {"adopted", "removed", "permission-gated"}.issubset(decisions):
            failures.append("ledger must demonstrate adopted, removed, and permission-gated decisions")
    coverage = data.get("releaseCoverage")
    coverage_tags: list[str] = []
    coverage_published: list[dt.datetime] = []
    if not isinstance(coverage, list) or not coverage:
        failures.append("stable release coverage is missing")
    else:
        for release in coverage:
            if not isinstance(release, dict) or set(release) != RELEASE_KEYS:
                failures.append("release coverage entry is malformed")
                continue
            tag = release.get("tag")
            if not isinstance(tag, str) or not STABLE_RELEASE_TAG.fullmatch(tag) or tag in coverage_tags:
                failures.append(f"release coverage tag is missing or duplicated: {tag}")
            else:
                coverage_tags.append(tag)
            try:
                published = dt.datetime.fromisoformat(str(release.get("publishedAt")).replace("Z", "+00:00"))
                if published.tzinfo is None:
                    raise ValueError("timezone missing")
                coverage_published.append(published.astimezone(dt.timezone.utc))
            except ValueError:
                failures.append(f"release coverage timestamp is invalid: {tag}")
            capability_ids = release.get("capabilityIds")
            if not isinstance(capability_ids, list) or not capability_ids or len(set(capability_ids)) != len(capability_ids):
                failures.append(f"release coverage capabilityIds are missing or duplicated: {tag}")
            elif any(identifier not in identifiers for identifier in capability_ids):
                failures.append(f"release coverage references an unknown capability: {tag}")
        if coverage_tags and coverage_tags[-1] != data.get("latestReleaseTag"):
            failures.append("release coverage must end at latestReleaseTag")
        if coverage_published != sorted(coverage_published) or len(set(coverage_published)) != len(coverage_published):
            failures.append("release coverage timestamps must be unique and ordered")
    return failures


def live_failures(data: dict[str, object]) -> list[str]:
    failures: list[str] = []
    sources = {
        source["kind"]: source
        for source in data.get("sources", [])
        if isinstance(source, dict) and source.get("kind") in SOURCE_KINDS and isinstance(source.get("url"), str)
    }
    bodies: dict[str, str] = {}
    for kind in ("manual", "changelog"):
        try:
            docs_request = urllib.request.Request(
                sources[kind]["url"], headers={"User-Agent": "ai-codex-framework-capability-check"}
            )
            with urllib.request.urlopen(docs_request, timeout=20) as response:
                raw = response.read()
            bodies[kind] = document_snapshot(raw).decode("utf-8")
            current_fingerprint = sha256_bytes(document_snapshot(raw))
            if current_fingerprint != sources[kind].get("sha256"):
                failures.append(
                    f"official Codex {kind} content changed: ledger fingerprint {sources[kind].get('sha256')}, current {current_fingerprint}"
                )
        except Exception as error:  # documentation lookup must fail closed for a release
            failures.append(f"official Codex {kind} lookup failed: {error}")
    if "manual" in bodies and "codex" not in bodies["manual"].lower():
        failures.append("official Codex manual response did not contain the expected product content")
    if "changelog" in bodies:
        dates = changelog_dates(bodies["changelog"])
        reviewed_through = dt.date.fromisoformat(str(data["changelogReviewedThrough"]))
        if not dates:
            failures.append("official Codex changelog response contained no dated entries")
        elif max(dates) > reviewed_through:
            failures.append(
                f"native capability ledger missed changelog delta: reviewed through {reviewed_through}, latest entry is {max(dates)}"
            )
        if str(data["changelogReviewedThrough"]) not in bodies["changelog"]:
            failures.append("reviewed changelog boundary is absent from the current official changelog")
    request = urllib.request.Request(
        source_url(data, "release"),
        headers={"Accept": "application/vnd.github+json", "User-Agent": "ai-codex-framework-capability-check"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            latest = json.load(response)
    except Exception as error:  # network/provider failure must remain a release blocker
        failures.append(f"official Codex latest-release lookup failed: {error}")
        return failures
    tag = latest.get("tag_name") if isinstance(latest, dict) else None
    if tag != data.get("latestReleaseTag"):
        failures.append(f"native capability ledger is stale: reviewed {data.get('latestReleaseTag')}, latest stable is {tag}")
    else:
        current_fingerprint = sha256_bytes(release_snapshot(latest))
        if current_fingerprint != sources["release"].get("sha256"):
            failures.append(
                f"official Codex release content changed: ledger fingerprint {sources['release'].get('sha256')}, current {current_fingerprint}"
            )
    releases_url = "https://api.github.com/repos/openai/codex/releases?per_page=100"
    try:
        releases_request = urllib.request.Request(
            releases_url, headers={"Accept": "application/vnd.github+json", "User-Agent": "ai-codex-framework-capability-check"}
        )
        with urllib.request.urlopen(releases_request, timeout=20) as response:
            releases = json.load(response)
        stable = [item for item in reversed(releases)
                  if isinstance(item, dict) and not item.get("draft") and not item.get("prerelease")]
        stable_tags = [item.get("tag_name") for item in stable]
        baseline = data.get("baselineReleaseTag")
        latest_tag = data.get("latestReleaseTag")
        start = stable_tags.index(baseline) + 1
        end = stable_tags.index(latest_tag) + 1
        expected = stable_tags[start:end]
        recorded = [item.get("tag") for item in data.get("releaseCoverage", []) if isinstance(item, dict)]
        if recorded != expected:
            failures.append(f"stable release coverage is incomplete: expected {expected}, recorded {recorded}")
        published_by_tag = {item.get("tag_name"): item.get("published_at") for item in stable}
        for item in data.get("releaseCoverage", []):
            if isinstance(item, dict) and published_by_tag.get(item.get("tag")) != item.get("publishedAt"):
                failures.append(f"stable release timestamp drifted: {item.get('tag')}")
    except Exception as error:
        failures.append(f"official Codex stable-release coverage lookup failed: {error}")
    return failures


def self_test(data: dict[str, object]) -> None:
    first = b'<html><script>build1</script><main><p>Codex rule</p></main></html>'
    chrome = b'<html><script>build2</script><main class="new"><p>Codex rule</p></main></html>'
    assert document_snapshot(first) == document_snapshot(chrome)
    assert document_snapshot(first) != document_snapshot(first.replace(b'Codex rule', b'Changed rule'))
    try:
        document_snapshot(b'<html>login page</html>')
    except ValueError:
        pass
    else:
        raise AssertionError("missing document content accepted")
    future = dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=30)
    assert validate(data, future), "stale ledger counterexample was accepted"
    invalid = copy.deepcopy(data)
    invalid["capabilities"][0]["decision"] = "invented"
    assert any("unsupported capability decision" in item for item in validate(invalid)), "unknown decision was accepted"
    invalid = copy.deepcopy(data)
    invalid["capabilities"][0]["evidence"] = ["missing-native-capability-evidence"]
    assert any("missing or external evidence" in item for item in validate(invalid)), "missing evidence was accepted"
    invalid = copy.deepcopy(data)
    invalid["sources"][0]["sha256"] = "not-a-digest"
    assert any("source fingerprint is malformed" in item for item in validate(invalid)), "malformed source digest was accepted"
    invalid = copy.deepcopy(data)
    for source in invalid["sources"]:
        if source["kind"] == "release":
            source["url"] = "https://api.github.com/repos/openai/codex/releases/tags/rust-v0.149.0"
    assert source_url(invalid, "release").endswith("/releases/tags/rust-v0.149.0"), \
        "live release lookup is not sourced from the recorded ledger URL"
    assert changelog_dates("released 2027-01-15 and 2026-12-31") == [dt.date(2026, 12, 31), dt.date(2027, 1, 15)], \
        "changelog date parsing is tied to one year"
    invalid = copy.deepcopy(data)
    invalid["releaseCoverage"] = invalid["releaseCoverage"][:-1]
    assert any("release coverage" in item for item in validate(invalid)), \
        "partial stable-release coverage was accepted"
    print("native capability ledger self-test: passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        data = json.loads(args.ledger.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"native capability ledger is unreadable: {error}")
        return 1
    if args.self_test:
        self_test(data)
        return 0
    failures = validate(data)
    if args.live and not failures:
        failures.extend(live_failures(data))
    if failures:
        print("native capability review failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    mode = "live" if args.live else "static"
    print(f"native capability review passed ({mode}): {data['latestReleaseTag']} through {data['changelogReviewedThrough']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
