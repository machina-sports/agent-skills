#!/bin/bash
set -e

# branch-guard.sh - Detect outdated branches and potential conflicts
# Usage:
#   ./branch-guard.sh check              # check if branch is behind main
#   ./branch-guard.sh conflicts          # detect potential merge conflicts
#   ./branch-guard.sh check --base dev   # use custom base branch
#   ./branch-guard.sh check --no-fetch   # skip git fetch

# ── Defaults ──────────────────────────────────────────────

BASE_BRANCH=""
DO_FETCH=true
CMD="${1:-check}"
shift 2>/dev/null || true

# ── Parse flags ───────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --base) BASE_BRANCH="$2"; shift ;;
    --no-fetch) DO_FETCH=false ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ───────────────────────────────────────────────

ensure_git_repo() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not inside a git repository."
    exit 1
  fi
}

detect_base_branch() {
  if [ -n "$BASE_BRANCH" ]; then
    return
  fi
  # Try main first, then master
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/remotes/origin/master; then
    BASE_BRANCH="master"
  else
    echo "Error: Could not detect main branch. Use --base <branch>."
    exit 1
  fi
}

fetch_remote() {
  if [ "$DO_FETCH" = true ]; then
    echo "Fetching latest from origin..."
    git fetch origin --quiet
    echo ""
  fi
}

# ── Command: check ────────────────────────────────────────

cmd_check() {
  ensure_git_repo
  detect_base_branch
  fetch_remote

  CURRENT=$(git branch --show-current)

  if [ "$CURRENT" = "$BASE_BRANCH" ]; then
    BEHIND=$(git rev-list --count HEAD..origin/"$BASE_BRANCH")
    if [ "$BEHIND" -eq 0 ]; then
      echo "You are on $BASE_BRANCH and up to date with origin."
    else
      echo "You are on $BASE_BRANCH but $BEHIND commit(s) behind origin."
      echo ""
      echo "Run:"
      echo "  git pull origin $BASE_BRANCH"
    fi
    return
  fi

  BEHIND=$(git rev-list --count HEAD..origin/"$BASE_BRANCH")
  AHEAD=$(git rev-list --count origin/"$BASE_BRANCH"..HEAD)

  echo "Branch:  $CURRENT"
  echo "Base:    $BASE_BRANCH (origin)"
  echo "Behind:  $BEHIND commit(s)"
  echo "Ahead:   $AHEAD commit(s)"
  echo ""

  if [ "$BEHIND" -eq 0 ] && [ "$AHEAD" -eq 0 ]; then
    echo "Status: Up to date. Nothing to do."

  elif [ "$BEHIND" -eq 0 ]; then
    echo "Status: You have local work not yet in $BASE_BRANCH. All good."

  elif [ "$AHEAD" -eq 0 ]; then
    echo "Status: Your branch is behind. You should pull."
    echo ""
    echo "Run:"
    echo "  git pull origin $BASE_BRANCH"

  else
    echo "Status: Diverged. Your branch is both behind and ahead."
    echo ""
    echo "Options:"
    echo "  # Rebase (clean history):"
    echo "  git pull --rebase origin $BASE_BRANCH"
    echo ""
    echo "  # Merge (preserve history):"
    echo "  git pull origin $BASE_BRANCH"
  fi
}

# ── Command: conflicts ────────────────────────────────────

cmd_conflicts() {
  ensure_git_repo
  detect_base_branch
  fetch_remote

  CURRENT=$(git branch --show-current)
  MERGE_BASE=$(git merge-base HEAD origin/"$BASE_BRANCH")

  # Files changed in your branch since diverging from base
  YOUR_FILES=$(git diff --name-only "$MERGE_BASE"..HEAD)

  # Files changed in base since you diverged
  BASE_FILES=$(git diff --name-only "$MERGE_BASE"..origin/"$BASE_BRANCH")

  if [ -z "$BASE_FILES" ]; then
    echo "No changes in $BASE_BRANCH since you branched off. No conflict risk."
    return
  fi

  if [ -z "$YOUR_FILES" ]; then
    echo "No local changes. No conflict risk."
    return
  fi

  # Find common files (potential conflicts)
  CONFLICTS=$(comm -12 <(echo "$YOUR_FILES" | sort) <(echo "$BASE_FILES" | sort))

  echo "Branch:  $CURRENT"
  echo "Base:    $BASE_BRANCH (origin)"
  echo "---"

  if [ -z "$CONFLICTS" ]; then
    echo "No potential conflicts detected."
    echo "Files changed in both branches don't overlap."
  else
    COUNT=$(echo "$CONFLICTS" | wc -l | tr -d ' ')
    echo "Warning: $COUNT file(s) modified in both branches:"
    echo ""
    echo "$CONFLICTS" | while read -r file; do
      echo "  - $file"
    done
    echo ""
    echo "These files may cause merge conflicts."
    echo "Review them before merging/rebasing."
  fi
}

# ── Dispatch ──────────────────────────────────────────────

case "$CMD" in
  check)     cmd_check ;;
  conflicts) cmd_conflicts ;;
  *)
    echo "Usage: $0 {check|conflicts} [--base <branch>] [--no-fetch]"
    exit 1
    ;;
esac
