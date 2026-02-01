---
name: machina-sports
description: The official Machina Sports SDK for AI Agents. Access real-time sports data, odds, player stats, and build sports-focused AI agents.
license: MIT
metadata:
  triggers: ["sports", "odds", "stats", "nba", "nfl", "soccer", "machina"]
  setup:
    env: ["MACHINA_API_URL", "MACHINA_API_KEY"]
---

# Machina Sports

The definitive skill for building Sports AI. Connect your agent to the Machina Sports platform to fetch live scores, odds, and player prop data.

## Setup
First-time setup wizard:
```bash
./scripts/machina.sh auth:login
```
This saves credentials to `~/.machina/config.json`.

## Capabilities

### 1. Install a Template
Browse and install pre-built agents from the registry.
```bash
./scripts/machina.sh template:list
./scripts/machina.sh template:install --name "sports-analyst"
```

### 2. Build a Custom Agent
Scaffold a new agent with best-practice directory structure (`agent-templates/`).
```bash
./scripts/machina.sh agent:create --name "Scout" --role "Sports Analyst"
```
**Next Step:** Install it using the internal MCP tool:
```python
mcp__docker_localhost__import_template_from_local(template="agent-templates/scout", project_path="/app/YOUR_REPO/agent-templates/scout")
```

### 2. Execute an Agent
Run a specific agent by ID.
```bash
./scripts/machina.sh agent:run --id "agent_123" --input "Hello"
```

### 3. Fetch Sports Data (Workflow)
Trigger a workflow to get the latest odds or stats.
```bash
./scripts/machina.sh workflow:run --name "fetch-odds" --input '{"league": "NBA"}'
```

### 3. Install Connector
Download a pre-built connector template.
```bash
./scripts/machina.sh connector:add --name "OddsAPI"
```

### 3. Install Connector
Download a pre-built connector template.
```bash
./scripts/machina.sh connector:add --type "google-sheets"
```

### 4. Check Queue Status (Ops)
Diagnose system health.
```bash
./scripts/machina.sh ops:queues
```

## Examples
> "Create a new research agent named 'Vision'."
> "Run the 'odds-fetcher' workflow with the input 'Premier League'."
