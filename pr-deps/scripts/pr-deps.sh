#!/bin/bash
set -e

# pr-deps.sh - Detect dependencies between Pull Requests
# Usage:
#   ./pr-deps.sh scan              # scan current branch for dependencies
#   ./pr-deps.sh scan --pr 11      # scan a specific PR
#   ./pr-deps.sh map               # map all open PR dependencies

# ── Defaults ──────────────────────────────────────────────

REPO=""
PR_NUMBER=""
CMD="${1:-scan}"
shift 2>/dev/null || true

# ── Parse flags ───────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --pr) PR_NUMBER="$2"; shift ;;
    --repo|-r) REPO="$2"; shift ;;
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
  if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated. Run 'gh auth login' first."
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

# ── Dependency detection helpers ──────────────────────────

# 1. Convention: scan text for "depends on #X", "blocked by #X", etc.
find_reference_deps() {
  local text="$1"
  echo "$text" | grep -ioE '(depends on|blocked by|blocks|requires|needs|after) #[0-9]+' | \
    grep -oE '#[0-9]+' | tr -d '#' | sort -un
}

# 2. Branch: check if PR branch was based on another feature branch
find_branch_deps() {
  local head_branch="$1"
  local open_prs_json="$2"

  # Get the list of open PR head branches (excluding current)
  echo "$open_prs_json" | while IFS='|' read -r pr_num pr_branch pr_base; do
    [ -z "$pr_num" ] && continue
    # Check if our branch contains the other PR's branch in its reflog/merge-base
    # Or if our branch name suggests it was derived from another feature branch
    if git merge-base --is-ancestor "origin/$pr_branch" "origin/$head_branch" 2>/dev/null; then
      echo "$pr_num"
    fi
  done | sort -un
}

# 3. Files: find PRs that touch the same files
find_file_deps() {
  local pr_files="$1"
  local open_prs_json="$2"

  [ -z "$pr_files" ] && return

  echo "$open_prs_json" | while IFS='|' read -r pr_num pr_branch pr_base; do
    [ -z "$pr_num" ] && continue

    # Get files from other PR
    OTHER_FILES=$(gh pr diff "$pr_num" -R "$REPO" --name-only 2>/dev/null || true)
    [ -z "$OTHER_FILES" ] && continue

    # Find overlapping files
    OVERLAP=$(comm -12 <(echo "$pr_files" | sort) <(echo "$OTHER_FILES" | sort))
    if [ -n "$OVERLAP" ]; then
      OVERLAP_COUNT=$(echo "$OVERLAP" | wc -l | tr -d ' ')
      # Join files with comma to keep on single line
      OVERLAP_FLAT=$(echo "$OVERLAP" | tr '\n' ',' | sed 's/,$//')
      echo "$pr_num|$OVERLAP_COUNT|$OVERLAP_FLAT"
    fi
  done
}

# ── Command: scan ─────────────────────────────────────────

cmd_scan() {
  check_prerequisites
  detect_repo

  local target_pr=""
  local head_branch=""
  local pr_title=""
  local pr_body=""

  if [ -n "$PR_NUMBER" ]; then
    target_pr="$PR_NUMBER"

    # Get PR info
    PR_JSON=$(gh pr view "$target_pr" -R "$REPO" --json title,headRefName,body 2>/dev/null || true)
    if [ -z "$PR_JSON" ]; then
      echo "Error: PR #$target_pr not found."
      exit 1
    fi
    head_branch=$(echo "$PR_JSON" | gh pr view "$target_pr" -R "$REPO" --json headRefName -q '.headRefName')
    pr_title=$(gh pr view "$target_pr" -R "$REPO" --json title -q '.title')
    pr_body=$(gh pr view "$target_pr" -R "$REPO" --json body -q '.body')
  else
    # Use current branch
    head_branch=$(git branch --show-current)

    # Find PR for current branch
    target_pr=$(gh pr list -R "$REPO" --head "$head_branch" --json number -q '.[0].number' 2>/dev/null || true)
    if [ -z "$target_pr" ]; then
      echo "No open PR found for branch '$head_branch'."
      echo "Use --pr <number> to scan a specific PR."
      exit 0
    fi
    pr_title=$(gh pr view "$target_pr" -R "$REPO" --json title -q '.title')
    pr_body=$(gh pr view "$target_pr" -R "$REPO" --json body -q '.body')
  fi

  echo "Scanning PR #$target_pr: $pr_title"
  echo "Branch:  $head_branch"
  echo "Repo:    $REPO"
  echo "---"

  # Fetch latest
  git fetch origin --quiet 2>/dev/null || true

  # Get all OTHER open PRs
  OPEN_PRS=$(gh pr list -R "$REPO" --state open --json number,headRefName,baseRefName \
    -q '.[] | select(.number != '"$target_pr"') | "\(.number)|\(.headRefName)|\(.baseRefName)"' 2>/dev/null || true)

  if [ -z "$OPEN_PRS" ]; then
    echo ""
    echo "No other open PRs found. No dependencies possible."
    exit 0
  fi

  DEPS_FOUND=false

  # 1. Convention-based: scan title, body, and commits for references
  COMMIT_MSGS=$(gh pr view "$target_pr" -R "$REPO" --json commits -q '.commits[].messageHeadline' 2>/dev/null || true)
  ALL_TEXT="$pr_title $pr_body $COMMIT_MSGS"
  REF_DEPS=$(find_reference_deps "$ALL_TEXT")

  if [ -n "$REF_DEPS" ]; then
    echo ""
    echo "References found (mentioned in PR description or commits):"
    for dep_num in $REF_DEPS; do
      DEP_STATE=$(gh pr view "$dep_num" -R "$REPO" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
      DEP_TITLE=$(gh pr view "$dep_num" -R "$REPO" --json title -q '.title' 2>/dev/null || echo "")
      if [ "$DEP_STATE" = "OPEN" ]; then
        echo "  [BLOCKED] PR #$dep_num ($DEP_TITLE) — still OPEN"
      elif [ "$DEP_STATE" = "MERGED" ]; then
        echo "  [OK]      PR #$dep_num ($DEP_TITLE) — already merged"
      else
        echo "  [??]      PR #$dep_num ($DEP_TITLE) — $DEP_STATE"
      fi
    done
    DEPS_FOUND=true
  fi

  # 2. Branch-based: check if branch contains other feature branches
  BRANCH_DEPS=$(find_branch_deps "$head_branch" "$OPEN_PRS")

  if [ -n "$BRANCH_DEPS" ]; then
    echo ""
    echo "Branch dependencies (your branch is based on these):"
    for dep_num in $BRANCH_DEPS; do
      DEP_TITLE=$(gh pr view "$dep_num" -R "$REPO" --json title -q '.title' 2>/dev/null || echo "")
      DEP_BRANCH=$(gh pr view "$dep_num" -R "$REPO" --json headRefName -q '.headRefName' 2>/dev/null || echo "")
      echo "  [BLOCKED] PR #$dep_num ($DEP_TITLE) — branch '$DEP_BRANCH' not merged yet"
    done
    DEPS_FOUND=true
  fi

  # 3. File-based: find PRs touching the same files
  MY_FILES=$(gh pr diff "$target_pr" -R "$REPO" --name-only 2>/dev/null || true)
  FILE_DEPS=$(find_file_deps "$MY_FILES" "$OPEN_PRS")

  if [ -n "$FILE_DEPS" ]; then
    echo ""
    echo "File overlaps (other PRs touching the same files):"
    echo "$FILE_DEPS" | while IFS='|' read -r dep_num overlap_count overlap_files; do
      [ -z "$dep_num" ] && continue
      DEP_TITLE=$(gh pr view "$dep_num" -R "$REPO" --json title -q '.title' 2>/dev/null || echo "")
      echo "  [OVERLAP] PR #$dep_num ($DEP_TITLE) — $overlap_count shared file(s):"
      echo "$overlap_files" | tr ',' '\n' | while read -r f; do
        [ -n "$f" ] && echo "            - $f"
      done
    done
    DEPS_FOUND=true
  fi

  # Summary
  echo ""
  echo "---"
  if [ "$DEPS_FOUND" = false ]; then
    echo "No dependencies detected. This PR is independent."
  else
    echo "Review the dependencies above before merging."
    echo ""
    echo "Tip: add 'depends on #X' to your PR description to make dependencies explicit."
  fi
}

# ── Command: map ──────────────────────────────────────────

cmd_map() {
  check_prerequisites
  detect_repo

  echo "Mapping dependencies for all open PRs in $REPO..."
  echo ""

  # Fetch latest
  git fetch origin --quiet 2>/dev/null || true

  # Get all open PRs
  ALL_PRS=$(gh pr list -R "$REPO" --state open --json number,title,headRefName,baseRefName,body \
    -q '.[] | "\(.number)|\(.title)|\(.headRefName)|\(.baseRefName)"' 2>/dev/null || true)

  if [ -z "$ALL_PRS" ]; then
    echo "No open PRs found."
    exit 0
  fi

  PR_COUNT=$(echo "$ALL_PRS" | wc -l | tr -d ' ')
  echo "Found $PR_COUNT open PR(s)."
  echo ""

  HAS_DEPS=false

  echo "$ALL_PRS" | while IFS='|' read -r pr_num pr_title pr_branch pr_base; do
    [ -z "$pr_num" ] && continue

    # Get PR body and commits for reference scanning
    PR_BODY=$(gh pr view "$pr_num" -R "$REPO" --json body -q '.body' 2>/dev/null || true)
    COMMIT_MSGS=$(gh pr view "$pr_num" -R "$REPO" --json commits -q '.commits[].messageHeadline' 2>/dev/null || true)
    ALL_TEXT="$pr_title $PR_BODY $COMMIT_MSGS"

    REF_DEPS=$(find_reference_deps "$ALL_TEXT")

    # Check branch ancestry against other open PRs
    OTHER_PRS=$(echo "$ALL_PRS" | grep -v "^$pr_num|" || true)
    BRANCH_DEPS=$(find_branch_deps "$pr_branch" "$OTHER_PRS")

    if [ -n "$REF_DEPS" ] || [ -n "$BRANCH_DEPS" ]; then
      echo "PR #$pr_num ($pr_title):"

      for dep in $REF_DEPS; do
        DEP_STATE=$(gh pr view "$dep" -R "$REPO" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
        echo "  -> depends on PR #$dep ($DEP_STATE)"
      done

      for dep in $BRANCH_DEPS; do
        echo "  -> branched from PR #$dep (OPEN)"
      done

      echo ""
      HAS_DEPS=true
    fi
  done

  if [ "$HAS_DEPS" = false ]; then
    echo "No dependencies found between open PRs."
  fi
}

# ── Dispatch ──────────────────────────────────────────────

case "$CMD" in
  scan) cmd_scan ;;
  map)  cmd_map ;;
  *)
    echo "Usage: $0 {scan|map} [--pr <number>] [--repo <owner/repo>]"
    exit 1
    ;;
esac
