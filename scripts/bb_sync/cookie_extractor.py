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

    Edge binds the debug port to 127.0.0.1 (Windows loopback), so the CDP client
    runs on Windows Python via PowerShell — same pattern as the browser_cookie3 script.
    PowerShell launches Edge, runs the CDP script, then kills Edge in a finally block.

    Flow:
    1. Write CDP client script to C:\\Windows\\Temp\\bb_cdp_extract.py.
    2. PowerShell: launch Edge hidden with real user profile + port 9222,
       run Windows Python CDP script, kill Edge in finally.
    3. Parse JSON output → {name: value} cookie dict.

    Raises RuntimeError on any failure.
    """
    Path(_CDP_SCRIPT_WSL).write_text(_CDP_WIN_SCRIPT)

    powershell = _find_powershell()

    # Launch Edge and run the CDP script in a single PowerShell command.
    # PowerShell's try/finally ensures Edge is killed even if the script fails.
    ps_cmd = (
        '$e = if (Test-Path "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe") '
        '{ "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" } '
        'else { "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe" }; '
        '$d = "$env:LOCALAPPDATA\\Microsoft\\Edge\\User Data"; '
        '$p = Start-Process -FilePath $e '
        '-ArgumentList "--remote-debugging-port=9222","--user-data-dir=$d",'
        '"--no-first-run","--no-default-browser-check" '
        f'-WindowStyle Hidden -PassThru; '
        f'try {{ python "{_CDP_SCRIPT_WIN}" {domain} }} '
        f'finally {{ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }}'
    )

    result = subprocess.run(
        [powershell, "-Command", ps_cmd],
        capture_output=True,
        text=True,
        timeout=45,  # Edge start + CDP poll (10 s) + extraction
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
