# ~/University/scripts/bb_sync/__main__.py
import sys
from pathlib import Path

# Ensure the package directory is on sys.path when run as `python -m bb_sync`
sys.path.insert(0, str(Path(__file__).parent))

from config import BB_BASE_URL, LOCAL_ROOT, local_path_for_course
from cookie_extractor import extract_bb_cookies
from bb_client import BlackboardClient
from syncer import Syncer


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

    user_id = me.get("id")
    if not user_id:
        print("ERROR: Could not retrieve user ID from Blackboard response.")
        sys.exit(1)
    print(f"Logged in as: {me.get('userName', user_id)}")

    print("Fetching enrolled courses…")
    courses = client.get_courses(user_id)
    if not courses:
        print("No active courses found.")
        sys.exit(0)

    print(f"Found {len(courses)} active course(s):")
    for c in courses:
        course_name = c.get("name", "")
        if not course_name:
            print(f"  [skip] Course {c.get('id', '?')} has no name, skipping")
            continue
        folder_name = local_path_for_course(course_name)
        if not folder_name:
            print(f"  [skip] Could not determine local folder for: {course_name!r}")
            continue
        local_path = str(Path(LOCAL_ROOT) / folder_name)
        print(f"  {course_name} → {local_path}")
        try:
            syncer.sync_course(c["id"], course_name, local_path)
        except Exception as e:
            print(f"  [error] Failed to sync {course_name}: {e}")

    print("\nSync complete.")


if __name__ == "__main__":
    main()
