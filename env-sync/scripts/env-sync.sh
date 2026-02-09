#!/bin/bash
set -e

# env-sync.sh - Compare .env.example with GitHub repo secrets
# Usage:
#   ./env-sync.sh check
#   ./env-sync.sh check --file .env.production --repo owner/repo

# ── Defaults ──────────────────────────────────────────────

ENVFILE=".env.example"
REPO=""
CMD="${1:-check}"
shift 2>/dev/null || true

# ── Parse flags ───────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --file) ENVFILE="$2"; shift ;;
    --repo|-r) REPO="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ───────────────────────────────────────────────

detect_repo() {
  if [ -n "$REPO" ]; then
    return
  fi
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
  if [ -z "$REPO" ]; then
    echo "Error: Could not detect repo. Use --repo owner/repo."
    exit 1
  fi
}

check_prerequisites() {
  if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install it: brew install gh"
    exit 1
  fi

  if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated. Run 'gh auth login' first."
    exit 1
  fi
}

# ── Command: check ────────────────────────────────────────

cmd_check() {
  check_prerequisites
  detect_repo

  if [ ! -f "$ENVFILE" ]; then
    echo "Error: $ENVFILE not found."
    exit 1
  fi

  echo "Repo:    $REPO"
  echo "Source:  $ENVFILE"
  echo "---"

  # Extract keys from .env file (skip comments and empty lines)
  LOCAL_KEYS=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    KEY=$(echo "$line" | cut -d '=' -f 1)
    LOCAL_KEYS+=("$KEY")
  done < "$ENVFILE"

  # Get GitHub secrets (names only)
  REMOTE_KEYS=()
  while IFS= read -r name; do
    [ -n "$name" ] && REMOTE_KEYS+=("$name")
  done < <(gh secret list -R "$REPO" --json name -q '.[].name' 2>/dev/null)

  # Compare
  MISSING=()
  IN_SYNC=()
  EXTRA=()

  for key in "${LOCAL_KEYS[@]}"; do
    FOUND=false
    for rkey in "${REMOTE_KEYS[@]}"; do
      if [ "$key" = "$rkey" ]; then
        FOUND=true
        break
      fi
    done
    if [ "$FOUND" = true ]; then
      IN_SYNC+=("$key")
    else
      MISSING+=("$key")
    fi
  done

  for rkey in "${REMOTE_KEYS[@]}"; do
    FOUND=false
    for key in "${LOCAL_KEYS[@]}"; do
      if [ "$rkey" = "$key" ]; then
        FOUND=true
        break
      fi
    done
    if [ "$FOUND" = false ]; then
      EXTRA+=("$rkey")
    fi
  done

  # Report
  if [ ${#IN_SYNC[@]} -gt 0 ]; then
    echo ""
    echo "In sync (${#IN_SYNC[@]}):"
    for key in "${IN_SYNC[@]}"; do
      echo "  [ok] $key"
    done
  fi

  if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Missing from GitHub (${#MISSING[@]}):"
    for key in "${MISSING[@]}"; do
      echo "  [!!] $key"
    done
    echo ""
    echo "Fix with:"
    echo "  bash scripts/setup-secrets.sh .env"
  fi

  if [ ${#EXTRA[@]} -gt 0 ]; then
    echo ""
    echo "Extra in GitHub — not in $ENVFILE (${#EXTRA[@]}):"
    for key in "${EXTRA[@]}"; do
      echo "  [??] $key"
    done
    echo ""
    echo "These may be obsolete. Remove with:"
    for key in "${EXTRA[@]}"; do
      echo "  gh secret delete $key -R $REPO"
    done
  fi

  if [ ${#MISSING[@]} -eq 0 ] && [ ${#EXTRA[@]} -eq 0 ]; then
    echo ""
    echo "All in sync! No action needed."
  fi
}

# ── Dispatch ──────────────────────────────────────────────

case "$CMD" in
  check) cmd_check ;;
  *)
    echo "Usage: $0 check [--file <envfile>] [--repo <owner/repo>]"
    exit 1
    ;;
esac
