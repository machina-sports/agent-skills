---
name: pr-summary
description: Generate a concise summary of a Pull Request — files changed, impact areas, and stats.
license: MIT
metadata:
  triggers: ["pr", "pull-request", "review", "summary", "diff"]
  setup:
    env: []
---

# PR Summary

Get a quick overview of any Pull Request without reading every line. Shows files changed, lines added/removed, impact areas, and commit history.

## Usage

### Summarize current branch's PR
```bash
./scripts/pr-summary.sh
```

### Summarize a specific PR
```bash
./scripts/pr-summary.sh --pr 42
```

### Options
```bash
# Custom repo
./scripts/pr-summary.sh --pr 42 --repo owner/repo

# Compare against a different base
./scripts/pr-summary.sh --base develop
```

## Examples
> "Summarize this PR for me."
> "What changed in PR #42?"
