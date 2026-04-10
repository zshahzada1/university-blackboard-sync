import json
import subprocess
import time
from pathlib import Path
from urllib.parse import urlparse
from config import BB_BASE_URL, COOKIE_CACHE

# --- browser_cookie3 fallback (legacy, broken on Edge 127+ due to App-Bound Encryption) ---
_WINDOWS_SCRIPT_LINES = [
    "import browser_cookie3, json, sys",
    "domain = sys.argv[1]",
    "cj = browser_cookie3.edge(domain_name=domain)",
    "print(json.dumps({c.name: c.value for c in cj}))",
]
_WINDOWS_SCRIPT = "; ".join(_WINDOWS_SCRIPT_LINES)

_WINDOWS_MANUAL_EXPORT = "C:\\cookies_bb.json"
_WINDOWS_MANUAL_EXPORT_WSL = "/mnt/c/cookies_bb.json"

# --- CDP cookie extraction ---
# Edge binds --remote-debugging-port to 127.0.0.1 (Windows loopback) which is not
# reachable from WSL2. The CDP client therefore runs on Windows Python, same as
# browser_cookie3, so it can connect to localhost:9222 directly.
# Requires: pip install websocket-client  (in Windows Python)
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

# Written to Windows Temp (accessible from WSL via /mnt/c/...) before each CDP run
_CDP_SCRIPT_WIN = r"C:\Windows\Temp\bb_cdp_extract.py"
_CDP_SCRIPT_WSL = "/mnt/c/Windows/Temp/bb_cdp_extract.py"

# PowerShell command template — {domain} is substituted at call time via .replace().
# Uses .format(script=...) at module load, leaving {domain} as a literal placeholder.
#
# Launch strategy: Start-Job (NOT Start-Process) to bypass Edge's singleton detection.
# Start-Process causes Edge to signal the existing singleton and exit without binding
# the debug port. Start-Job runs Edge in a background job session, which avoids the
# singleton check and makes Edge reliably bind --remote-debugging-port=9222.
#
# Steps: kill existing Edge → launch via Start-Job → try: run CDP script
#        finally: stop job + kill all msedge.
_CDP_PS_CMD = (
    'Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue; '
    'Start-Sleep -Milliseconds 800; '
    '$ed = if (Test-Path "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe") '
    '{{ "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" }} '
    'else {{ "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe" }}; '
    '$ud = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data"; '
    '$job = Start-Job -ArgumentList $ed, $ud {{ '
    '  param($e, $d); '
    '  & $e "--remote-debugging-port=9222" "--remote-allow-origins=*" "--user-data-dir=$d" "--no-first-run" "--no-default-browser-check" "about:blank" '
    '}}; '
    'try {{ '
    # Poll for CDP readiness in PowerShell before invoking Python.
    # Edge can take 8-12s to start in a Start-Job context — poll up to 20s (40×0.5s).
    # Use curl.exe (ships with Windows 10+) — more reliable than Invoke-WebRequest
    # in non-interactive PowerShell sessions (avoids proxy/TLS policy issues).
    '  $ok = $false; '
    '  for ($i = 0; $i -lt 40; $i++) {{ '
    '    $r = curl.exe -s -o NUL -w "%{{http_code}}" --max-time 1 http://localhost:9222/json/version 2>$null; '
    '    if ($r -eq "200") {{ $ok = $true; break }}; '
    '    Start-Sleep -Milliseconds 500 '
    '  }}; '
    '  if (-not $ok) {{ throw "CDP not ready within 20s" }}; '
    '  $py = $null; '
    '  foreach ($c in @("py", "python")) {{ '
    '    try {{ & $c --version 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) {{ $py = $c; break }} }} '
    '    catch {{}} '
    '  }}; '
    '  if (-not $py) {{ throw "No Python found in Windows PATH" }}; '
    '  & $py "{script}" {{domain}} '
    '}} finally {{ '
    '  Stop-Job $job -ErrorAction SilentlyContinue; '
    '  Remove-Job $job -ErrorAction SilentlyContinue; '
    '  Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue '
    '}}'
).format(script=_CDP_SCRIPT_WIN)


def _find_powershell() -> str:
    """Return the path to powershell.exe."""
    candidates = [
        "powershell.exe",
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
    ]
    return next(
        (p for p in candidates if Path(p).exists() or p == "powershell.exe"),
        "powershell.exe",
    )


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
        timeout=90,  # Edge start (~8s) + CDP poll (20s) + extraction
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
        try:
            raw = json.loads(manual.read_text())
            if isinstance(raw, list):
                cookies = {c["name"]: c["value"] for c in raw if "name" in c and "value" in c}
            else:
                cookies = raw
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_text(json.dumps(cookies))
            return cookies
        except (json.JSONDecodeError, OSError, KeyError) as e:
            print(f"    [cookie-editor] Skipping malformed export file: {e}")
            # fall through to browser_cookie3

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
            f"Workaround: export cookies manually with Cookie-Editor and save to "
            f"{_WINDOWS_MANUAL_EXPORT}"
        )

    cookies = json.loads(result.stdout.strip())
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(cookies))
    return cookies
