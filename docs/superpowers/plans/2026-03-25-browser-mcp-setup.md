# Browser MCP Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Playwright MCP and Camoufox MCP as two browser automation servers in Claude Code, then use Playwright to download FA583 coursework from gofile.io.

**Architecture:** Playwright MCP runs via npx (zero install, accessibility-tree mode for low token usage). Camoufox MCP is a small Python MCP server wrapping the `camoufox` library — pure tool functions in `tools.py` are tested independently, `browser.py` manages the Firefox session, `main.py` wires everything into a FastMCP server.

**Tech Stack:** Python 3.11+, `uv`, `camoufox`, `mcp[cli]` (FastMCP), `pytest`, Node.js/npx, `@playwright/mcp@0.0.68`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `~/.claude/settings.json` | Modify | Add `mcpServers` block for both servers |
| `~/.local/share/mcp-servers/camoufox-mcp/pyproject.toml` | Create | uv project config + dependencies |
| `~/.local/share/mcp-servers/camoufox-mcp/browser.py` | Create | Camoufox session lifecycle (get_page, shutdown) |
| `~/.local/share/mcp-servers/camoufox-mcp/tools.py` | Create | Pure tool functions that accept a Playwright `Page` and return strings |
| `~/.local/share/mcp-servers/camoufox-mcp/main.py` | Create | FastMCP server entrypoint — registers tools, wires browser.py |
| `~/.local/share/mcp-servers/camoufox-mcp/tests/test_tools.py` | Create | Unit tests for tools.py using mock Page objects |

---

## Task 1: Register Playwright MCP in settings.json

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Read current settings.json**

```bash
cat ~/.claude/settings.json
```

- [ ] **Step 2: Add mcpServers block**

Edit `~/.claude/settings.json` to match exactly:

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
    }
  }
}
```

> Camoufox is added in Task 6 once the server is built and verified. Adding it now would cause Claude Code to log errors on startup.

- [ ] **Step 3: Verify JSON is valid**

```bash
python3 -m json.tool ~/.claude/settings.json
```
Expected: prints formatted JSON with no errors.

- [ ] **Step 4: Commit**

```bash
git -C ~ add .claude/settings.json
git -C ~ commit -m "feat: register Playwright MCP server"
```

---

## Task 2: Bootstrap camoufox MCP project

**Files:**
- Create: `~/.local/share/mcp-servers/camoufox-mcp/pyproject.toml`

- [ ] **Step 1: Create directory**

```bash
mkdir -p ~/.local/share/mcp-servers/camoufox-mcp/tests
```

- [ ] **Step 2: Create pyproject.toml**

Write `~/.local/share/mcp-servers/camoufox-mcp/pyproject.toml`:

```toml
[project]
name = "camoufox-mcp"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "camoufox[geoip]",
    "mcp[cli]",
    "pytest",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

- [ ] **Step 3: Install dependencies**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && /home/zo/.local/bin/uv sync
```
Expected: resolves and installs packages, creates `.venv/`.

- [ ] **Step 4: Verify uv environment**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && /home/zo/.local/bin/uv run python -c "import camoufox; import mcp; print('OK')"
```
Expected: prints `OK`.

---

## Task 3: Write failing tests for tools

**Files:**
- Create: `~/.local/share/mcp-servers/camoufox-mcp/tests/test_tools.py`

The tool functions in `tools.py` will accept a `page` argument (a Playwright `Page` object). Tests mock this object so no real browser is needed.

- [ ] **Step 1: Create test file**

Write `~/.local/share/mcp-servers/camoufox-mcp/tests/test_tools.py`:

```python
from unittest.mock import MagicMock, patch, call
import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


def make_page():
    """Return a mock Playwright Page with sensible defaults."""
    page = MagicMock()
    page.title.return_value = "Test Page"
    page.inner_text.return_value = "Hello world"
    page.is_closed.return_value = False
    return page


def test_navigate_calls_goto_and_returns_title():
    from tools import navigate
    page = make_page()
    result = navigate(page, "https://example.com")
    page.goto.assert_called_once_with("https://example.com", wait_until="networkidle")
    assert "Test Page" in result


def test_snapshot_returns_body_text():
    from tools import snapshot
    page = make_page()
    result = snapshot(page)
    page.inner_text.assert_called_once_with("body")
    assert result == "Hello world"


def test_screenshot_returns_base64_string():
    from tools import screenshot
    page = make_page()
    page.screenshot.return_value = b"\x89PNG\r\n"
    result = screenshot(page)
    assert isinstance(result, str)
    assert len(result) > 0


def test_click_calls_page_click():
    from tools import click
    page = make_page()
    result = click(page, "button.download")
    page.click.assert_called_once_with("button.download")
    assert "button.download" in result


def test_type_text_fills_input():
    from tools import type_text
    page = make_page()
    result = type_text(page, "#search", "hello")
    page.fill.assert_called_once_with("#search", "hello")
    assert "#search" in result


def test_download_saves_file(tmp_path):
    from tools import download
    page = make_page()
    mock_dl = MagicMock()
    page.expect_download.return_value.__enter__ = MagicMock(return_value=MagicMock())
    page.expect_download.return_value.__exit__ = MagicMock(return_value=False)
    page.expect_download.return_value.__enter__.return_value.value = mock_dl
    save_path = str(tmp_path / "file.docx")
    result = download(page, "https://example.com/file.docx", save_path)
    mock_dl.save_as.assert_called_once_with(save_path)
    assert save_path in result
```

- [ ] **Step 2: Run tests — verify they fail with ImportError**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && /home/zo/.local/bin/uv run pytest tests/test_tools.py -v
```
Expected: all tests fail with `ModuleNotFoundError: No module named 'tools'` — that's correct, `tools.py` doesn't exist yet.

---

## Task 4: Implement tools.py

**Files:**
- Create: `~/.local/share/mcp-servers/camoufox-mcp/tools.py`

- [ ] **Step 1: Write tools.py**

Write `~/.local/share/mcp-servers/camoufox-mcp/tools.py`:

```python
from __future__ import annotations
import base64
from playwright.sync_api import Page


def navigate(page: Page, url: str) -> str:
    """Navigate to a URL and return the page title."""
    page.goto(url, wait_until="networkidle")
    return f"Navigated to '{page.title()}' at {url}"


def snapshot(page: Page) -> str:
    """Return the page body text (low token usage)."""
    return page.inner_text("body")


def screenshot(page: Page) -> str:
    """Capture a full-page screenshot and return as base64-encoded PNG."""
    data = page.screenshot(full_page=True)
    return base64.b64encode(data).decode()


def click(page: Page, selector: str) -> str:
    """Click an element by CSS selector."""
    page.click(selector)
    return f"Clicked '{selector}'"


def type_text(page: Page, selector: str, text: str) -> str:
    """Type text into an input element by CSS selector."""
    page.fill(selector, text)
    return f"Typed into '{selector}'"


def download(page: Page, url: str, save_path: str) -> str:
    """Navigate to a URL that triggers a download and save it to save_path."""
    with page.expect_download() as dl_info:
        page.goto(url)
    dl_info.value.save_as(save_path)
    return f"Downloaded to {save_path}"
```

- [ ] **Step 2: Run tests — verify they all pass**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && /home/zo/.local/bin/uv run pytest tests/test_tools.py -v
```
Expected: 6 tests PASS.

- [ ] **Step 3: Commit**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && git init && git add pyproject.toml tools.py tests/test_tools.py && git commit -m "feat: camoufox-mcp tools with passing tests"
```

> `~/.local/share/mcp-servers/camoufox-mcp` is its own small git repo — independent of the University repo.

---

## Task 5: Implement browser.py

**Files:**
- Create: `~/.local/share/mcp-servers/camoufox-mcp/browser.py`

No unit tests here — session management is integration-only (requires a real browser). Verified in Task 7.

- [ ] **Step 1: Write browser.py**

Write `~/.local/share/mcp-servers/camoufox-mcp/browser.py`:

```python
from __future__ import annotations
from camoufox.sync_api import Camoufox
from playwright.sync_api import Page

_camoufox: Camoufox | None = None
_page: Page | None = None


def get_page() -> Page:
    """Return the active page, starting a new Camoufox session if needed."""
    global _camoufox, _page
    if _camoufox is None:
        _camoufox = Camoufox(headless=True)
        _camoufox.__enter__()
    if _page is None or _page.is_closed():
        _page = _camoufox.new_page()
    return _page


def shutdown() -> None:
    """Close the browser session cleanly."""
    global _camoufox, _page
    if _page and not _page.is_closed():
        _page.close()
        _page = None
    if _camoufox is not None:
        _camoufox.__exit__(None, None, None)
        _camoufox = None
```

- [ ] **Step 2: Commit**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && git add browser.py && git commit -m "feat: camoufox browser session manager"
```

---

## Task 6: Implement main.py and fetch Firefox binary

**Files:**
- Create: `~/.local/share/mcp-servers/camoufox-mcp/main.py`

- [ ] **Step 1: Fetch the Camoufox Firefox binary (one-time setup)**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && /home/zo/.local/bin/uv run python -m camoufox fetch
```
Expected: downloads the Firefox binary (~100MB). Takes a minute. Prints progress then exits cleanly.

- [ ] **Step 2: Write main.py**

Write `~/.local/share/mcp-servers/camoufox-mcp/main.py`:

```python
import atexit
from mcp.server.fastmcp import FastMCP
import browser
import tools

mcp = FastMCP("camoufox")


@mcp.tool()
def navigate(url: str) -> str:
    """Navigate to a URL. Returns the page title. Use this first before any other tool."""
    return tools.navigate(browser.get_page(), url)


@mcp.tool()
def snapshot() -> str:
    """Return the current page body text. Low token usage. Use after navigate."""
    return tools.snapshot(browser.get_page())


@mcp.tool()
def screenshot() -> str:
    """Capture a full-page screenshot. Returns base64-encoded PNG. Use when you need to see the visual layout."""
    return tools.screenshot(browser.get_page())


@mcp.tool()
def click(selector: str) -> str:
    """Click an element by CSS selector (e.g. 'button.download', '#submit', 'a[href*=docx]')."""
    return tools.click(browser.get_page(), selector)


@mcp.tool()
def type_text(selector: str, text: str) -> str:
    """Type text into an input field by CSS selector."""
    return tools.type_text(browser.get_page(), selector, text)


@mcp.tool()
def download(url: str, save_path: str) -> str:
    """Navigate to a download URL and save the file to save_path (absolute path)."""
    return tools.download(browser.get_page(), url, save_path)


atexit.register(browser.shutdown)

if __name__ == "__main__":
    mcp.run()
```

- [ ] **Step 3: Verify server starts cleanly**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && timeout 5 /home/zo/.local/bin/uv run python main.py 2>&1 || true
```
Expected: server starts (may print MCP startup info) and exits after 5 seconds without a crash/traceback.

- [ ] **Step 4: Commit**

```bash
cd ~/.local/share/mcp-servers/camoufox-mcp && git add main.py && git commit -m "feat: camoufox MCP server entrypoint"
```

---

## Task 7: Register camoufox in settings.json and restart

**Files:**
- Modify: `~/.claude/settings.json`

- [ ] **Step 1: Add camoufox to mcpServers**

Edit `~/.claude/settings.json` — update the `mcpServers` block to:

```json
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
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -m json.tool ~/.claude/settings.json
```
Expected: prints formatted JSON with no errors.

- [ ] **Step 3: Commit**

```bash
git -C ~ add .claude/settings.json
git -C ~ commit -m "feat: register camoufox MCP server"
```

- [ ] **Step 4: Restart Claude Code**

Close and reopen the Claude Code session. Run `/mcp` to verify both servers appear as connected.

Expected output includes:
```
playwright  ✓ Connected
camoufox    ✓ Connected
```

If either shows as disconnected, check the startup logs in the MCP panel.

---

## Task 8: Download FA583 coursework from gofile.io

> **Prerequisite:** Both MCP servers are connected (Task 7 complete).

- [ ] **Step 1: List existing coursework files**

```bash
ls -la /home/zo/University/FA583/coursework/
```
Expected (from spec): `RELX_Report_FA583.docx`, `RELX_Financial_Analysis_FA583.xlsx`, `build_docx.py`, `build_xlsx.py`

- [ ] **Step 2: Ask user about existing files before deleting**

Show the user the file listing and ask:
> "I found these files in `FA583/coursework/`: [list]. The new download will likely replace `RELX_Report_FA583.docx`. Which files should I delete before placing the new one? (Note: `build_docx.py` and `build_xlsx.py` are build scripts — worth keeping unless you say otherwise.)"

Wait for confirmation before proceeding.

- [ ] **Step 3: Navigate to gofile.io using Playwright MCP**

Use the `playwright` MCP `browser_navigate` tool:
```
URL: https://gofile.io/d/Dl0SyY
```

If the page shows an error, expiry notice, or no download button — stop and report back to the user.

- [ ] **Step 4: Snapshot the page to find the download button**

Use `browser_snapshot` to get the accessibility tree. Identify the selector or link for the `.docx` download.

- [ ] **Step 5: Download the file**

Use `browser_click` on the download button, or `browser_navigate` directly to the download URL if visible in the snapshot. Save the file to:
```
/home/zo/University/FA583/coursework/
```
Rename it to match the existing naming convention: `RELX_Report_FA583.docx` (or keep original name if different — confirm with user).

- [ ] **Step 6: Verify the file landed correctly**

```bash
ls -lh /home/zo/University/FA583/coursework/
```
Expected: new `.docx` file present, sensible file size (>10KB).

- [ ] **Step 7: Commit the new file**

```bash
git -C /home/zo/University add FA583/coursework/
git -C /home/zo/University commit -m "feat: add latest FA583 coursework submission"
```
