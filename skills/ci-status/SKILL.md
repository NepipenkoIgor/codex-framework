---
name: ci-status
description: Check GitHub Actions CI status for current branch — surfaces failures back to Claude
metadata:
  version: 1.0
  domain: devops
  agents: [project-manager]
---

# CI Status Skill

Spawns pm~h to check GitHub Actions status for the current branch and surface failures.

## Steps

1. Run: `gh run list --branch $(git branch --show-current) --limit 3 --json status,conclusion,name,databaseId,url,createdAt`
2. If latest run is `in_progress`:
   - Report: `CI: ⏳ <workflow> in progress — watching...`
   - Run `gh run watch <id>` with a 5-minute timeout
3. If latest run `conclusion` is `failure`:
   - Run `gh run view <id> --log-failed` to get failed step output
   - Surface in structured format:
     ```
     CI FAILED: <workflow name>
     Step: <failed step name>
     Error: <first 20 lines of log>
     URL: <run url>
     ```
   - Suggest: "Spawn fix~s with this error as context"
4. If `conclusion` is `success`: report `CI: ✓ <workflow> passed (<time ago>)`
5. If no runs found: report `CI: no runs found for branch <branch-name>`

## Usage

Type `/ci-status` after pushing a branch or creating a PR to check build health without leaving Claude Code.
