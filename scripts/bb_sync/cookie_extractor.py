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
            return json.loads(cache.read_text())

    domain = urlparse(BB_BASE_URL).netloc  # studentcentral.brighton.ac.uk

    result = subprocess.run(
        ["powershell.exe", "-Command", f'python -c "{_WINDOWS_SCRIPT}" {domain}'],
        capture_output=True,
        text=True,
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
