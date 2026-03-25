# Browser MCP Setup — Design Spec

**Date:** 2026-03-25
**Status:** Approved

---

## Goal

Configure a general-purpose, "swiss army knife" browser automation capability for Claude Code via two MCP servers: a fast low-token default (Playwright) and a stealth fallback (Camoufox). Then use the Playwright server to download university coursework from a gofile.io link and store it in the correct module folder.

---

## Architecture

Two MCP servers registered in `~/.claude/settings.json`:

### 1. Playwright MCP (default)
- **Package:** `@playwright/mcp` (verified: v0.0.68 on npm, Microsoft-maintained)
- **Engine:** Chromium (default) — can switch to `--browser firefox` or `--browser webkit`
- **Mode:** Accessibility tree snapshots by default (incremental mode, ~500 tokens per interaction). No flag needed — this is the default behaviour.
- **Launch:** `npx @playwright/mcp@latest`
- **Use for:** All standard browsing tasks — JS-rendered pages, file downloads, form fills, navigation

### 2. Camoufox MCP (stealth fallback)
- **Location:** `~/.local/share/mcp-servers/camoufox-mcp/`
- **Engine:** Firefox (anti-detect, fingerprint-spoofed)
- **Launch:** `uv run main.py` from the project directory
- **Use for:** Sites with aggressive bot detection where Playwright gets blocked
- **Package manager:** `uv` (no virtualenv management needed)

### Exposed tools (Camoufox MCP)
| Tool | Description |
|------|-------------|
| `navigate` | Navigate to a URL and wait for JS to render |
| `snapshot` | Return accessibility tree / DOM text (low token) |
| `screenshot` | Capture full-page screenshot (higher token) |
| `click` | Click element by selector or description |
| `type` | Type text into an input field |
| `download` | Download a file to a specified local path |

---

## File Structure (Camoufox MCP — to be authored)

```
~/.local/share/mcp-servers/camoufox-mcp/
├── main.py          # MCP server entrypoint (to be authored by coding agent)
├── browser.py       # Camoufox session management
├── tools.py         # Tool definitions (navigate, click, etc.)
└── pyproject.toml   # Dependencies: camoufox, mcp[cli]
```

---

## Target `~/.claude/settings.json` (complete file)

```json
{
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "skill-creator@claude-plugins-official": true,
    "greptile@claude-plugins-official": false,
    "hookify@claude-plugins-official": true,
    "sentry@claude-plugins-official": false
  },
  "skipDangerousModePermissionPrompt": true,
  "mcpServers": {
    "playwright": {
      "command": "/home/zo/.nvm/versions/node/v22.22.1/bin/npx",
      "args": ["@playwright/mcp@0.0.68"]
    },
    "camoufox": {
      "command": "/home/zo/.local/bin/uv",
      "args": ["run", "main.py"],
      "cwd": "/home/zo/.local/share/mcp-servers/camoufox-mcp"
    }
  }
}
```

> **Note:** Full paths are used for both `npx` and `uv` because Claude Code MCP processes may not inherit the full user `$PATH` (nvm and `~/.local/bin` are user-session PATH entries). Version `@0.0.68` is pinned for stability — bump intentionally when upgrading.

---

## Setup Steps

### Playwright MCP
No installation required — `npx` fetches on demand.

### Camoufox MCP
1. Create directory: `mkdir -p ~/.local/share/mcp-servers/camoufox-mcp`
2. Author `pyproject.toml`, `main.py`, `browser.py`, `tools.py`
3. Install dependencies: `cd ~/.local/share/mcp-servers/camoufox-mcp && uv sync`
4. Fetch Firefox binary (one-time): `uv run -m camoufox fetch`
5. Test server starts: `uv run main.py`

---

## Gofile.io Download Task

After browser MCPs are configured:

1. Use Playwright MCP to navigate to `https://gofile.io/d/Dl0SyY`
2. If the link is expired, password-protected, or shows no download button — stop and report back to the user. Do not proceed.
3. Identify and click the download button for the Word document (`.docx`)
4. Save file to `/home/zo/University/FA583/coursework/`
5. Before placing the file, list existing files in `FA583/coursework/` and **confirm with user before deleting** any old coursework files (currently: `RELX_Report_FA583.docx`, `RELX_Financial_Analysis_FA583.xlsx`, `build_docx.py`, `build_xlsx.py`)

---

## Token Strategy

- Default to Playwright accessibility tree mode for all tasks (~500 tokens per interaction)
- Screenshots are available as individual tool calls in default mode — no extra flags needed
- `--caps vision` switches the server's primary mode to vision-based (higher token cost) and should not be used
- Use Camoufox only when Playwright is blocked by bot detection

---

## Out of Scope

- Auth/login session persistence (cookies, profiles) — deferred
- Proxy configuration — deferred
- Automated scheduling of downloads — not needed
