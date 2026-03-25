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
- **Package:** `@playwright/mcp` (Microsoft-maintained)
- **Engine:** Chromium
- **Mode:** Snapshot (accessibility tree) — ~500 tokens per interaction
- **Launch:** `npx @playwright/mcp@latest --snapshot`
- **Use for:** All standard browsing tasks — JS-rendered pages, file downloads, form fills, navigation
- **No installation required** — `npx` handles it on demand

### 2. Camoufox MCP (stealth fallback)
- **Location:** `~/.local/share/mcp-servers/camoufox-mcp/`
- **Engine:** Firefox (anti-detect, fingerprint-spoofed)
- **Mode:** DOM snapshot + screenshot
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

## File Structure

```
~/.local/share/mcp-servers/camoufox-mcp/
├── main.py          # MCP server entrypoint
├── browser.py       # Camoufox session management
├── tools.py         # Tool definitions (navigate, click, etc.)
└── pyproject.toml   # Dependencies: camoufox, mcp[cli]
```

---

## Claude Settings

Both servers added to `~/.claude/settings.json` under `mcpServers`:

```json
"mcpServers": {
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--snapshot"]
  },
  "camoufox": {
    "command": "uv",
    "args": ["run", "main.py"],
    "cwd": "/home/zo/.local/share/mcp-servers/camoufox-mcp"
  }
}
```

---

## Gofile.io Download Task

After browser MCPs are configured:

1. Use Playwright MCP to navigate to `https://gofile.io/d/Dl0SyY`
2. Identify and click the download button for the Word document
3. Save file to `/home/zo/University/FA583/`
4. Before saving, list existing files in FA583 and **confirm with user** before deleting any old coursework files
5. Place new file in the appropriate subfolder (e.g. `Coursework/` or root of FA583)

---

## Token Strategy

- Default to Playwright snapshot mode for all tasks (accessibility tree, minimal tokens)
- Use screenshot only when visual layout is needed
- Use Camoufox only when Playwright is blocked

---

## Out of Scope

- Auth/login session persistence (cookies, profiles) — deferred
- Proxy configuration — deferred
- Automated scheduling of downloads — not needed
