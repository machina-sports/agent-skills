# Machina Skills

**The official Orchestration & Deployment skills for Machina Cloud.**

This repository contains the orchestration skills that teach an AI agent (like Claude Code, Cursor, or OpenClaw) how to interact with a Machina Cloud Pod. 

These skills act as an "Infrastructure as Code" CLI for AI. They allow an agent to build, validate, and deploy complex YAML templates and connectors directly into a live Machina MongoDB.

## Included Skills

1. `machina-sports`: The core SDK. Trigger workflows, run agents, and check queue status on your live pod.
2. `machina-constructor`: The YAML generator. Teaches the AI the exact schema required to build custom agents, workflows, and connectors from scratch.
3. `machina-installer`: The Deployment engine. Allows the AI to fetch pre-built templates from the `machina-templates` repository and push them directly to a pod using the `import_template_from_git` MCP tool.
4. `machina-secrets`: The Vault manager. Securely injects third-party data API credentials (e.g., Sportradar, Opta, Twitter) into the Machina pod vault.

## Installation

Add this package to your agent's context:

```bash
npx skills add machina-sports/machina-skills
```

Once installed, simply ask your agent:
> *"Install the sports-analyst agent to my pod and configure my Sportradar API key."*

The agent will handle the Git imports, the MCP execution, and the vault configuration automatically.

---
*Note: This repository is the orchestration bridge. The actual template source code lives in the `machina-templates` repository.*
