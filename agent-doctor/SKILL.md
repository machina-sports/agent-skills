---
name: agent-doctor
description: Validate Machina agent templates — check YAML structure, file references, and workflow integrity.
license: MIT
metadata:
  triggers: ["doctor", "validate", "agent", "health", "check", "yaml", "lint"]
  setup:
    env: []
---

# Agent Doctor

Diagnose problems in your Machina agent templates before deploying. Validates YAML syntax, required fields, file references, and directory structure.

## Usage

### Validate a specific agent
```bash
./scripts/agent-doctor.sh validate agent-templates/scout
```

### Validate all agents
```bash
./scripts/agent-doctor.sh validate-all
```

### Options
```bash
# Custom templates directory
./scripts/agent-doctor.sh validate-all --dir my-agents/
```

## Examples
> "Is my agent template valid?"
> "Check all agents for errors."
