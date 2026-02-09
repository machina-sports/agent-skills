---
name: pr-deps
description: Detect dependencies between Pull Requests — find PRs that block yours by analyzing branches, file overlaps, and commit references.
license: MIT
metadata:
  triggers: ["pr", "dependency", "depends", "blocked", "blocking", "merge-order"]
  setup:
    env: []
---

# PR Deps

Discover hidden dependencies between Pull Requests before they cause merge failures. Analyzes branch origin, file overlaps, and commit references to map what blocks what.

## Usage

### Scan current branch for dependencies
```bash
./scripts/pr-deps.sh scan
```

### Scan a specific PR
```bash
./scripts/pr-deps.sh scan --pr 11
```

### Map all open PR dependencies
```bash
./scripts/pr-deps.sh map
```

### Options
```bash
# Custom repo
./scripts/pr-deps.sh scan --repo owner/repo
```

## Examples
> "Does my PR depend on any other open PRs?"
> "Show me the dependency map of all open PRs."
> "Is PR #11 blocked by anything?"
