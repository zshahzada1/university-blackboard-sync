# CDP Cookie Extraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `browser_cookie3` cookie extraction with a Chrome DevTools Protocol (CDP) approach that launches Edge with a debug port, queries cookies via WebSocket, and requires a sudo password confirmation before proceeding.

**Architecture:** `cookie_extractor.py` gains a new `_extract_via_cdp()` function that (1) prompts for sudo password as a security gate, (2) launches Edge headlessly via PowerShell using the user's real profile + `--remote-debugging-port=9222`, (3) connects from WSL over `localhost:9222`, (4) sends `Network.getAllCookies` via WebSocket and filters to the BB domain, then (5) kills the Edge process. `extract_bb_cookies()` tries CDP first and falls back to the existing manual-export → browser_cookie3 chain on failure.

**Tech Stack:** Python 3, `requests` (already installed), `websocket-client` (new), `subprocess` for PowerShell/sudo, `unittest.mock` for tests.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `scripts/bb_sync/requirements.txt` | Add `websocket-client` |
| Modify | `scripts/bb_sync/cookie_extractor.py` | Add `_find_powershell`, `_require_sudo_auth`, `_kill_edge_pid`, `_extract_via_cdp`; update `extract_bb_cookies` |
| Modify | `scripts/bb_sync/test_cookie_extractor.py` | Add CDP tests; update existing tests to patch `_extract_via_cdp` so browser_cookie3 fallback still tested |

---

## Task 1: Add `websocket-client` to requirements and install it

**Files:**
- Modify: `scripts/bb_sync/requirements.txt`

- [ ] **Step 1: Add the dependency**

Edit `scripts/bb_sync/requirements.txt` to read:

```
requests
websocket-client
pytest
```

- [ ] **Step 2: Install it in WSL Python**

```bash
pip install websocket-client
```

Expected: `Successfully installed websocket-client-X.Y.Z` (or "already satisfied")

- [ ] **Step 3: Verify it imports**

```bash
python3 -c "import websocket; print('OK')"
```

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
cd ~/University && git add scripts/bb_sync/requirements.txt
git commit -m "chore: add websocket-client dependency for CDP cookie extraction"
```

---

## Task 2: Add `_require_sudo_auth`, `_kill_edge_pid`, and `_extract_via_cdp` to `cookie_extractor.py`

**Files:**
- Modify: `scripts/bb_sync/cookie_extractor.py`
- Test: `scripts/bb_sync/test_cookie_extractor.py`

- [ ] **Step 1: Write the failing tests**

Add the following to `scripts/bb_sync/test_cookie_extractor.py` — insert after the existing `TestCookieExtractor` class:

```python
import sys
sys.path.insert(0, '.')

# (add these imports at the top of the file alongside existing imports)
# import json  ← already there
# from unittest.mock import patch, MagicMock  ← already there


class TestExtractViaCdp(unittest.TestCase):
    """Tests for the CDP-based cookie extraction path."""

    def _make_mock_get(self):
        """Return a side_effect function for requests.get that handles CDP URLs."""
        def side_effect(url, **kwargs):
            if "version" in url:
                m = MagicMock()
                m.status_code = 200
                return m
            if url.endswith("/json"):
                m = MagicMock()
                m.json.return_value = [
                    {
                        "type": "page",
                        "webSocketDebuggerUrl": "ws://localhost:9222/devtools/page/1",
                    }
                ]
                return m
            raise ValueError(f"Unexpected URL in mock: {url}")

        return side_effect

    def _make_mock_run(self, edge_pid="9999"):
        """Return a side_effect function for subprocess.run that handles all expected calls."""
        def side_effect(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "sudo" in cmd_str:
                return MagicMock(returncode=0)
            if "powershell" in cmd_str.lower() or "Stop-Process" in cmd_str:
                return MagicMock(returncode=0, stdout=f"{edge_pid}\n", stderr="")
            return MagicMock(returncode=0, stdout="", stderr="")

        return side_effect

    def test_cdp_returns_bb_cookies_only(self):
        """_extract_via_cdp returns cookies filtered to the BB domain."""
        all_cookies_payload = json.dumps({
            "result": {
                "cookies": [
                    {"name": "BbRouter", "value": "tok123", "domain": "studentcentral.brighton.ac.uk"},
                    {"name": "JSESSIONID", "value": "sid456", "domain": "studentcentral.brighton.ac.uk"},
                    {"name": "unrelated", "value": "xyz", "domain": "google.com"},
                ]
            }
        })
        mock_ws = MagicMock()
        mock_ws.recv.return_value = all_cookies_payload

        with patch("cookie_extractor.subprocess.run", side_effect=self._make_mock_run()), \
             patch("cookie_extractor.requests.get", side_effect=self._make_mock_get()), \
             patch("cookie_extractor.websocket.WebSocket", return_value=mock_ws):
            from cookie_extractor import _extract_via_cdp
            result = _extract_via_cdp("studentcentral.brighton.ac.uk")

        self.assertEqual(result["BbRouter"], "tok123")
        self.assertEqual(result["JSESSIONID"], "sid456")
        self.assertNotIn("unrelated", result)

    def test_cdp_sudo_failure_raises(self):
        """_extract_via_cdp raises RuntimeError when sudo auth fails."""
        def sudo_fails(cmd, **kwargs):
            if "sudo" in " ".join(str(c) for c in cmd):
                return MagicMock(returncode=1)
            return MagicMock(returncode=0)

        with patch("cookie_extractor.subprocess.run", side_effect=sudo_fails):
            from cookie_extractor import _extract_via_cdp
            with self.assertRaises(RuntimeError) as ctx:
                _extract_via_cdp("studentcentral.brighton.ac.uk")
        self.assertIn("sudo", str(ctx.exception).lower())

    def test_cdp_kills_edge_on_ws_error(self):
        """_extract_via_cdp kills Edge even when WebSocket raises."""
        mock_ws = MagicMock()
        mock_ws.connect.side_effect = OSError("connection refused")

        kill_calls = []

        def run_side_effect(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "Stop-Process" in cmd_str:
                kill_calls.append(cmd_str)
            if "Start-Process" in cmd_str:
                return MagicMock(returncode=0, stdout="8888\n", stderr="")
            return MagicMock(returncode=0, stdout="", stderr="")

        with patch("cookie_extractor.subprocess.run", side_effect=run_side_effect), \
             patch("cookie_extractor.requests.get", side_effect=self._make_mock_get()), \
             patch("cookie_extractor.websocket.WebSocket", return_value=mock_ws):
            from cookie_extractor import _extract_via_cdp
            with self.assertRaises(Exception):
                _extract_via_cdp("studentcentral.brighton.ac.uk")

        # Edge must be killed even on error
        self.assertTrue(any("8888" in c for c in kill_calls), "Edge PID not killed on error")
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py::TestExtractViaCdp -v
```

Expected: `FAILED` — `ImportError` or `AttributeError` because `_extract_via_cdp` doesn't exist yet.

- [ ] **Step 3: Add helper functions and `_extract_via_cdp` to `cookie_extractor.py`**

Add `import requests` at the top (after existing imports). Then add the following functions **before** `extract_bb_cookies`:

```python
import requests


def _find_powershell() -> str:
    """Return the path to powershell.exe, preferring the bare name (works when Windows paths are in $PATH)."""
    candidates = [
        "powershell.exe",
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
    ]
    return next(
        (p for p in candidates if Path(p).exists() or p == "powershell.exe"),
        "powershell.exe",
    )


def _require_sudo_auth() -> None:
    """Prompt for WSL sudo password as a security gate before cookie extraction."""
    subprocess.run(["sudo", "-k"])  # invalidate cached sudo timestamp (ignore errors)
    result = subprocess.run(["sudo", "-v"])  # always prompts for password
    if result.returncode != 0:
        raise RuntimeError("sudo authentication failed — cookie extraction aborted")


def _kill_edge_pid(powershell: str, pid: str) -> None:
    """Kill a Windows process by PID via PowerShell, silently."""
    if pid and pid.strip():
        subprocess.run(
            [powershell, "-Command", f"Stop-Process -Id {pid.strip()} -Force -ErrorAction SilentlyContinue"],
            capture_output=True,
            timeout=5,
        )


def _extract_via_cdp(domain: str) -> dict:
    """
    Extract cookies via Chrome DevTools Protocol (bypasses App-Bound Encryption).

    Flow:
    1. Prompt for sudo password (security gate).
    2. Launch Edge headlessly with the user's real profile + remote debug port 9222.
    3. Poll localhost:9222 until CDP is ready (up to 10 s).
    4. Send Network.getAllCookies via WebSocket, filter to `domain`.
    5. Kill Edge, return {name: value} dict.

    Raises RuntimeError on any failure; Edge is always cleaned up.
    """
    try:
        import websocket
    except ImportError:
        raise RuntimeError(
            "websocket-client not installed. Run: pip install websocket-client"
        )

    _require_sudo_auth()

    powershell = _find_powershell()

    # Launch Edge headlessly using the user's real profile so stored cookies are accessible.
    # Start-Process -PassThru returns the Process object; we print its Id to capture the PID.
    launch_cmd = (
        '$d = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data"; '
        '$p = Start-Process -FilePath msedge.exe '
        '-ArgumentList '
        '"--headless=new","--remote-debugging-port=9222",'
        '"--user-data-dir=$d","--no-first-run","--no-default-browser-check" '
        '-PassThru; Write-Output $p.Id'
    )
    launch_result = subprocess.run(
        [powershell, "-Command", launch_cmd],
        capture_output=True,
        text=True,
        timeout=15,
    )
    if launch_result.returncode != 0:
        raise RuntimeError(
            f"Failed to launch Edge for CDP: {launch_result.stderr.strip()}"
        )

    edge_pid = launch_result.stdout.strip()

    try:
        # Poll until the CDP endpoint is ready (up to 10 seconds)
        cdp_base = "http://localhost:9222"
        for _ in range(20):
            try:
                resp = requests.get(f"{cdp_base}/json/version", timeout=1)
                if resp.status_code == 200:
                    break
            except requests.RequestException:
                pass
            time.sleep(0.5)
        else:
            raise RuntimeError(
                "Edge CDP port did not become available within 10 seconds. "
                "Try closing any open Edge windows first."
            )

        # Find a debuggable page target
        targets = requests.get(f"{cdp_base}/json", timeout=5).json()
        page_targets = [t for t in targets if t.get("type") == "page"]
        if page_targets:
            ws_url = page_targets[0]["webSocketDebuggerUrl"]
        else:
            new_tab = requests.get(f"{cdp_base}/json/new", timeout=5).json()
            ws_url = new_tab["webSocketDebuggerUrl"]

        # Query all cookies via the DevTools WebSocket
        ws = websocket.WebSocket()
        ws.connect(ws_url)
        ws.send(json.dumps({"id": 1, "method": "Network.getAllCookies"}))
        result = json.loads(ws.recv())
        ws.close()

        all_cookies = result["result"]["cookies"]
        return {
            c["name"]: c["value"]
            for c in all_cookies
            if domain in c.get("domain", "")
        }

    finally:
        _kill_edge_pid(powershell, edge_pid)
```

- [ ] **Step 4: Run new tests to confirm they pass**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py::TestExtractViaCdp -v
```

Expected: all 3 tests `PASSED`

- [ ] **Step 5: Run all tests to check for regressions**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest -v
```

The existing `TestCookieExtractor` tests may fail at this point — that is expected and will be fixed in Task 3. If tests other than `TestCookieExtractor` fail, investigate before continuing.

- [ ] **Step 6: Commit**

```bash
cd ~/University && git add scripts/bb_sync/cookie_extractor.py scripts/bb_sync/test_cookie_extractor.py
git commit -m "feat: add CDP cookie extraction with sudo auth gate"
```

---

## Task 3: Update `extract_bb_cookies()` to try CDP first; fix existing tests

**Files:**
- Modify: `scripts/bb_sync/cookie_extractor.py` (update `extract_bb_cookies` body)
- Modify: `scripts/bb_sync/test_cookie_extractor.py` (patch `_extract_via_cdp` in existing tests)

- [ ] **Step 1: Write the failing test for the new CDP-first flow**

Replace the body of `TestCookieExtractor` in `test_cookie_extractor.py` with the following (keep the class name):

```python
class TestCookieExtractor(unittest.TestCase):
    def test_returns_dict_via_cdp_when_available(self):
        """extract_bb_cookies returns cookies from CDP when it succeeds."""
        cdp_cookies = {"BbRouter": "abc123", "JSESSIONID": "xyz"}
        with patch("cookie_extractor._extract_via_cdp", return_value=cdp_cookies):
            result = extract_bb_cookies(force_refresh=True)
        self.assertIsInstance(result, dict)
        self.assertIn("BbRouter", result)
        self.assertEqual(result["BbRouter"], "abc123")

    def test_falls_back_to_browser_cookie3_when_cdp_fails(self):
        """extract_bb_cookies falls back to browser_cookie3 when CDP raises."""
        fake_cookies = json.dumps({"BbRouter": "abc123", "JSESSIONID": "xyz"})
        with patch("cookie_extractor._extract_via_cdp", side_effect=RuntimeError("CDP unavailable")), \
             patch("cookie_extractor.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout=fake_cookies, stderr="")
            result = extract_bb_cookies(force_refresh=True)
        self.assertIsInstance(result, dict)
        self.assertIn("BbRouter", result)

    def test_raises_when_all_methods_fail(self):
        """extract_bb_cookies raises RuntimeError when CDP and browser_cookie3 both fail."""
        with patch("cookie_extractor._extract_via_cdp", side_effect=RuntimeError("CDP unavailable")), \
             patch("cookie_extractor.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=1, stdout="", stderr="ModuleNotFoundError: No module named 'browser_cookie3'"
            )
            with self.assertRaises(RuntimeError):
                extract_bb_cookies(force_refresh=True)
```

- [ ] **Step 2: Run the new tests to confirm they fail**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py::TestCookieExtractor -v
```

Expected: `test_returns_dict_via_cdp_when_available` FAILS because `extract_bb_cookies` doesn't call `_extract_via_cdp` yet.

- [ ] **Step 3: Update `extract_bb_cookies()` in `cookie_extractor.py`**

Replace the entire `extract_bb_cookies` function with:

```python
def extract_bb_cookies(force_refresh: bool = False) -> dict:
    """
    Extract Edge session cookies for BB_BASE_URL.
    Tries methods in order: CDP (primary) → manual Cookie-Editor export → browser_cookie3.
    Caches result to COOKIE_CACHE for 1 hour. Returns dict of {name: value}.
    Raises RuntimeError if all methods fail.
    """
    cache = Path(COOKIE_CACHE)
    if not force_refresh and cache.exists():
        age = time.time() - cache.stat().st_mtime
        if age < 3600:
            try:
                return json.loads(cache.read_text())
            except (json.JSONDecodeError, OSError):
                pass  # fall through to re-extraction

    domain = urlparse(BB_BASE_URL).netloc  # studentcentral.brighton.ac.uk

    # --- Method 1: Chrome DevTools Protocol (bypasses App-Bound Encryption) ---
    try:
        print("    [cdp] Extracting cookies via Chrome DevTools Protocol…")
        cookies = _extract_via_cdp(domain)
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(cookies))
        return cookies
    except RuntimeError as e:
        print(f"    [cdp] CDP failed: {e}")
        print("    [cdp] Falling back to alternative methods…")

    # --- Method 2: Manually exported Cookie-Editor JSON ---
    manual = Path(_WINDOWS_MANUAL_EXPORT_WSL)
    if manual.exists():
        print(f"    [cookie-editor] Reading from {_WINDOWS_MANUAL_EXPORT_WSL}")
        raw = json.loads(manual.read_text())
        if isinstance(raw, list):
            cookies = {c["name"]: c["value"] for c in raw if "name" in c and "value" in c}
        else:
            cookies = raw
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(cookies))
        return cookies

    # --- Method 3: browser_cookie3 via Windows Python (legacy, broken on Edge 127+) ---
    powershell = _find_powershell()
    ps_command = f"python -c '{_WINDOWS_SCRIPT}' {domain}"
    result = subprocess.run(
        [powershell, "-Command", ps_command],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        ps_command_py = f"py -3 -c '{_WINDOWS_SCRIPT}' {domain}"
        result = subprocess.run(
            [powershell, "-Command", ps_command_py],
            capture_output=True, text=True, timeout=30,
        )

    if result.returncode != 0:
        raise RuntimeError(
            f"Cookie extraction failed. All methods exhausted.\n"
            f"CDP failed (see above). browser_cookie3 error: {result.stderr.strip()}\n"
            f"Workaround: export cookies manually with Cookie-Editor and save to {_WINDOWS_MANUAL_EXPORT}"
        )

    cookies = json.loads(result.stdout.strip())
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(cookies))
    return cookies
```

Also remove the duplicated `_find_powershell` inline logic that was previously inside `extract_bb_cookies` (it's now a standalone function added in Task 2).

- [ ] **Step 4: Run updated tests to confirm they pass**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py -v
```

Expected: all 5 tests in `test_cookie_extractor.py` PASSED.

- [ ] **Step 5: Run all tests**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest -v
```

Expected: all tests PASSED.

- [ ] **Step 6: Smoke-test the actual CDP extraction**

```bash
cd ~/University/scripts/bb_sync && python3 . --list-courses 2>&1
```

Expected output (in order):
1. `[cdp] Extracting cookies via Chrome DevTools Protocol…`
2. A `sudo` password prompt in the terminal
3. After password entered: Edge launches, cookies extracted, JSON printed to stdout

If Edge is already open with the same profile, the launch may fail. Close Edge first if so.

- [ ] **Step 7: Commit**

```bash
cd ~/University && git add scripts/bb_sync/cookie_extractor.py scripts/bb_sync/test_cookie_extractor.py
git commit -m "feat: use CDP as primary cookie extraction method, fall back to browser_cookie3"
```

---

## Self-Review

### Spec coverage

| Requirement | Covered by |
|-------------|-----------|
| Replace broken `browser_cookie3` with CDP | Task 2: `_extract_via_cdp` |
| Sudo password gate before extraction | Task 2: `_require_sudo_auth` (`sudo -k && sudo -v`) |
| Launch Edge with real profile + debug port | Task 2: PowerShell `Start-Process` with `$env:LOCALAPPDATA` path |
| Filter cookies to BB domain | Task 2: `if domain in c.get("domain", "")` |
| Kill Edge after extraction (even on error) | Task 2: `try/finally _kill_edge_pid` |
| CDP as primary, fallback chain preserved | Task 3: CDP → manual export → browser_cookie3 |
| Existing tests updated | Task 3: `TestCookieExtractor` patched to mock `_extract_via_cdp` |

### Placeholder scan

No TBDs, TODOs, or vague instructions present.

### Type consistency

- `_find_powershell() -> str` defined in Task 2, used in Task 2 (`_extract_via_cdp`) and Task 3 (`extract_bb_cookies`)
- `_kill_edge_pid(powershell: str, pid: str)` defined in Task 2, called in Task 2's `finally` block
- `_extract_via_cdp(domain: str) -> dict` defined in Task 2, called in Task 3
- `domain` is `str` everywhere — consistent

---
