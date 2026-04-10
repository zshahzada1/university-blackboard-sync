# Fix Edge Cookie Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `cookie_extractor.py` so CDP-based Edge cookie extraction reliably works from WSL2, and update the skill documentation to match the actual implementation.

**Architecture:** Three bugs cause extraction to always fail: (1) an erroneous `sudo` gate that has no business being there, (2) the PowerShell command that starts a new Edge instance with the user's real profile without first checking if Edge is already running (causing the new instance to immediately signal the existing one and exit), and (3) `python` not being in the Windows PATH. Fix all three in `cookie_extractor.py`, update tests, then update `SKILL.md` to match.

**Tech Stack:** Python 3, PowerShell (Windows, called via `subprocess` from WSL2), Edge DevTools Protocol, `websocket-client` + `requests` (Windows Python), `pytest` (unit tests)

---

## Root-Cause Analysis

| Bug | Location | Effect |
|-----|----------|--------|
| `_require_sudo_auth()` called before CDP | `cookie_extractor.py:96` | Prompts for WSL sudo password — pointless, can block automation |
| Edge already running → new instance signals existing → exits | PS command in `_extract_via_cdp` | `$p` captures a process that exits in milliseconds; CDP never becomes ready |
| `python` not guaranteed in Windows PATH | PS command `python "{script}" {domain}` | `FileNotFoundError` or silent failure |
| SKILL.md still describes `browser_cookie3`/DPAPI as primary method | `~/.claude/skills/blackboard-sync/SKILL.md` | Misleading troubleshooting guidance |

---

## File Structure

**Modified:**
- `~/University/scripts/bb_sync/cookie_extractor.py` — remove sudo gate, fix PS command to kill existing Edge before launching debug instance, fix Python discovery
- `~/University/scripts/bb_sync/test_cookie_extractor.py` — remove sudo test, add test for Edge-kill-before-launch path
- `~/.claude/skills/blackboard-sync/SKILL.md` — update "How Cookie Extraction Works" and troubleshooting table to reflect CDP reality

---

## Task 1: Remove the erroneous sudo gate

**Files:**
- Modify: `~/University/scripts/bb_sync/cookie_extractor.py:66-76` (delete `_require_sudo_auth` function)
- Modify: `~/University/scripts/bb_sync/cookie_extractor.py:96` (remove call site)
- Modify: `~/University/scripts/bb_sync/test_cookie_extractor.py` (remove `test_cdp_sudo_failure_raises`)

- [ ] **Step 1: Write the replacement test that asserts sudo is NOT called**

In `test_cookie_extractor.py`, replace `test_cdp_sudo_failure_raises` with a test asserting subprocess is only called once (the PowerShell call, not a sudo call):

```python
def test_cdp_does_not_call_sudo(self):
    """_extract_via_cdp must NOT call sudo — it runs on Windows, sudo is irrelevant."""
    cdp_output = json.dumps({"BbRouter": "tok123"})

    from cookie_extractor import _extract_via_cdp
    with patch("cookie_extractor.subprocess.run",
               side_effect=self._make_mock_run(ps_output=cdp_output)) as mock_run, \
         patch("pathlib.Path.write_text"):
        _extract_via_cdp("studentcentral.brighton.ac.uk")

    for call in mock_run.call_args_list:
        cmd = call[0][0]  # first positional arg is the command list
        self.assertNotIn("sudo", " ".join(str(c) for c in cmd),
                         "sudo must never be called from _extract_via_cdp")
```

- [ ] **Step 2: Run test to verify it fails** (sudo IS currently being called)

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py::TestExtractViaCdp::test_cdp_does_not_call_sudo -v
```

Expected: FAIL — the test catches the two `subprocess.run(["sudo", ...])` calls that currently happen.

- [ ] **Step 3: Delete `_require_sudo_auth` and its call site**

In `cookie_extractor.py`, remove lines 66–76 (the entire `_require_sudo_auth` function):

```python
# DELETE this entire function:
def _require_sudo_auth() -> None:
    """..."""
    subprocess.run(["sudo", "-k"])
    result = subprocess.run(["sudo", "-v"])
    if result.returncode != 0:
        raise RuntimeError("sudo authentication failed — cookie extraction aborted")
```

Also remove the call on line 96:

```python
# DELETE this line inside _extract_via_cdp:
    _require_sudo_auth()
```

- [ ] **Step 4: Run all cookie tests to verify they pass**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py -v
```

Expected: all 7 tests PASS (the old `test_cdp_sudo_failure_raises` is gone, new `test_cdp_does_not_call_sudo` passes).

- [ ] **Step 5: Commit**

```bash
cd ~/University/scripts/bb_sync
git add cookie_extractor.py test_cookie_extractor.py
git commit -m "fix: remove erroneous sudo gate from CDP cookie extraction"
```

---

## Task 2: Fix the Edge-already-running problem in the PowerShell command

**Files:**
- Modify: `~/University/scripts/bb_sync/cookie_extractor.py` — replace `_CDP_WIN_SCRIPT` PS command and `_extract_via_cdp` PS launch logic
- Modify: `~/University/scripts/bb_sync/test_cookie_extractor.py` — add test for Edge-already-running path

**The problem in detail:**

If Edge is running without `--remote-debugging-port=9222`, the command:
```
Start-Process msedge.exe --user-data-dir="...\User Data" --remote-debugging-port=9222
```
signals the existing Edge singleton and exits immediately. `$p` holds a dead process. CDP never becomes ready.

**Fix:** The PS command must:
1. Check if port 9222 is already open (Edge running with debug port)
2. If not, kill all `msedge` processes first, then start fresh with debug port
3. Use `py -3` / `python` fallback chain for Windows Python discovery

- [ ] **Step 1: Write the failing test for Edge-already-running handling**

In `test_cookie_extractor.py`, add inside `TestExtractViaCdp`:

```python
def test_cdp_kills_edge_before_launching_with_debug_port(self):
    """When Edge is running without debug port, the PS command must kill it first.

    We verify by checking that the PowerShell command string contains
    'Stop-Process' (kill) before 'Start-Process' (launch).
    """
    cdp_output = json.dumps({"BbRouter": "tok123"})

    from cookie_extractor import _extract_via_cdp, _CDP_PS_CMD
    # _CDP_PS_CMD is the PowerShell command string constant
    kill_pos = _CDP_PS_CMD.find("Stop-Process")
    start_pos = _CDP_PS_CMD.find("Start-Process")
    self.assertGreater(kill_pos, -1, "PS command must contain Stop-Process to kill existing Edge")
    self.assertGreater(start_pos, -1, "PS command must contain Start-Process to launch Edge")
    # Kill before start
    self.assertLess(kill_pos, start_pos, "Stop-Process must appear before Start-Process")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py::TestExtractViaCdp::test_cdp_kills_edge_before_launching_with_debug_port -v
```

Expected: FAIL — `_CDP_PS_CMD` doesn't exist yet, and current PS command has no `Stop-Process` before `Start-Process`.

- [ ] **Step 3: Replace the PS command constant and extraction logic in `cookie_extractor.py`**

Replace the `_CDP_WIN_SCRIPT`, `_CDP_SCRIPT_WIN`, `_CDP_SCRIPT_WSL` section and `_extract_via_cdp` with the following.

First, update the module-level constants (replace everything from line 25 to line 51):

```python
# --- CDP cookie extraction ---
# Flow:
# 1. PowerShell kills any running msedge (profile lock prevention).
# 2. Launches Edge hidden with real profile + --remote-debugging-port=9222.
# 3. Windows Python CDP client connects, calls Network.getAllCookies, returns JSON.
# 4. PowerShell finally block kills Edge.
#
# The CDP client runs on Windows Python (not WSL) because Edge binds 9222 to
# 127.0.0.1 (Windows loopback) — unreachable from WSL2 network namespace.

_CDP_WIN_SCRIPT = "\n".join([
    "import time, json, sys, requests, websocket",
    "domain = sys.argv[1]",
    "base = 'http://localhost:9222'",
    "ready = False",
    "for _ in range(20):",
    "    try:",
    "        if requests.get(base+'/json/version', timeout=1).status_code == 200:",
    "            ready = True; break",
    "    except Exception: pass",
    "    time.sleep(0.5)",
    "if not ready: raise SystemExit('CDP not ready within 10s')",
    "targets = requests.get(base+'/json', timeout=5).json()",
    "pts = [t for t in targets if t.get('type') == 'page']",
    "ws_url = (pts[0]['webSocketDebuggerUrl'] if pts",
    "          else requests.get(base+'/json/new', timeout=5).json()['webSocketDebuggerUrl'])",
    "ws = websocket.WebSocket()",
    "ws.connect(ws_url, timeout=10); ws.settimeout(10)",
    "ws.send(json.dumps({'id': 1, 'method': 'Network.getAllCookies'}))",
    "r = json.loads(ws.recv()); ws.close()",
    "print(json.dumps({c['name']: c['value'] for c in r['result']['cookies']",
    "                  if domain in c.get('domain', '')}))",
])

# Written to Windows Temp before each CDP run
_CDP_SCRIPT_WIN = r"C:\Windows\Temp\bb_cdp_extract.py"
_CDP_SCRIPT_WSL = "/mnt/c/Windows/Temp/bb_cdp_extract.py"

# PowerShell command template — {domain} is substituted at call time.
# Steps:
#   1. Kill any running msedge (releases profile lock).
#   2. Find msedge.exe path.
#   3. Launch Edge hidden with real profile + debug port; capture process object.
#   4. Try/finally: run CDP script, always kill Edge afterward.
#   5. Python discovery: try `py -3` first (Python Launcher), then `python`.
_CDP_PS_CMD = (
    # 1. Kill existing Edge to release profile lock
    'Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue; '
    'Start-Sleep -Milliseconds 800; '
    # 2. Find Edge executable
    '$e = if (Test-Path "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe") '
    '{ "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" } '
    'else { "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe" }; '
    # 3. Launch Edge with real profile + debug port
    '$d = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data"; '
    '$p = Start-Process -FilePath $e '
    '-ArgumentList "--remote-debugging-port=9222","--user-data-dir=$d",'
    '"--no-first-run","--no-default-browser-check" '
    '-WindowStyle Hidden -PassThru; '
    # 4. Run CDP script, kill Edge in finally
    'try {{ '
    '  $py = $null; '
    '  foreach ($c in @("py", "python")) {{ '
    '    try {{ & $c --version 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) {{ $py = $c; break }} }} '
    '    catch {{}} '
    '  }}; '
    '  if (-not $py) {{ throw "No Python found in Windows PATH" }}; '
    '  & $py "{script}" {{domain}} '
    '}} finally {{ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }}'
).format(script=_CDP_SCRIPT_WIN)
```

Then replace `_extract_via_cdp` (remove the `_require_sudo_auth()` call and use `_CDP_PS_CMD`):

```python
def _extract_via_cdp(domain: str) -> dict:
    """
    Extract cookies via Chrome DevTools Protocol (bypasses App-Bound Encryption).

    Kills any running Edge processes first (releases profile lock), then launches
    Edge hidden with the real user profile and --remote-debugging-port=9222.
    A Windows Python CDP client connects and calls Network.getAllCookies.
    Edge is killed in a PowerShell finally block regardless of outcome.

    Raises RuntimeError on any failure.
    """
    Path(_CDP_SCRIPT_WSL).write_text(_CDP_WIN_SCRIPT)

    powershell = _find_powershell()
    ps_cmd = _CDP_PS_CMD.replace("{domain}", domain)

    result = subprocess.run(
        [powershell, "-Command", ps_cmd],
        capture_output=True,
        text=True,
        timeout=60,  # Edge kill + start + CDP poll (10 s) + extraction
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"CDP extraction failed.\n{result.stderr.strip()}"
        )

    output = result.stdout.strip()
    if not output:
        raise RuntimeError(
            "CDP script produced no output — Edge may have failed to start or cookies are empty"
        )

    try:
        return json.loads(output)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"CDP script returned unexpected output: {output!r}") from e
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_cookie_extractor.py -v
```

Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/University/scripts/bb_sync
git add cookie_extractor.py test_cookie_extractor.py
git commit -m "fix: kill existing Edge before CDP launch, fix Python discovery in PS command"
```

---

## Task 3: Update SKILL.md to match the actual CDP implementation

**Files:**
- Modify: `~/.claude/skills/blackboard-sync/SKILL.md` — replace "How Cookie Extraction Works" section and troubleshooting table

- [ ] **Step 1: Replace the "How Cookie Extraction Works" section**

In `~/.claude/skills/blackboard-sync/SKILL.md`, find and replace the section starting with `## How Cookie Extraction Works` through the end of the DPAPI paragraph:

**Old text (lines 110–117):**
```markdown
## How Cookie Extraction Works

`cookie_extractor.py` calls `powershell.exe` from WSL to invoke Windows Python with `browser_cookie3`, which decrypts Edge cookies using DPAPI (Windows-only). Cookies are cached to `~/.cache/bb_sync/cookies.json` for 1 hour.

**Requires:**
- WSL interop enabled (`interop.enabled = true` in `/etc/wsl.conf`)
- `browser_cookie3` installed in Windows Python: `pip install browser-cookie3` (run in Windows PowerShell)
- Edge signed in to `studentcentral.brighton.ac.uk`
```

**New text:**
```markdown
## How Cookie Extraction Works

`cookie_extractor.py` uses **Chrome DevTools Protocol (CDP)** to extract Edge cookies — this bypasses App-Bound Encryption (Edge 127+) which broke `browser_cookie3`.

**Flow:**
1. Writes a CDP client script to `C:\Windows\Temp\bb_cdp_extract.py`
2. Calls `powershell.exe` from WSL, which:
   - Kills any running `msedge` processes (releases profile lock)
   - Launches Edge hidden with the real user profile + `--remote-debugging-port=9222`
   - Runs the CDP client (Windows Python: `py` or `python`)
   - Kills Edge in a `finally` block
3. CDP client connects to `localhost:9222`, calls `Network.getAllCookies`, prints JSON
4. Cookies cached to `~/.cache/bb_sync/cookies.json` for 1 hour

**Requires:**
- WSL interop enabled (`interop.enabled = true` in `/etc/wsl.conf`)
- Windows Python with `requests` and `websocket-client`: `pip install requests websocket-client` (run in Windows PowerShell or `py -m pip install ...`)
- Edge signed in to `studentcentral.brighton.ac.uk` (cookies must exist in the profile)

**Note:** The script kills Edge before extracting cookies. Save any open Edge work before running.
```

- [ ] **Step 2: Replace the "Known Issue: DPAPI / Admin Error" section**

Find and replace the section starting with `## Known Issue: DPAPI / Admin Error` through the end of that section:

**Old text:**
```markdown
## Known Issue: DPAPI / Admin Error

`browser_cookie3` fails if:
1. **Running PowerShell as Admin** — DPAPI keys are per-user; admin context can't decrypt them. Run as **normal user**.
2. **Edge is open** — cookie DB is locked. Fix: **close Edge completely** (check Task Manager for background Edge processes) before running.

Correct flow:
1. Close Edge completely (all windows + background processes)
2. Open normal (non-admin) PowerShell
3. Run `python3 .` from WSL (or it'll be called automatically)
```

**New text:**
```markdown
## Cookie Extraction Notes

The CDP method kills Edge automatically before starting the debug session. You do not need to close Edge manually — but save any open browser work first, as all Edge windows will close.

If you need Edge to stay open during a sync, use Method 2 instead: export cookies with the [Cookie Editor](https://cookie-editor.com/) browser extension and save to `C:\cookies_bb.json` before running.
```

- [ ] **Step 3: Replace the Troubleshooting table**

Find the `## Troubleshooting` section and replace the table:

**Old table:**
```markdown
| Error | Fix |
|-------|-----|
| `FileNotFoundError: powershell.exe` | WSL interop disabled — edit `/etc/wsl.conf`, restart WSL |
| `RequiresAdminError` | Edge is open — close Edge completely first |
| `Failed to decrypt with DPAPI` | Running as admin — use normal user PowerShell |
| `BrowserCookieError: Unable to get key` | Both above issues combined |
| `401 Unauthorized` on API | Session expired — close Edge, reopen, log back in, then `--refresh-cookies` |
| `--list-courses` returns empty `[]` | No active enrolments returned; try `--refresh-cookies` |
| Course missing from `--list-courses` | Course may be inactive; check Blackboard availability |
| Course synced but wrong folder | Add to `COURSE_OVERRIDES` in `config.py` |
```

**New table:**
```markdown
| Error | Fix |
|-------|-----|
| `FileNotFoundError: powershell.exe` | WSL interop disabled — edit `/etc/wsl.conf`, restart WSL |
| `CDP not ready within 10s` | Edge failed to start — check msedge.exe path exists, or run `python3 . --refresh-cookies` to retry |
| `No Python found in Windows PATH` | Install Python from python.org (check "Add to PATH") or Microsoft Store, then retry |
| `ModuleNotFoundError: requests` or `websocket` | Run in Windows PowerShell: `py -m pip install requests websocket-client` |
| `CDP extraction failed` + PowerShell error | See full stderr — usually a PATH or Edge path issue |
| `401 Unauthorized` on API | Session expired — open Edge, log back into studentcentral.brighton.ac.uk, then `--refresh-cookies` |
| `--list-courses` returns empty `[]` | No active enrolments returned; try `--refresh-cookies` |
| Course missing from `--list-courses` | Course may be inactive; check Blackboard availability |
| Course synced but wrong folder | Add to `COURSE_OVERRIDES` in `config.py` |
```

- [ ] **Step 4: Verify the skill file looks correct**

```bash
cat ~/.claude/skills/blackboard-sync/SKILL.md | grep -A5 "How Cookie"
```

Expected: Shows the new CDP-based description.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude/skills/blackboard-sync
git add SKILL.md
git commit -m "docs: update cookie extraction docs to reflect CDP approach, fix troubleshooting table"
```

---

## Self-Review

**Spec coverage:**
- [x] Remove sudo gate → Task 1
- [x] Fix Edge-already-running (kill before launch) → Task 2  
- [x] Fix Python discovery (`py` before `python`) → Task 2
- [x] Update skill docs → Task 3
- [x] Tests updated throughout

**Placeholder scan:** No TBD or TODO left in plan — all steps have concrete code.

**Type consistency:** 
- `_CDP_PS_CMD` introduced in Task 2 and used in test in Task 2 (same name throughout)
- `_extract_via_cdp` signature unchanged — callers unaffected
- `_CDP_WIN_SCRIPT`, `_CDP_SCRIPT_WIN`, `_CDP_SCRIPT_WSL` unchanged names — only `_CDP_PS_CMD` added

**One edge case:** The `_CDP_PS_CMD` uses Python `.format(script=_CDP_SCRIPT_WIN)` at module load time, then `ps_cmd.replace("{domain}", domain)` at call time. The `{domain}` literal must survive the `.format()` call — so it must be written as `{{domain}}` in the template string (double braces = escaped brace in `.format()`). The Task 2 code already does this correctly.
