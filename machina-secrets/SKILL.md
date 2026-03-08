---
name: machina-secrets
description: Manage and configure secure vault credentials for third-party API keys required by Machina connectors.
license: MIT
metadata:
  triggers: ["add api key", "configure secrets", "set token", "vault"]
---

# Machina Secrets Manager

This skill allows the agent to securely inject third-party API keys (OpenAI, Sportradar, Google) into the Machina Pod's encrypted vault.

## Usage

When a user installs a connector that requires API keys (e.g., `MACHINA_CONTEXT_VARIABLE_OPENAI_API_KEY`), use the MCP tool to set it in the vault.

### Example MCP Call
```python
mcp__create_secrets({
    "data": {
        "name": "OPENAI_API_KEY",
        "key": "sk-proj-..."
    }
})
```

To verify if a secret is already configured:
```python
mcp__check_secrets({
    "name": "OPENAI_API_KEY"
})
```
