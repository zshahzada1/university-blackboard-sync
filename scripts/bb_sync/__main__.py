# ~/University/scripts/bb_sync/__main__.py
import sys
from pathlib import Path
from .config import BB_BASE_URL, LOCAL_ROOT, local_path_for_course
from .cookie_extractor import extract_bb_cookies
from .bb_client import BlackboardClient
from .syncer import Syncer


def main():
    force_refresh = "--refresh-cookies" in sys.argv
    print(f"Blackboard Sync — {BB_BASE_URL}")

    print("Extracting Edge cookies from Windows…")
    try:
        cookies = extract_bb_cookies(force_refresh=force_refresh)
    except RuntimeError as e:
        print(f"ERROR: {e}")
        print("\nFix: open Windows PowerShell and run: pip install browser-cookie3")
        print("Also make sure you are logged in to Blackboard in Edge.")
        sys.exit(1)

    client = BlackboardClient(cookies)
    syncer = Syncer(client, LOCAL_ROOT)

    print("Checking authentication…")
    try:
        me = client.get_current_user()
    except Exception as e:
        print(f"ERROR: Could not authenticate with Blackboard: {e}")
        print("Try: python -m bb_sync --refresh-cookies")
        sys.exit(1)

    user_id = me["id"]
    print(f"Logged in as: {me.get('userName', user_id)}")

    print("Fetching enrolled courses…")
    courses = client.get_courses(user_id)
    if not courses:
        print("No active courses found.")
        sys.exit(0)

    print(f"Found {len(courses)} active course(s):")
    for c in courses:
        folder_name = local_path_for_course(c["name"])
        local_path = str(Path(LOCAL_ROOT) / folder_name)
        print(f"  {c['name']} → {local_path}")
        syncer.sync_course(c["id"], c["name"], local_path)

    print("\nSync complete.")


if __name__ == "__main__":
    main()
