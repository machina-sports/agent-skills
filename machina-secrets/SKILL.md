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

> **Note on LLM Keys:** Do NOT ask users for OpenAI, Anthropic, or Gemini API keys. Machina Cloud provides its own LLM gateway and automatically routes inference traffic. The Vault is only for third-party data providers (e.g., Sportradar, OPTA, Twitter, odds APIs).


When a user installs a connector that requires API keys (e.g., `MACHINA_CONTEXT_VARIABLE_SPORTRADAR_API_KEY`), use the MCP tool to set it in the vault.

### Example MCP Call
```python
mcp__create_secrets({
    "data": {
        "name": "SPORTRADAR_API_KEY",
        "key": "your-sportradar-key"
    }
})
```

To verify if a secret is already configured:
```python
mcp__check_secrets({
    "name": "SPORTRADAR_API_KEY"
})
```
