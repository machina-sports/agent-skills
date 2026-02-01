#!/bin/bash
set -e

# machina.sh - The Machina Sports SDK Wrapper
# Usage: ./machina.sh [command] [args...]

API_URL="${MACHINA_API_URL:-https://api.machinasports.com/v1}"
API_KEY="${MACHINA_API_KEY}"

# Check for saved config if env vars are missing
if [ -z "$API_KEY" ] && [ -f "$HOME/.machina/config.json" ]; then
  # Simple grep extract for bash portability (jq might not be there)
  API_URL=$(grep -o '"api_url": *"[^"]*"' "$HOME/.machina/config.json" | cut -d'"' -f4)
  API_KEY=$(grep -o '"api_key": *"[^"]*"' "$HOME/.machina/config.json" | cut -d'"' -f4)
fi

if [ -z "$API_KEY" ] && [ "$1" != "auth:login" ]; then
  echo "⚠️  Not authenticated."
  echo "Run './scripts/machina.sh auth:login' first."
  exit 1
fi

cmd="$1"
shift

case "$cmd" in
  "auth:login")
    echo "🔑 Machina Sports Login"
    read -p "Enter API URL (Default: https://api.machinasports.com/v1): " input_url
    API_URL="${input_url:-https://api.machinasports.com/v1}"
    
    read -s -p "Enter API Key: " input_key
    echo ""
    
    config_dir="$HOME/.machina"
    mkdir -p "$config_dir"
    
    cat > "$config_dir/config.json" <<EOF
{
  "api_url": "$API_URL",
  "api_key": "$input_key"
}
EOF
    echo "✅ Configuration saved to ~/.machina/config.json"
    ;;

  "template:list")
    echo "🔍 Fetching available templates..."
    # V1 Mock - real version would curl the templates registry
    echo "Available Templates:"
    echo "1. basic-agent (Simple Q&A)"
    echo "2. sports-analyst (Odds & Stats)"
    echo "3. content-writer (SEO Blog Posts)"
    ;;

  "template:install")
    template_name=""
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --name) template_name="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done

    if [ -z "$template_name" ]; then
      # Interactive mode
      $0 template:list
      read -p "Enter template name to install: " template_name
    fi
    
    echo "📦 Installing template: $template_name..."
    # In V2 this would git clone from machina-templates
    # For now, we simulate the fetch
    
    mkdir -p "agent-templates/$template_name"
    echo "✅ Template '$template_name' downloaded to ./agent-templates/$template_name"
    echo "➡️  Next: Customize _install.yml and run installation."
    ;;

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

  "agent:run")
    id=""
    input="run"
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --id) id="$2"; shift ;;
        --input) input="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done

    echo "🤖 Executing Agent $id..."
    curl -X POST "$API_URL/agent/execute-agent-by-id" \
      -H "X-Api-Token: $API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"agent_id\": \"$id\", \"input\": {\"text\": \"$input\"}}"
    ;;

  "workflow:run")
    id=""
    name=""
    input="{}"
    context="{}"
    
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        --id) id="$2"; shift ;;
        --name) name="$2"; shift ;;
        --input) input="$2"; shift ;;
        --context) context="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
      esac
      shift
    done

    if [ -n "$id" ]; then
      echo "🚀 Triggering Workflow ID: $id..."
      curl -X POST "$API_URL/workflow/execute-workflow-by-id" \
        -H "X-Api-Token: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$id\", \"input\": $input, \"context-workflow\": $context, \"skip_delay\": true}"
    elif [ -n "$name" ]; then
      echo "🚀 Triggering Workflow Name: $name..."
      curl -X POST "$API_URL/workflow/execute-workflow-by-name" \
        -H "X-Api-Token: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$name\", \"input\": $input, \"context-workflow\": $context, \"skip_delay\": true}"
    else
      echo "Error: Must provide --id or --name"
      exit 1
    fi
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
    echo "This command is reserved for self-hosted environments."
    ;;

  *)
    echo "Usage: $0 {agent:create|workflow:run|connector:add|debug:queues}"
    exit 1
    ;;
esac
