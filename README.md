# Machina Sports Agent Skills

The official SDK for building AI Agents on the **Machina Sports** platform.

This repository contains **Agent Skills** that can be installed directly into AI agents (like Claude Code, Cursor, or OpenClaw) to give them the ability to interact with the Machina Sports ecosystem.

## 📦 Skills

### `machina-sports`
The core builder skill. Gives your agent the ability to:
- 🏗️ **Scaffold** new Agents and Workflows locally.
- 🚀 **Execute** Agents and Workflows via the Machina API.
- 🔌 **Install** data connectors (PyScript/REST).

## 🚀 Installation

Install this skill into your agent with one command:

```bash
npx skills add machina-sports/agent-skills
```

## 🛠️ Usage

Once installed, you can ask your agent to perform tasks like:

> "Create a new sports analyst agent named 'Scout'."
> "Run the 'fetch-odds' workflow for the NBA."
> "Install a Google Sheets connector."

### Manual Setup
If you prefer to run the CLI directly:

1. **Authenticate:**
   ```bash
   ./scripts/machina.sh auth:login
   ```
   (Or set `MACHINA_API_URL` and `MACHINA_API_KEY` in your environment).

2. **Run Commands:**
   ```bash
   ./scripts/machina.sh agent:create --name "MyAgent"
   ./scripts/machina.sh agent:run --id "agent_123" --input "Hello"
   ```

## 📚 Documentation
For full platform documentation, visit [docs.machina.gg](https://docs.machina.gg).

## License
MIT
