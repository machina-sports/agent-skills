#!/bin/bash
set -e

# machina.sh - The Machina Sports SDK Wrapper
# Usage: ./machina.sh [command] [args...]

API_URL="${MACHINA_API_URL:-https://api.machinasports.com/v1}"
API_KEY="${MACHINA_API_KEY}"

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
    mkdir -p "agent-templates/$slug"/{agents,workflows,prompts,connectors,tests}
    
    # Generate _install.yml
    cat > "agent-templates/$slug/_install.yml" <<EOF
setup:
  title: "$name"
  description: "Agent for $role"
  category: [custom-agents]
  version: 1.0.0

datasets:
  - type: workflow
    path: workflows/main.yml
  - type: agent
    path: agents/main.yml
EOF

    # Generate agents/main.yml
    cat > "agent-templates/$slug/agents/main.yml" <<EOF
agent:
  name: $slug
  title: $name
  description: $role
  workflows:
    - name: ${slug}-workflow
      description: Main workflow
      inputs:
        input: $.get('context_value')
      outputs:
        result: $.get('result')
EOF

    # Generate workflows/main.yml
    cat > "agent-templates/$slug/workflows/main.yml" <<EOF
workflow:
  name: ${slug}-workflow
  title: $name Process
  inputs:
    input: $.get('input')
  outputs:
    result: $.get('result')
    workflow-status: 'executed'
  tasks:
    - type: prompt
      name: process-input
      connector:
        name: machina-ai
        command: invoke_prompt
      inputs:
        _0-instruction: "You are $name ($role). Process this: "
        _1-input: $.get('input')
      outputs:
        result: $.get('response')
EOF
    
    echo "✅ Agent '$name' scaffolded at agent-templates/$slug/"
    echo "➡️  Next: Run mcp__docker_localhost__import_template_from_local(template=\"agent-templates/$slug\", project_path=\"/app/YOUR_REPO/agent-templates/$slug\")"
    ;;

  "workflow:run")
    echo "⚠️  To run a workflow, use the MCP tool directly:"
    echo "mcp__machina_client_dev__execute_workflow(name=\"WORKFLOW_NAME\", context={...})"
    ;;

  "connector:add")
    name=""
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --name) name="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done
    
    if [ -z "$name" ]; then
      echo "Error: --name is required."
      exit 1
    fi

    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    mkdir -p "connectors/$slug"
    
    # _install.yml
    cat > "connectors/$slug/_install.yml" <<EOF
setup:
  title: "$name Connector"
  version: 1.0.0

datasets:
  - type: connector
    path: $slug.yml
EOF

    # Definition YAML
    cat > "connectors/$slug/$slug.yml" <<EOF
connector:
  name: $slug
  description: Custom connector for $name
  filename: $slug.py
  filetype: pyscript
  commands:
    - name: Fetch Data
      value: fetch_data
EOF

    # Python Script
    cat > "connectors/$slug/$slug.py" <<EOF
def fetch_data(request_data):
    """
    Standard Machina Connector Pattern
    """
    headers = request_data.get("headers", {})
    params = request_data.get("params", {})
    
    return {
        "status": True,
        "data": {"message": "Hello from $name"},
        "message": "Success"
    }
EOF
    
    echo "✅ Connector '$name' scaffolded at connectors/$slug/"
    ;;

  "debug:queues")
    namespace="${2:-default}"
    echo "🔍 Checking Machina Queue Workers (Namespace: $namespace)..."

    if ! kubectl get deployment machina-worker -n "$namespace" >/dev/null 2>&1; then
        echo "⚠️  No 'machina-worker' deployment found. Are you connected to the right cluster?"
        # Fallback for local docker
        docker-compose ps | grep celery
        exit 0
    fi

    echo "--- Worker Pods ---"
    kubectl get pods -n "$namespace" -l app=machina-worker -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp

    if kubectl get hpa machina-worker -n "$namespace" >/dev/null 2>&1; then
        echo -e "\n--- Autoscaling Metrics (Load) ---"
        kubectl get hpa machina-worker -n "$namespace"
    fi
    ;;

  *)
    echo "Usage: $0 {agent:create|workflow:run|connector:add|debug:queues}"
    exit 1
    ;;
esac
