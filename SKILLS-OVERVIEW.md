# New Agent Skills — Overview

Five new skills to improve code quality, security, and developer experience across our repositories.

---

## 1. env-sync — Secret Sync Checker

**Problem:** Secrets are added to `.env.example` but someone forgets to configure them in GitHub. The deploy breaks.

**Solution:** Compares `.env.example` keys against the actual GitHub repo secrets and shows what's missing, what's extra, and what's in sync.

```bash
bash env-sync/scripts/env-sync.sh check --file .env.example
```

```
Repo:    machina-sports/agent-skills
Source:  .env.example
---

In sync (1):
  [ok] MACHINA_API_URL

Missing from GitHub (1):
  [!!] MACHINA_API_KEY

Fix with:
  bash scripts/setup-secrets.sh .env
```

**Highlights:**
- Auto-detects the GitHub repo
- Works with any `.env` file (`--file .env.production`)
- Suggests the exact fix command
- Flags extra secrets in GitHub that aren't in the env file (possibly obsolete)

---

## 2. branch-guard — Branch Sync & Conflict Detector

**Problem:** You work on a feature branch for days, open a PR, and discover you're 15 commits behind main with merge conflicts everywhere.

**Solution:** Checks if your branch is behind the main branch, shows how far you've diverged, and detects which files are likely to conflict before you merge.

```bash
# Check if your branch is up to date
bash branch-guard/scripts/branch-guard.sh check

# Detect potential merge conflicts
bash branch-guard/scripts/branch-guard.sh conflicts
```

```
Branch:  feat/my-feature
Base:    main (origin)
Behind:  5 commit(s)
Ahead:   3 commit(s)

Status: Diverged. Your branch is both behind and ahead.

Options:
  # Rebase (clean history):
  git pull --rebase origin main

  # Merge (preserve history):
  git pull origin main
```

```
Warning: 2 file(s) modified in both branches:

  - src/api/routes.ts
  - src/utils/helpers.ts

These files may cause merge conflicts.
Review them before merging/rebasing.
```

**Highlights:**
- Auto-detects `main` or `master` as base branch
- Shows behind/ahead count with specific suggested commands
- Crosses file lists from both branches to find conflict-prone files
- `--no-fetch` for offline mode, `--base <branch>` for custom base
- Works in any git repository

---

## 3. agent-doctor — Agent Template Validator

**Problem:** A typo in a YAML file or a missing workflow reference breaks the agent at runtime — and the error message is not helpful.

**Solution:** Validates Machina agent templates before deploying. Checks YAML syntax, required fields, file references, and directory structure.

```bash
bash agent-doctor/scripts/agent-doctor.sh validate agent-templates/my-agent
```

```
Diagnosing: my-agent
Path: agent-templates/my-agent
---
  [OK]    _install.yml found
  [OK]    _install.yml has 'setup' section
  [OK]    _install.yml has 'datasets' section
  [OK]    Referenced file exists: agents/main.yml
  [OK]    Referenced file exists: workflows/main.yml
  [OK]    agents/ directory exists
  [OK]    workflows/ directory exists
  [OK]    main.yml has 'agent' root key
  [OK]    main.yml references workflows
  [OK]    main.yml has 'workflow' root key
  [OK]    main.yml has 'tasks' section
  [OK]    main.yml uses connector: machina-ai

Result: Healthy! No issues found.
```

**Highlights:**
- Validates `_install.yml`, agents, workflows, and connectors
- Checks that all referenced files actually exist
- Detects tabs in YAML (common mistake)
- Detects unbalanced quotes
- `validate-all` scans every agent in the templates directory at once

---

## 4. pr-summary — Pull Request Summarizer

**Problem:** PRs with 10+ files are hard to review. Reviewers waste time figuring out *what changed* before they can evaluate *how it changed*.

**Solution:** Generates a quick summary of any PR or branch — files changed, lines added/removed, impact areas, and commit history.

```bash
# Summarize current branch vs main
bash pr-summary/scripts/pr-summary.sh

# Summarize a specific PR
bash pr-summary/scripts/pr-summary.sh --pr 42
```

```
Branch:   feat/code-quality
Base:     main
Commits:  3
---
Files changed:  5
Additions:      +310
Deletions:      -0

Files:
  [added] .env.example
  [added] .gitignore
  [added] branch-guard/scripts/branch-guard.sh
  [added] scripts/setup-secrets.sh

Impact areas:
  branch-guard/scripts (1 file(s))
  scripts (1 file(s))
  (root) (2 file(s))

Commits:
  - feat: add branch-guard skill
  - feat: add setup-secrets script
```

**Highlights:**
- Works locally (branch diff) or remotely (`--pr 42`)
- Groups files by impact area so reviewers see which parts of the codebase are affected
- Shows change type per file (added, modified, deleted, renamed)
- Works with any base branch (`--base develop`)

---

## 5. pr-deps — PR Dependency Detector

**Problem:** Dev A opens a PR that creates a new API endpoint. Dev B opens another PR that uses that endpoint. Nobody realizes PR #11 depends on PR #10 until the merge breaks everything.

**Solution:** Analyzes open PRs and detects dependencies using three strategies: explicit references in descriptions/commits, branch ancestry, and file overlap analysis.

```bash
# Scan current branch's PR for dependencies
bash pr-deps/scripts/pr-deps.sh scan

# Scan a specific PR
bash pr-deps/scripts/pr-deps.sh scan --pr 12

# Map all open PR dependencies
bash pr-deps/scripts/pr-deps.sh map
```

```
Scanning PR #12: feat: add code quality skills
Branch:  feat/code-quality
Repo:    machina-sports/agent-skills
---

Branch dependencies (your branch is based on these):
  [BLOCKED] PR #11 (feat: add setup-secrets) — branch 'feat/agent-skills-gh-secrets' not merged yet
  [BLOCKED] PR #13 (feat: add branch-guard) — branch 'feat/branch-guard' not merged yet

File overlaps (other PRs touching the same files):
  [OVERLAP] PR #13 (feat: add branch-guard) — 2 shared file(s):
            - branch-guard/SKILL.md
            - branch-guard/scripts/branch-guard.sh
  [OVERLAP] PR #11 (feat: add setup-secrets) — 3 shared file(s):
            - .env.example
            - .gitignore
            - scripts/setup-secrets.sh

---
Review the dependencies above before merging.
```

**Highlights:**
- Three detection layers: references (`depends on #X`), branch ancestry, and file overlaps
- `scan` for a single PR, `map` for all open PRs at once
- Shows status of each dependency (OPEN, MERGED, CLOSED)
- Suggests adding `depends on #X` to PR descriptions for explicit tracking
- Works with any GitHub repository

---

## Quick Reference

| Skill | Command | What it does |
|-------|---------|-------------|
| env-sync | `env-sync.sh check` | Compares .env vs GitHub secrets |
| branch-guard | `branch-guard.sh check` | Checks if branch is behind main |
| branch-guard | `branch-guard.sh conflicts` | Detects potential merge conflicts |
| agent-doctor | `agent-doctor.sh validate <path>` | Validates agent template |
| agent-doctor | `agent-doctor.sh validate-all` | Validates all templates |
| pr-summary | `pr-summary.sh` | Summarizes current branch diff |
| pr-summary | `pr-summary.sh --pr 42` | Summarizes a specific PR |
| pr-deps | `pr-deps.sh scan` | Scans current PR for dependencies |
| pr-deps | `pr-deps.sh map` | Maps all open PR dependencies |

All skills require only `git` and `gh` (GitHub CLI) — no extra dependencies.
