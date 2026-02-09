---
name: env-sync
description: Compare your .env.example with GitHub repo secrets and detect missing, extra, or out-of-sync variables.
license: MIT
metadata:
  triggers: ["env", "secrets", "sync", "environment", "variables", "dotenv"]
  setup:
    env: []
---

# Env Sync

Never deploy with missing secrets again. This skill compares your `.env.example` (source of truth) against the secrets actually configured in your GitHub repository.

## Usage

### Check for missing secrets
```bash
./scripts/env-sync.sh check
```
Compares `.env.example` keys against GitHub secrets and shows what's missing, what's extra, and what's in sync.

### Options
```bash
# Custom env file
./scripts/env-sync.sh check --file .env.production

# Custom repo
./scripts/env-sync.sh check --repo owner/repo
```

## Examples
> "Are all my env vars configured as GitHub secrets?"
> "Which secrets am I missing in the repo?"
