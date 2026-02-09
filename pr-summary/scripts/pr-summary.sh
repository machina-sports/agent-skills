#!/bin/bash
set -e

# pr-summary.sh - Generate a concise summary of a Pull Request
# Usage:
#   ./pr-summary.sh                  # summarize current branch's diff
#   ./pr-summary.sh --pr 42          # summarize PR #42
#   ./pr-summary.sh --base develop   # compare against develop

# ── Defaults ──────────────────────────────────────────────

PR_NUMBER=""
REPO=""
BASE_BRANCH=""

# ── Parse flags ───────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --pr) PR_NUMBER="$2"; shift ;;
    --repo|-r) REPO="$2"; shift ;;
    --base) BASE_BRANCH="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ───────────────────────────────────────────────

check_prerequisites() {
  if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    exit 1
  fi
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not inside a git repository."
    exit 1
  fi
}

detect_repo() {
  if [ -n "$REPO" ]; then return; fi
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
  if [ -z "$REPO" ]; then
    echo "Error: Could not detect repo. Use --repo owner/repo."
    exit 1
  fi
}

detect_base() {
  if [ -n "$BASE_BRANCH" ]; then return; fi
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/remotes/origin/master; then
    BASE_BRANCH="master"
  else
    BASE_BRANCH="main"
  fi
}

# ── Summarize from PR number ─────────────────────────────

summarize_pr() {
  detect_repo

  echo "Fetching PR #$PR_NUMBER from $REPO..."
  echo ""

  # Get PR metadata
  PR_DATA=$(gh pr view "$PR_NUMBER" -R "$REPO" --json title,author,state,baseRefName,headRefName,additions,deletions,changedFiles,commits,createdAt,body)

  TITLE=$(echo "$PR_DATA" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
  AUTHOR=$(echo "$PR_DATA" | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)
  STATE=$(echo "$PR_DATA" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
  BASE=$(echo "$PR_DATA" | grep -o '"baseRefName":"[^"]*"' | cut -d'"' -f4)
  HEAD=$(echo "$PR_DATA" | grep -o '"headRefName":"[^"]*"' | cut -d'"' -f4)
  ADDITIONS=$(echo "$PR_DATA" | grep -o '"additions":[0-9]*' | cut -d: -f2)
  DELETIONS=$(echo "$PR_DATA" | grep -o '"deletions":[0-9]*' | cut -d: -f2)
  CHANGED=$(echo "$PR_DATA" | grep -o '"changedFiles":[0-9]*' | cut -d: -f2)

  echo "PR #$PR_NUMBER: $TITLE"
  echo "Author:  $AUTHOR"
  echo "State:   $STATE"
  echo "Branch:  $HEAD -> $BASE"
  echo "---"
  echo "Files changed:  $CHANGED"
  echo "Additions:      +$ADDITIONS"
  echo "Deletions:      -$DELETIONS"
  echo ""

  # Get file list
  echo "Files:"
  gh pr diff "$PR_NUMBER" -R "$REPO" --name-only | while read -r file; do
    echo "  $file"
  done

  # Group by directory
  echo ""
  echo "Impact areas:"
  gh pr diff "$PR_NUMBER" -R "$REPO" --name-only | while read -r file; do
    dirname "$file"
  done | sort -u | while read -r dir; do
    COUNT=$(gh pr diff "$PR_NUMBER" -R "$REPO" --name-only | grep "^$dir/" | wc -l | tr -d ' ')
    [ "$dir" = "." ] && dir="(root)"
    echo "  $dir ($COUNT file(s))"
  done

  # Commits
  echo ""
  echo "Commits:"
  gh pr view "$PR_NUMBER" -R "$REPO" --json commits --jq '.commits[].messageHeadline' | while read -r msg; do
    echo "  - $msg"
  done
}

# ── Summarize from local branch diff ─────────────────────

summarize_local() {
  detect_base
  git fetch origin --quiet

  CURRENT=$(git branch --show-current)
  MERGE_BASE=$(git merge-base HEAD origin/"$BASE_BRANCH")

  COMMITS=$(git rev-list --count "$MERGE_BASE"..HEAD)
  FILES=$(git diff --name-only "$MERGE_BASE"..HEAD)
  FILE_COUNT=$(echo "$FILES" | grep -c . || echo "0")

  STAT=$(git diff --shortstat "$MERGE_BASE"..HEAD)
  ADDITIONS=$(echo "$STAT" | grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo "0")
  DELETIONS=$(echo "$STAT" | grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo "0")

  echo "Branch:   $CURRENT"
  echo "Base:     $BASE_BRANCH"
  echo "Commits:  $COMMITS"
  echo "---"
  echo "Files changed:  $FILE_COUNT"
  echo "Additions:      +${ADDITIONS:-0}"
  echo "Deletions:      -${DELETIONS:-0}"

  if [ -z "$FILES" ]; then
    echo ""
    echo "No changes to summarize."
    return
  fi

  # File list with change type
  echo ""
  echo "Files:"
  git diff --name-status "$MERGE_BASE"..HEAD | while read -r status file; do
    case "$status" in
      A) label="added" ;;
      M) label="modified" ;;
      D) label="deleted" ;;
      R*) label="renamed" ;;
      *) label="$status" ;;
    esac
    echo "  [$label] $file"
  done

  # Impact areas
  echo ""
  echo "Impact areas:"
  echo "$FILES" | while read -r file; do
    dirname "$file"
  done | sort | uniq -c | sort -rn | while read -r count dir; do
    [ "$dir" = "." ] && dir="(root)"
    echo "  $dir ($count file(s))"
  done

  # Commit log
  echo ""
  echo "Commits:"
  git log --oneline "$MERGE_BASE"..HEAD | while read -r line; do
    echo "  - $line"
  done
}

# ── Main ──────────────────────────────────────────────────

check_prerequisites

if [ -n "$PR_NUMBER" ]; then
  summarize_pr
else
  summarize_local
fi
