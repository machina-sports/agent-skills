#!/bin/bash
set -e

# setup-secrets.sh - Automate GitHub Secrets from .env file
# Usage:
#   bash scripts/setup-secrets.sh                    # uses .env
#   bash scripts/setup-secrets.sh .env.production    # custom file
#   bash scripts/setup-secrets.sh .env -e production # per environment

REPO="machina-sports/agent-skills"
ENVFILE="${1:-.env}"
ENVIRONMENT=""

# Parse flags
shift 2>/dev/null || true
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -e|--environment) ENVIRONMENT="$2"; shift ;;
    -r|--repo) REPO="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# Check gh is installed
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed."
  echo "Install it: brew install gh"
  exit 1
fi

# Check gh is authenticated
if ! gh auth status &> /dev/null; then
  echo "Error: Not authenticated. Run 'gh auth login' first."
  exit 1
fi

# Check .env file exists
if [ ! -f "$ENVFILE" ]; then
  echo "Error: $ENVFILE not found."
  echo "Create one from the template: cp .env.example .env"
  exit 1
fi

echo "Repository: $REPO"
[ -n "$ENVIRONMENT" ] && echo "Environment: $ENVIRONMENT"
echo "Source file: $ENVFILE"
echo "---"

COUNT=0

while IFS= read -r line; do
  # Skip comments and empty lines
  [[ -z "$line" || "$line" == \#* ]] && continue

  KEY=$(echo "$line" | cut -d '=' -f 1)
  VALUE=$(echo "$line" | cut -d '=' -f 2-)

  # Skip example/placeholder values
  if [[ "$VALUE" == *"your-"*"-here"* ]]; then
    echo "Skipping $KEY (placeholder value)"
    continue
  fi

  ENV_FLAG=""
  [ -n "$ENVIRONMENT" ] && ENV_FLAG="-e $ENVIRONMENT"

  echo "Setting $KEY..."
  gh secret set "$KEY" -R "$REPO" $ENV_FLAG --body "$VALUE"
  COUNT=$((COUNT + 1))

done < "$ENVFILE"

echo "---"
echo "Done! $COUNT secrets configured."
echo ""
echo "Verify with: gh secret list -R $REPO"
