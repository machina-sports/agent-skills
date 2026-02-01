---
name: machina-sdk
description: The official Machina Sports SDK for AI Agents. Create agents, scaffold workflows, and manage data connectors directly from your agent environment.
license: MIT
metadata:
  triggers: ["machina", "create agent", "run workflow", "sdk"]
  setup:
    env: ["MACHINA_API_URL", "MACHINA_API_KEY"]
---

# Machina Sports SDK

The operational brain for Machina Sports developers. Use this skill to interact with the Machina Platform without leaving your agent session.

## Setup
Set your environment variables (in `.env` or session config):
```bash
export MACHINA_API_URL="https://api.machinasports.com/v1"
export MACHINA_API_KEY="ms_live_..."
```

## Capabilities

### 1. Create Agent
Scaffold a new agent with best-practice directory structure.
```bash
./scripts/machina.sh agent:create --name "Scout" --role "Recruiting"
```
**Outcome:** Creates `agents/scout/agent.yml` and `agents/scout/workflow.yml`.

### 2. Run Workflow
Trigger a workflow execution and stream the logs.
```bash
./scripts/machina.sh workflow:run --id "wkfl_123" --input '{"query": "latest odds"}'
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
