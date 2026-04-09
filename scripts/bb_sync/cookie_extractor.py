import json
import subprocess
import time
from pathlib import Path
from urllib.parse import urlparse
import requests
try:
    import websocket
except ImportError:
    websocket = None  # type: ignore[assignment]
from config import BB_BASE_URL, COOKIE_CACHE

# This script runs on the WINDOWS Python side via powershell.exe
# It extracts Edge cookies for the given domain using browser_cookie3
_WINDOWS_SCRIPT_LINES = [
    "import browser_cookie3, json, sys",
    "domain = sys.argv[1]",
    "cj = browser_cookie3.edge(domain_name=domain)",
    "print(json.dumps({c.name: c.value for c in cj}))",
]
_WINDOWS_SCRIPT = "; ".join(_WINDOWS_SCRIPT_LINES)


_WINDOWS_MANUAL_EXPORT = "C:\\cookies_bb.json"
_WINDOWS_MANUAL_EXPORT_WSL = "/mnt/c/cookies_bb.json"


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
    if websocket is None:
        raise RuntimeError(
            "websocket-client not installed. Run: pip install websocket-client"
        )

    _require_sudo_auth()

    powershell = _find_powershell()

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

        targets = requests.get(f"{cdp_base}/json", timeout=5).json()
        page_targets = [t for t in targets if t.get("type") == "page"]
        if page_targets:
            ws_url = page_targets[0]["webSocketDebuggerUrl"]
        else:
            new_tab = requests.get(f"{cdp_base}/json/new", timeout=5).json()
            ws_url = new_tab["webSocketDebuggerUrl"]

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


def extract_bb_cookies(force_refresh: bool = False) -> dict:
    """
    Extract Edge session cookies for BB_BASE_URL using Windows Python.
    Caches result to COOKIE_CACHE for 1 hour. Returns dict of {name: value}.
    Raises RuntimeError if extraction fails.
    """
    cache = Path(COOKIE_CACHE)
    if not force_refresh and cache.exists():
        age = time.time() - cache.stat().st_mtime
        if age < 3600:
            try:
                return json.loads(cache.read_text())
            except (json.JSONDecodeError, OSError):
                pass  # fall through to re-extraction

    # Check for manually exported cookie file (Cookie-Editor JSON export)
    manual = Path(_WINDOWS_MANUAL_EXPORT_WSL)
    if manual.exists():
        print(f"    [cookie-editor] Reading from {_WINDOWS_MANUAL_EXPORT_WSL}")
        raw = json.loads(manual.read_text())
        # Cookie-Editor exports a list of objects with "name"/"value" keys
        if isinstance(raw, list):
            cookies = {c["name"]: c["value"] for c in raw if "name" in c and "value" in c}
        else:
            cookies = raw
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(cookies))
        return cookies

    domain = urlparse(BB_BASE_URL).netloc  # studentcentral.brighton.ac.uk

    # Locate powershell.exe — bare name works when Windows paths are in WSL $PATH,
    # full path works when they aren't (e.g. restricted/sandboxed sessions).
    _PS_CANDIDATES = [
        "powershell.exe",
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
    ]
    powershell = next(
        (p for p in _PS_CANDIDATES if Path(p).exists() or p == "powershell.exe"),
        "powershell.exe",
    )

    # Try 'python' first (most common), fall back to 'py -3' (Windows Python Launcher)
    ps_command = f"python -c '{_WINDOWS_SCRIPT}' {domain}"
    result = subprocess.run(
        [powershell, "-Command", ps_command],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode != 0:
        ps_command_py = f"py -3 -c '{_WINDOWS_SCRIPT}' {domain}"
        result = subprocess.run(
            [powershell, "-Command", ps_command_py],
            capture_output=True,
            text=True,
            timeout=30,
        )

    if result.returncode != 0:
        raise RuntimeError(
            f"Cookie extraction failed. Is browser-cookie3 installed in Windows Python?\n"
            f"Run in Windows PowerShell: pip install browser-cookie3\n"
            f"Error: {result.stderr.strip()}"
        )

    cookies = json.loads(result.stdout.strip())
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(cookies))
    return cookies
