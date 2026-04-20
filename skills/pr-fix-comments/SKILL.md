---
name: pr-fix-comments
description: Fetch unresolved PR review comments, analyze and fix actionable ones, commit, push, and resolve threads
metadata:
  version: 1.4
  argument-hint: "PR number or URL, repo owner/name, comment filter (unresolved/all)"
---

Fix all unresolved PR review comments for $ARGUMENTS — analyze each comment, apply fixes, push, and resolve threads.

## Tool Preference

- Prefer the framework capability path from the task brief
- If structured GitHub tools are available, use them to read PR comments, review threads, and structured PR data
- Otherwise use `gh` CLI for both reading and resolving thread state
- If neither exists, stop and tell the user remote PR comment operations are not available

## Step 1: Resolve gh CLI Path

The `gh` CLI may not be in the default PATH. Try these locations in order:

1. `gh` (default PATH)
2. `/opt/homebrew/bin/gh` (Homebrew on Apple Silicon)
3. `/usr/local/bin/gh` (Homebrew on Intel Mac / Linux)

Test with `$GH_PATH --version`. If none work, stop and tell the user to install gh: `brew install gh`

```bash
GH=""
for candidate in gh /opt/homebrew/bin/gh /usr/local/bin/gh; do
  if command -v "$candidate" &>/dev/null || [ -x "$candidate" ]; then
    GH="$candidate"
    break
  fi
done
```

Verify authentication: `$GH auth status`. If not authenticated, instruct the user to run `$GH auth login`.

## Step 2: Parse Arguments

Parse `$ARGUMENTS` to extract:

| Input | Behavior |
|---|---|
| (empty) | Auto-detect PR for current branch: `$GH pr view --json number,url` |
| `123` or `#123` | PR number in current repo |
| `https://github.com/owner/repo/pull/123` | Full URL — extract owner, repo, number |
| `owner/repo#123` | Cross-repo PR |
| `--dry-run` flag (anywhere) | Analyze and show plan, but do NOT fix, commit, push, or resolve |

If no PR is found for the current branch, tell the user to specify a PR number.

## Step 3: Fetch PR Context

Gather all data needed for fixing:

```bash
# PR metadata
$GH pr view <number> --json title,headRefName,baseRefName,url,author

# Full diff (to understand what was changed)
$GH pr diff <number>

# Changed files list
$GH pr diff <number> --name-only

# All review comments (including resolved — to avoid re-fixing)
$GH api repos/{owner}/{repo}/pulls/{number}/comments --paginate

# PR review threads with resolution status
$GH api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 10) {
            nodes {
              id
              body
              path
              line
              author { login }
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner="{owner}" -f repo="{repo}" -F number={number}
```

## Step 4: Filter and Classify Comments

From the fetched review threads, extract only **unresolved** threads (`isResolved: false`).

For each unresolved thread, classify the first comment (the review comment) into:

| Category | Action | Examples |
|---|---|---|
| **suggestion** | Auto-fix | "Use X instead of Y", "Rename to...", GitHub suggestion blocks |
| **bug** | Auto-fix | "This will crash when...", "Missing null check", "Off-by-one" |
| **style** | Auto-fix | "Naming convention", "Missing type", "Format issue" |
| **nit** | Auto-fix | "Typo", "Extra whitespace", "Import order" |
| **question** | Skip — reply only | "Why did you...?", "What happens if...?" |
| **architecture** | Skip — flag | "Should we redesign...", "Consider splitting this service" |
| **unclear** | Skip — flag | Can't determine intent or action |

### GitHub Suggestion Blocks

If a comment contains a GitHub suggestion block:
````
```suggestion
<replacement code>
```
````

Extract the exact replacement code. This is the highest-confidence fix — apply it verbatim to the specified file and line range.

## Step 5: Present Analysis

Show the user a structured analysis before proceeding:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR Comment Analysis: owner/repo#123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Will fix (N comments):
  1. [suggestion] src/api/users.ts:42 — @reviewer: "Use parameterized query"
  2. [bug] src/utils/parse.ts:15 — @reviewer: "Missing null check on input"
  3. [nit] src/index.ts:3 — @reviewer: "Typo in variable name"

Will skip (M comments):
  4. [question] src/api/auth.ts:20 — @reviewer: "Why not use middleware here?"
  5. [architecture] src/services/ — @reviewer: "Consider splitting this"

Dry run: no changes will be made.
— OR —
Proceed with fixes? (y/n)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `--dry-run` was specified, stop here.

Otherwise, **ask the user for confirmation** before proceeding. The user may choose to:
- Fix all
- Fix specific items by number
- Skip entirely

## Step 6: Apply Fixes

For each fixable comment, in file order (to avoid line-number drift):

1. **Read the target file** using normal Codex file reads
2. **Understand the context** — read surrounding code, imports, types
3. **Apply the fix:**
   - For GitHub suggestion blocks → apply the exact replacement
   - For other comments → understand the intent and make the minimal correct change
4. Make changes using the repo's normal Codex edit flow

### Fix ordering rules

- Group fixes by file
- Within a file, apply fixes from **bottom to top** (highest line number first) to prevent line-number shifting
- If two comments refer to the same line/region, combine them into one fix
- If a fix requires changes in multiple files (e.g., renaming an export), apply all related changes

### Safety rules

- **Never delete functionality** unless the comment explicitly asks for removal
- **Never change logic** beyond what the comment requests
- **Never fix resolved threads** — only unresolved ones
- If a fix seems risky or ambiguous, skip it and flag it for the user
- If a fix would conflict with another fix, flag both and let the user decide

## Step 7: Commit and Push

After all fixes are applied:

1. **Stage only the fixed files** — use `git add <file1> <file2> ...` (never `git add .`)
2. **Create a single commit** with a descriptive message:

```bash
git commit -m "$(cat <<'EOF'
fix(pr-review): address review comments

- Use parameterized query in users.ts
- Add null check in parse.ts
- Fix typo in index.ts

Resolves N review comments from PR #123
EOF
)"
```

3. **Push to the PR branch:**

```bash
git push
```

If push fails (e.g., behind remote), pull with rebase first:
```bash
git pull --rebase && git push
```

## Step 8: Resolve Threads

After pushing, resolve each fixed comment thread via the GitHub GraphQL API:

```bash
$GH api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { isResolved }
  }
}' -f threadId="{thread_id}"
```

Do this for each thread that was successfully fixed.

**Do NOT resolve:**
- Threads where the fix was skipped
- Question threads (reply to them instead — see Step 9)
- Architecture/unclear threads

## Step 9: Reply to Non-Fixable Comments

For **question** comments, post a brief reply explaining the reasoning:

```bash
$GH api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies \
  -f body="<concise answer based on code context>"
```

Read the surrounding code to provide accurate answers. If you can't determine the answer from the code, reply with:
> "This needs manual review — the intent isn't clear from the code context alone."

For **architecture** and **unclear** comments, do NOT reply — just list them in the final report.

## Step 10: Final Report

After all actions are complete, show:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR Comments Fixed: owner/repo#123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fixed and resolved (N):
  ✅ src/api/users.ts:42 — parameterized query
  ✅ src/utils/parse.ts:15 — null check added
  ✅ src/index.ts:3 — typo fixed

Replied (M):
  💬 src/api/auth.ts:20 — answered question about middleware

Needs manual review (K):
  ⚠️ src/services/ — architecture discussion (thread not resolved)

Commit: abc1234 — "fix(pr-review): address review comments"
Pushed to: feature/my-branch
PR: https://github.com/owner/repo/pull/123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Error Handling

- If `gh` is not found → tell user to install: `brew install gh`
- If not authenticated → tell user to run: `gh auth login`
- If PR not found → "PR #N not found. Check the number or specify the full URL."
- If no unresolved comments → "No unresolved review comments on PR #N. Nothing to fix."
- If GraphQL API fails on thread resolution → warn but don't fail; list unresolved threads in report
- If push fails after rebase → stop and ask user to resolve manually
- If a fix introduces a syntax error → revert that file's changes and flag it

## Cross-Repo Support

When the PR is in a different repo than the current working directory:
- Use `--repo owner/repo` for all `gh pr` commands
- Use full `repos/owner/repo/pulls/...` paths for API calls
- Clone or fetch the repo if needed for local file reads
- Warn the user that fixes will be applied to the local checkout
