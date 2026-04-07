import json
import subprocess
import time
from pathlib import Path
from urllib.parse import urlparse
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
