---
name: branch-guard
description: Detect when your branch is outdated, behind the main branch, and spot potential merge conflicts before they happen.
license: MIT
metadata:
  triggers: ["branch", "git", "sync", "outdated", "behind", "pull"]
  setup:
    env: []
---

# Branch Guard

Keep your branch in sync. This skill checks if your current branch is behind the main branch and warns you about potential merge conflicts.

## Usage

### Check branch status
```bash
./scripts/branch-guard.sh check
```
Fetches the latest remote state and tells you if you're behind, ahead, or diverged.

### Detect potential conflicts
```bash
./scripts/branch-guard.sh conflicts
```
Lists files modified in both your branch and main — these are likely to conflict on merge.

### Options
```bash
# Specify a different base branch
./scripts/branch-guard.sh check --base develop

# Skip git fetch (offline mode)
./scripts/branch-guard.sh check --no-fetch
```

## Examples
> "Is my branch up to date?"
> "Check if I need to pull from main."
> "Are there potential conflicts with main?"
