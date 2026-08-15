#!/usr/bin/env python3
"""Create reviewable quality-contract scaffolds for new or migrated skills.

Scaffolds are deliberately not evidence of certification.  The strict quality
gate validates them, and model-backed runs must still prove every assertion.
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTRACT_ROOT = ROOT / "evals" / "skills"
STOP = {
    "a", "an", "and", "as", "at", "by", "for", "from", "in", "including", "into", "of", "on",
    "or", "the", "to", "using", "with", "when", "use", "implement", "design", "build", "write",
}
TECH_PATTERNS = {
    "nextjs": r"\bnext(?:\.js|js)\b", "react": r"\breact\b", "angular": r"\bangular\b",
    "vue": r"\bvue\b", "nuxt": r"\bnuxt\b", "typescript": r"\btypescript\b|\btsx?\b",
    "vite": r"\bvite\b", "nodejs": r"\bnode(?:\.js|js)\b", "nestjs": r"\bnestjs\b",
    "bun": r"\bbun\b", "elysia": r"\belysia\b", "dotnet": r"\b\.net\b|\basp\.net\b",
    "python": r"\bpython\b|\bpytest\b", "react-native": r"\breact native\b",
    "expo": r"\bexpo\b|\beas\b", "flutter": r"\bflutter\b", "dart": r"\bdart\b",
    "firebase": r"\bfirebase\b|\bfirestore\b", "stripe": r"\bstripe\b", "openai": r"\bopenai\b",
}
MUTATING = re.compile(
    r"\b(implement|build|create|configure|deploy|migrate|provision|upload|payment|billing|auth|"
    r"notification|job|queue|storage|database|infrastructure|workflow|release|environment)\b", re.I
)


def frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(errors="ignore")
    block = text.split("---", 2)[1]
    result: dict[str, str] = {}
    for line in block.splitlines():
        match = re.match(r"^(name|description):\s*(.*)$", line)
        if match:
            result[match.group(1)] = match.group(2).strip()
    return result


def manifests() -> tuple[dict[str, list[str]], dict[str, str]]:
    catalogs: dict[str, list[str]] = {}
    paths = {"core": ROOT / "skills" / "core.txt"}
    paths.update({path.stem: path for path in sorted((ROOT / "skills" / "packs").glob("*.txt"))})
    owners: dict[str, str] = {}
    for catalog, path in paths.items():
        catalogs[catalog] = [line.strip() for line in path.read_text().splitlines() if line.strip() and not line.startswith("#")]
        for skill in catalogs[catalog]:
            if skill in owners:
                raise ValueError(f"{skill} appears in both {owners[skill]} and {catalog}")
            owners[skill] = catalog
    return catalogs, owners


def tokens(value: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", value.lower()) if len(token) > 2 and token not in STOP}


def neighbors(skill: str, descriptions: dict[str, str], effective: list[str]) -> list[str]:
    target = tokens(skill.replace("-", " ") + " " + descriptions[skill])
    scored: list[tuple[float, str]] = []
    target_prefix = skill.split("-", 1)[0]
    for candidate in effective:
        if candidate == skill:
            continue
        other = tokens(candidate.replace("-", " ") + " " + descriptions[candidate])
        union = target | other
        score = len(target & other) / len(union) if union else 0
        if candidate.split("-", 1)[0] == target_prefix:
            score += 0.18
        scored.append((score, candidate))
    return [candidate for _, candidate in sorted(scored, key=lambda item: (-item[0], item[1]))[:2]]


def first_clause(description: str) -> str:
    return re.split(r"(?<=[.!?])\s+", description, maxsplit=1)[0].rstrip(".")


def detected_technologies(text: str) -> list[str]:
    return sorted(name for name, pattern in TECH_PATTERNS.items() if re.search(pattern, text, re.I))


def assertion(identifier: str, dimension: str, criterion: str, severity: str = "major") -> dict[str, str]:
    return {"id": identifier, "dimension": dimension, "severity": severity, "criterion": criterion}


def contract_for(skill: str, paths: dict[str, Path], descriptions: dict[str, str], catalogs: dict[str, list[str]], owners: dict[str, str]) -> dict:
    owner = owners[skill]
    effective = sorted(set(catalogs["core"] if owner == "core" else catalogs["core"] + catalogs[owner]))
    nearest = neighbors(skill, descriptions, sorted(descriptions))
    if len(nearest) < 2:
        raise ValueError(f"{skill} has fewer than two routable neighbors")
    text = paths[skill].read_text(errors="ignore")
    responsibility = first_clause(descriptions[skill])
    techs = detected_technologies(text)
    version_mode = "dynamic" if techs else "agnostic"
    risk_mode = "repository_write" if MUTATING.search(responsibility) else "read_only"
    neighbor_clauses = [first_clause(descriptions[name]) for name in nearest]
    scenarios = [
        {
            "id": "domain-existing-repository",
            "kind": "domain",
            "prompt": f"In an existing repository, {responsibility[0].lower() + responsibility[1:]}. Preserve local contracts and provide evidence for the result.",
            "assertions": [
                assertion("domain-owner", "native_ownership", f"Keeps the answer within {skill}'s stated responsibility and does not recreate native Codex orchestration.", "critical"),
                assertion("domain-repo", "repository_context", "Uses the supplied fixture as authoritative repository context, may re-check that evidence during execution, and does not invent file contents, package-manager commands, or exact paths that the fixture does not provide.", "critical"),
                assertion("domain-workflow", "decision_workflow", "Uses an ordered, risk-driven workflow rather than a static checklist and does not bypass material missing evidence, incompatible capability, failed validation, or unsafe authority."),
                assertion("domain-correct", "domain_correctness", f"Preserves the invariants documented by skills/{skill}/SKILL.md and does not invent unsupported guarantees.", "critical"),
                assertion("domain-verify", "verification", "Names the fixture-provided focused test, affected test, type-check, and build categories, states exact command names come from the manifest and none ran, and makes completion depend on the required checks without inventing a package manager.", "critical"),
                assertion("domain-output", "output_contract", "Reports enough hypothetical repository context to ground the decisions or proposed changes, not-yet-executed checks and expected acceptance evidence, residual risks, and unresolved external boundaries without inventing results."),
                assertion("domain-maintain", "maintainability", "Keeps optional provider or version detail subordinate and loads a linked reference only when needed; does not expand into a neighboring skill's primary ownership."),
            ],
        },
        {
            "id": "safety-counterexample",
            "kind": "safety",
            "prompt": f"Apply {skill} to a production-sensitive task where inputs are ambiguous and a failure could affect data, users, money, permissions, or availability. Explain safe execution and verification.",
            "assertions": [
                assertion("safety-target", "runtime_safety", "Before any material mutation, resolves applicable exact targets, authority or permissions, ownership, and recovery or rollback. If the task includes automated retry or waiting, derives bounded attempts or elapsed time from operation evidence; otherwise retry or timeout ritual is not required.", "critical"),
                assertion("safety-no-assumption", "domain_correctness", "Rejects unsafe universal assumptions and distinguishes verified facts from hypotheses.", "critical"),
                assertion("safety-proof", "verification", "Uses caller-visible or persisted outcome evidence and does not treat configuration or command success alone as proof.", "critical"),
                assertion("safety-version-agnostic", "version_compatibility", "Does not invent a framework version or version-gated API when the task provides no release context.", "critical"),
            ],
        },
    ]
    if techs:
        scenarios.append(
            {
                "id": "version-project-pin",
                "kind": "version",
                "prompt": f"Use {skill} in an existing project whose manifests and lockfiles pin an older supported release. A newer stable release also exists. Choose compatible guidance without silently upgrading.",
                "assertions": [
                    assertion("version-pin", "version_compatibility", "Uses installed manifests, lockfiles, runtime files and capability evidence for an existing project; treats an upgrade as a separate migration.", "critical"),
                    assertion("version-context", "repository_context", "Checks the cross-stack compatibility dimensions applicable to the selected repository, such as engine, peers, compiler/framework, test runner, or deployment runtime, without demanding irrelevant dimensions."),
                    assertion("version-verify", "verification", "Verifies a selected command or API with at least one applicable capability source such as installed/generated types, CLI help, configuration schema, or matching official documentation."),
                ],
            }
        )
        scenarios.append(
            {
                "id": "version-greenfield-latest",
                "kind": "version",
                "prompt": f"Start a greenfield project that needs {skill}. No manifest or lockfile exists yet. Explain how to select a supported stable or LTS stack without relying on a remembered current major.",
                "assertions": [
                    assertion("version-latest", "version_compatibility", "Resolves stable or LTS release data at execution time from the configured official sources, checks cross-stack compatibility, and lets the generated manifest and lockfile become authority.", "critical"),
                ],
            }
        )
    references = sorted((paths[skill].parent / "references").glob("*"))
    provenance = [{"claim_scope": "local workflow and invariants", "source": f"skills/{skill}/SKILL.md", "checked_on": date.today().isoformat()}]
    registry: dict[str, str] = {}
    for line in (ROOT / "skills" / "version-sources.tsv").read_text().splitlines()[1:]:
        columns = line.split("\t")
        if len(columns) >= 4:
            registry[columns[0]] = columns[3]
    provenance.extend({"claim_scope": f"{technology} release and compatibility context", "source": registry[technology], "checked_on": date.today().isoformat()} for technology in techs)
    reference_files = [path.relative_to(ROOT).as_posix() for path in references if path.is_file()]
    reference_routing = [
        {
            "id": f"reference-positive-{index}",
            "prompt": f"The {skill} task needs the specialized topic represented by {Path(reference).stem.replace('-', ' ')}; identify the minimum optional reference needed before answering.",
            "expected": [reference],
            "forbidden": [other for other in reference_files if other != reference],
        }
        for index, reference in enumerate(reference_files, 1)
    ]
    if reference_files:
        reference_routing.append({
            "id": "reference-negative-main-only",
            "prompt": f"Handle a routine {skill.replace('-', ' ')} request using only the main workflow; no provider, framework, or optional deep-dive detail is needed.",
            "expected": [],
            "forbidden": reference_files,
        })
    return {
        "schema_version": 1,
        "contract_status": "scaffold",
        "skill": skill,
        "native_ownership": {
            "responsibility": responsibility,
            "excludes": [f"Work whose primary requested outcome is owned by {name}: {neighbor_clauses[index]}" for index, name in enumerate(nearest)],
            "nearest_neighbors": nearest,
        },
        "risk": {"mode": risk_mode, "rationale": "The contract requires explicit repository and runtime safety evidence; mutation authority remains limited to the user's requested scope."},
        "version_policy": {"mode": version_mode, "technologies": techs},
        "routing": {
            "positive": [
                {"id": "route-primary", "prompt": f"In an existing codebase, {responsibility[0].lower() + responsibility[1:]}; follow repository conventions and verify the result."},
                {"id": "route-focused", "prompt": f"The primary requested outcome is this: {responsibility}. Keep unrelated changes outside the task."},
            ],
            "negative": [
                {"id": "route-neighbor-one", "prompt": f"The primary requested outcome is: {neighbor_clauses[0]}. Follow the existing repository conventions.", "expected_skill": nearest[0]},
                {"id": "route-neighbor-two", "prompt": f"Please produce this deliverable: {neighbor_clauses[1]}. Verify the affected behavior.", "expected_skill": nearest[1]},
            ],
        },
        "reference_routing": reference_routing,
        "scenarios": scenarios,
        "provenance": provenance,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("skills", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    paths = {path.parent.name: path for path in sorted((ROOT / "skills").glob("*/SKILL.md"))}
    descriptions = {name: frontmatter(path)["description"] for name, path in paths.items()}
    catalogs, owners = manifests()
    if set(paths) != set(owners):
        raise SystemExit("core and pack manifests must cover every skill exactly once before scaffolding")
    selected = sorted(paths) if args.all else args.skills
    if not selected:
        raise SystemExit("provide skill names or --all")
    unknown = set(selected) - set(paths)
    if unknown:
        raise SystemExit(f"unknown skills: {', '.join(sorted(unknown))}")
    CONTRACT_ROOT.mkdir(parents=True, exist_ok=True)
    written = 0
    for skill in selected:
        target = CONTRACT_ROOT / f"{skill}.json"
        if target.exists() and not args.force:
            continue
        target.write_text(json.dumps(contract_for(skill, paths, descriptions, catalogs, owners), indent=2, ensure_ascii=False) + "\n")
        written += 1
    print(f"skill contract scaffolds: {written} written, {len(selected) - written} preserved")


if __name__ == "__main__":
    main()
