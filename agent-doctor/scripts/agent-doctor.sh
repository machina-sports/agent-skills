#!/bin/bash
set -e

# agent-doctor.sh - Validate Machina agent templates
# Usage:
#   ./agent-doctor.sh validate agent-templates/scout
#   ./agent-doctor.sh validate-all
#   ./agent-doctor.sh validate-all --dir my-agents/

# ── Defaults ──────────────────────────────────────────────

TEMPLATES_DIR="agent-templates"
CMD="${1:-help}"
TARGET="${2:-}"
shift 2 2>/dev/null || shift 2>/dev/null || true

# ── Parse flags ───────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --dir) TEMPLATES_DIR="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ───────────────────────────────────────────────

ERRORS=0
WARNINGS=0

error() {
  echo "  [ERROR] $1"
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "  [WARN]  $1"
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  echo "  [OK]    $1"
}

check_yaml_syntax() {
  local file="$1"
  # Basic YAML validation: check for tab indentation (YAML uses spaces)
  if grep -P '\t' "$file" &>/dev/null; then
    error "$file contains tabs (YAML requires spaces)"
    return 1
  fi
  # Check for obvious syntax issues: odd number of quotes on a line (unbalanced)
  while IFS= read -r yaml_line; do
    [[ -z "$yaml_line" || "$yaml_line" =~ ^[[:space:]]*# ]] && continue
    QUOTE_COUNT=$(echo "$yaml_line" | tr -cd '"' | wc -c | tr -d ' ')
    if [ "$((QUOTE_COUNT % 2))" -ne 0 ]; then
      warn "$file has unbalanced quotes"
      break
    fi
  done < "$file"
  return 0
}

# ── Command: validate ─────────────────────────────────────

cmd_validate() {
  local agent_path="$1"

  if [ -z "$agent_path" ]; then
    echo "Error: Provide the agent path."
    echo "Usage: $0 validate <path>"
    exit 1
  fi

  if [ ! -d "$agent_path" ]; then
    echo "Error: $agent_path is not a directory."
    exit 1
  fi

  AGENT_NAME=$(basename "$agent_path")
  echo "Diagnosing: $AGENT_NAME"
  echo "Path: $agent_path"
  echo "---"

  ERRORS=0
  WARNINGS=0

  # 1. Check _install.yml exists
  if [ -f "$agent_path/_install.yml" ]; then
    ok "_install.yml found"
    check_yaml_syntax "$agent_path/_install.yml"

    # Check required fields in _install.yml
    if grep -q "setup:" "$agent_path/_install.yml"; then
      ok "_install.yml has 'setup' section"
    else
      error "_install.yml missing 'setup' section"
    fi

    if grep -q "datasets:" "$agent_path/_install.yml"; then
      ok "_install.yml has 'datasets' section"
    else
      error "_install.yml missing 'datasets' section"
    fi

    # Validate dataset file references
    while IFS= read -r ref_path; do
      ref_path=$(echo "$ref_path" | sed 's/^[[:space:]]*path:[[:space:]]*//' | tr -d '"' | tr -d "'")
      if [ -f "$agent_path/$ref_path" ]; then
        ok "Referenced file exists: $ref_path"
      else
        error "Referenced file not found: $ref_path"
      fi
    done < <(grep "path:" "$agent_path/_install.yml" 2>/dev/null || true)
  else
    error "_install.yml not found"
  fi

  # 2. Check directory structure
  for dir in agents workflows; do
    if [ -d "$agent_path/$dir" ]; then
      ok "$dir/ directory exists"
    else
      warn "$dir/ directory missing"
    fi
  done

  # 3. Validate agent YAML files
  if [ -d "$agent_path/agents" ]; then
    for yml in "$agent_path"/agents/*.yml; do
      [ -f "$yml" ] || continue
      FNAME=$(basename "$yml")
      check_yaml_syntax "$yml"

      if grep -q "agent:" "$yml"; then
        ok "$FNAME has 'agent' root key"
      else
        error "$FNAME missing 'agent' root key"
      fi

      if grep -q "name:" "$yml"; then
        ok "$FNAME has 'name' field"
      else
        error "$FNAME missing 'name' field"
      fi

      if grep -q "workflows:" "$yml"; then
        ok "$FNAME references workflows"
      else
        warn "$FNAME has no workflow references"
      fi
    done
  fi

  # 4. Validate workflow YAML files
  if [ -d "$agent_path/workflows" ]; then
    for yml in "$agent_path"/workflows/*.yml; do
      [ -f "$yml" ] || continue
      FNAME=$(basename "$yml")
      check_yaml_syntax "$yml"

      if grep -q "workflow:" "$yml"; then
        ok "$FNAME has 'workflow' root key"
      else
        error "$FNAME missing 'workflow' root key"
      fi

      if grep -q "tasks:" "$yml"; then
        ok "$FNAME has 'tasks' section"
      else
        error "$FNAME missing 'tasks' section"
      fi

      # Check connector references exist
      while IFS= read -r connector_name; do
        connector_name=$(echo "$connector_name" | sed 's/^[[:space:]]*name:[[:space:]]*//' | tr -d '"' | tr -d "'")
        if [ -n "$connector_name" ]; then
          ok "$FNAME uses connector: $connector_name"
        fi
      done < <(grep -A1 "connector:" "$yml" 2>/dev/null | grep "name:" || true)
    done
  fi

  # 5. Check for Python connector files
  if [ -d "$agent_path/connectors" ]; then
    for py in "$agent_path"/connectors/*.py; do
      [ -f "$py" ] || continue
      FNAME=$(basename "$py")
      ok "Connector script found: $FNAME"
    done
  fi

  # Summary
  echo ""
  echo "---"
  if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "Result: Healthy! No issues found."
  elif [ "$ERRORS" -eq 0 ]; then
    echo "Result: $WARNINGS warning(s), 0 errors. Looks good."
  else
    echo "Result: $ERRORS error(s), $WARNINGS warning(s). Needs fixing."
  fi
}

# ── Command: validate-all ─────────────────────────────────

cmd_validate_all() {
  if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "Error: $TEMPLATES_DIR directory not found."
    echo "Use --dir to specify the templates directory."
    exit 1
  fi

  TOTAL=0
  TOTAL_ERRORS=0

  for agent_dir in "$TEMPLATES_DIR"/*/; do
    [ -d "$agent_dir" ] || continue
    TOTAL=$((TOTAL + 1))
    echo ""
    cmd_validate "${agent_dir%/}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
    echo ""
  done

  if [ "$TOTAL" -eq 0 ]; then
    echo "No agent templates found in $TEMPLATES_DIR/"
    exit 0
  fi

  echo "========================"
  echo "Scanned $TOTAL agent(s). Total errors: $TOTAL_ERRORS"
}

# ── Dispatch ──────────────────────────────────────────────

case "$CMD" in
  validate)     cmd_validate "$TARGET" ;;
  validate-all) cmd_validate_all ;;
  *)
    echo "Usage: $0 {validate <path>|validate-all} [--dir <templates-dir>]"
    exit 1
    ;;
esac
