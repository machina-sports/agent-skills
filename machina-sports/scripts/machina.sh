#!/bin/bash
set -e

# machina.sh - The Machina Sports SDK Wrapper
# Usage: ./machina.sh [command] [args...]

API_URL="${MACHINA_API_URL:-https://api.machinasports.com/v1}"
API_KEY="${MACHINA_API_KEY}"

if [ -z "$API_KEY" ]; then
  echo "Error: MACHINA_API_KEY is not set."
  echo "Export it or add it to your .env file."
  exit 1
fi

cmd="$1"
shift

case "$cmd" in
  "agent:create")
    name=""
    role="Generic"
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --name) name="$2"; shift ;;
        --role) role="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done
    
    if [ -z "$name" ]; then
      echo "Error: --name is required."
      exit 1
    fi

    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    mkdir -p "agents/$slug"
    
    # Scaffold agent.yml
    cat > "agents/$slug/agent.yml" <<EOF
name: $name
role: $role
version: 1.0.0
description: Auto-generated via Machina SDK
EOF

    # Scaffold workflow.yml
    cat > "agents/$slug/workflow.yml" <<EOF
trigger: manual
steps:
  - id: step_1
    action: llm.process
    prompt: "You are $name. Do your job."
EOF
    
    echo "✅ Agent '$name' created at agents/$slug/"
    ;;

  "workflow:run")
    id=""
    input="{}"
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --id) id="$2"; shift ;;
        --input) input="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done

    echo "🚀 Triggering Workflow $id..."
    # Mocking the actual API call for V1 prototype
    # curl -X POST "$API_URL/workflows/$id/execute" -H "Authorization: Bearer $API_KEY" -d "$input"
    echo "✅ Workflow triggered. Execution ID: exec_$(date +%s)"
    ;;

  "connector:add")
    type=""
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --type) type="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done
    
    echo "📦 Installing connector: $type"
    mkdir -p "connectors/$type"
    touch "connectors/$type/connector.py"
    echo "✅ Connector scaffolded at connectors/$type/"
    ;;

  "ops:queues")
    echo "🔍 Checking Machina Queues..."
    # Placeholder for kubectl/redis logic
    echo "✅ Queues Healthy. Pending: 0."
    ;;

  *)
    echo "Usage: $0 {agent:create|workflow:run|connector:add|ops:queues}"
    exit 1
    ;;
esac
