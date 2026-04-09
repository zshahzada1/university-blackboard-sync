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
    """Require sudo authentication before cookie extraction.

    Invalidates any cached sudo timestamp (sudo -k) then validates credentials
    (sudo -v), which prompts for a password unless NOPASSWD is configured.
    Raises RuntimeError if sudo -v fails.
    """
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
        try:
            if page_targets:
                ws_url = page_targets[0]["webSocketDebuggerUrl"]
            else:
                new_tab = requests.get(f"{cdp_base}/json/new", timeout=5).json()
                ws_url = new_tab["webSocketDebuggerUrl"]
        except (KeyError, IndexError) as e:
            raise RuntimeError(f"Unexpected CDP target response: {e}") from e

        ws = websocket.WebSocket()
        ws.connect(ws_url, timeout=10)
        ws.settimeout(10)
        ws.send(json.dumps({"id": 1, "method": "Network.getAllCookies"}))
        try:
            result = json.loads(ws.recv())
            all_cookies = result["result"]["cookies"]
        except (KeyError, json.JSONDecodeError) as e:
            raise RuntimeError(f"Unexpected CDP getAllCookies response: {e}") from e
        finally:
            ws.close()

        return {
            c["name"]: c["value"]
            for c in all_cookies
            if domain in c.get("domain", "")
        }

    finally:
        _kill_edge_pid(powershell, edge_pid)


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
            f"Workaround: export cookies manually with Cookie-Editor and save to "
            f"{_WINDOWS_MANUAL_EXPORT}"
        )

    cookies = json.loads(result.stdout.strip())
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(cookies))
    return cookies
