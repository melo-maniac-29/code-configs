# 9router + CodeGraph MCP Setup for OpenCode

## Why this setup? (The problem)

AI coding agents (OpenCode, Claude Code, Cursor, etc.) understand your codebase by searching: `grep`, `glob`, `Read` — one file at a time. Every time you ask a question, the agent burns **dozens of tool calls and millions of tokens** rediscovering code structure it already found five minutes ago. That's slow, expensive, and wastes context window on discovery instead of real work.

## What CodeGraph MCP solves

CodeGraph ([colbymchenry/codegraph](https://github.com/colbymchenry/codegraph), 62K+ stars) is a **persistent semantic code graph** — a pre-built SQLite database of every symbol, function, class, call edge, import, and dependency in your project. It exposes this through an MCP server so the agent answers from the graph in **one or two calls** instead of crawling files.

### Concrete wins (benchmarked Jul 2026)

| Codebase | Tool calls | File reads | Tokens saved | Cost saved |
|----------|-----------|------------|-------------|------------|
| VS Code (11K files) | **2** vs 40 | **0** vs 17 | 83% fewer | 75% cheaper |
| Django (3K files) | **2** vs 29 | **0** vs 16 | 78% fewer | 69% cheaper |
| Tokio (Rust, 790 files) | **3** vs 57 | **0** vs 15 | 91% fewer | 86% cheaper |
| A 100-file Go project | **3** vs 10 | **0** vs 4 | 18% fewer | 41% cheaper |

Key takeaway: **Zero file reads** across all seven benchmark repos when CodeGraph is active. The agent stops grepping and answers from the graph.

### 9router's role

[9router](https://github.com/decolua/9router) (23K+ stars) provides a local OpenAI-compatible API endpoint at `http://localhost:20128/v1`. It routes your requests to any provider (Kimi, Claude, GLM, etc.) with automatic fallback and token savings via RTK. We use it here to feed free/cheap Moonshot Kimi models to OpenCode.

## What the installer does

After running the installer:

- 9router installed globally and set to auto-start at boot
- CodeGraph installed globally and MCP wired into OpenCode via `codegraph install --yes`
- Any project indexed with `codegraph init` is instantly queryable by OpenCode

## How to use CodeGraph in OpenCode

### Index your project (one time)

```bash
cd /path/to/your-project
codegraph init
```

This creates `.codegraph/` in the project root and builds the full graph. After that, file changes auto-sync — never re-run it.

### Natural language queries that work

**Finding code:**
- *"Where is `process_payment` defined?"*
- *"Find the `UserService` class."*
- *"Show me code related to database connection."*

**Call chains & impact:**
- *"Who calls `validate_input`?"*
- *"If I change `calculate_tax`, what else breaks?"*
- *"Trace the call chain from `main` to `process_data`."*
- *"What methods does the `Order` class have?"*

**Architecture & design:**
- *"Show the inheritance hierarchy for `BaseController`."*
- *"Which files import the `requests` library?"*
- *"Find all implementations of the `render` method."*

**Code quality:**
- *"Find dead code in this project."*
- *"Calculate cyclomatic complexity of `handle_request` in app.py."*
- *"Find the 5 most complex functions."*

## Quick installers

The install scripts live in the `code-configs` workspace:

- **Windows**: `install-9router-codegraph.bat` (Run as Administrator)
- **Linux / macOS / WSL**: `install-9router-codegraph.sh`

```bash
cd /mnt/C/Works/code-configs
chmod +x install-9router-codegraph.sh
./install-9router-codegraph.sh
```

### What the script does

1. Installs `9router` (global npm)
2. Installs `@colbymchenry/codegraph` (global npm)
3. Runs `codegraph install --yes` → wires MCP into OpenCode automatically
4. Sets 9router to auto-start on boot:
   - **Linux**: systemd --user service
   - **macOS**: launchd agent
   - **Windows**: Scheduled Task at login

## Manual opencode.json (if not using the installer)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "9router/moonshot/kimi-k2.7-code",
  "small_model": "9router/moonshot/kimi-k2.5",
  "enabled_providers": ["9router"],
  "provider": {
    "9router": {
      "options": {
        "apiKey": "PASTE_YOUR_9ROUTER_API_KEY_HERE",
        "baseURL": "http://localhost:20128/v1"
      }
    }
  },
  "mcp": {
    "codegraph": {
      "type": "local",
      "command": ["codegraph", "serve", "--mcp"],
      "enabled": true
    }
  }
}
```

## After installation

1. **Configure 9router**: Open `http://localhost:20128` → Providers → Add Kimi/Moonshot with your API key → Create a model combo named `moonshot/kimi-k2.7-code`
2. **Set the API key** in OpenCode config → `provider.9router.options.apiKey`
3. **Index your projects**: `codegraph init .` in each repo you work on
4. **Restart OpenCode**

## Useful commands

```bash
codegraph status          # Check if graph is up-to-date
codegraph upgrade         # Update to latest version
codegraph uninstall       # Remove CodeGraph from all agents
9router                   # Start 9router manually
```

## References

- CodeGraph repo: https://github.com/colbymchenry/codegraph
- 9router repo: https://github.com/decolua/9router
- OpenCode config: https://opencode.ai/config.json
