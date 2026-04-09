# Module Allowlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Filter Blackboard sync to only the six specified modules: FA565, FN585, FA583, FN581, LW570, MA583.

**Architecture:** Add a `SYNC_MODULES` set to `config.py` and a `should_sync_course()` helper that checks the extracted module code against the allowlist. Update `__main__.py` to skip courses not in the allowlist.

**Tech Stack:** Python 3, unittest (stdlib)

---

## File Map

| File | Change |
|---|---|
| `scripts/bb_sync/config.py` | Add `SYNC_MODULES` set + `should_sync_course()` function |
| `scripts/bb_sync/__main__.py` | Skip courses where `should_sync_course()` returns False |
| `scripts/bb_sync/test_config.py` | New file — unit tests for `should_sync_course()` |

---

### Task 1: Test `should_sync_course()`

**Files:**
- Create: `scripts/bb_sync/test_config.py`

- [ ] **Step 1: Write the failing tests**

```python
# scripts/bb_sync/test_config.py
import sys
import unittest
sys.path.insert(0, '.')
from config import should_sync_course

class TestShouldSyncCourse(unittest.TestCase):
    def test_listed_module_is_synced(self):
        self.assertTrue(should_sync_course("FN585 - Corporate Finance"))

    def test_unlisted_module_is_skipped(self):
        self.assertFalse(should_sync_course("BY150 - Introduction to Business"))

    def test_all_six_modules_are_synced(self):
        cases = [
            "FA565 - Financial Reporting",
            "FN585 - Corporate Finance",
            "FA583 - Advanced Accounting",
            "FN581 - Investments",
            "LW570 - Business Law",
            "MA583 - Quantitative Methods",
        ]
        for course_name in cases:
            with self.subTest(course_name=course_name):
                self.assertTrue(should_sync_course(course_name))

    def test_course_with_no_code_is_skipped(self):
        self.assertFalse(should_sync_course("General Resources"))

    def test_lowercase_code_in_title_is_matched(self):
        # Module codes in BB titles are always uppercase, but be safe
        self.assertTrue(should_sync_course("fn585 - Corporate Finance"))

if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/University/scripts/bb_sync && python -m pytest test_config.py -v
```

Expected: `ImportError: cannot import name 'should_sync_course' from 'config'`

- [ ] **Step 3: Add `SYNC_MODULES` and `should_sync_course()` to `config.py`**

Add after the existing `MODULE_CODE_RE` line:

```python
# Allowlist — only these module codes will be synced
SYNC_MODULES = {"FA565", "FN585", "FA583", "FN581", "LW570", "MA583"}


def should_sync_course(course_name: str) -> bool:
    """Return True only if course_name contains a module code in SYNC_MODULES."""
    m = MODULE_CODE_RE.search(course_name.upper())
    return bool(m and m.group(1) in SYNC_MODULES)
```

Full updated `config.py` for reference:

```python
BB_BASE_URL = "https://studentcentral.brighton.ac.uk"
LOCAL_ROOT = "/home/zo/University"
COOKIE_CACHE = "/home/zo/.cache/bb_sync/cookies.json"

# Maps Blackboard course name prefix → local subfolder name
# The script will auto-detect codes like FA565, FN585, FA583 from course titles.
# Add explicit overrides here if auto-detection misses one:
COURSE_OVERRIDES = {
    # "Some Long Course Name": "FA565",
}

# Regex to pull a module code from a BB course title, e.g. "FN585 - Corporate Finance"
import re
MODULE_CODE_RE = re.compile(r'\b([A-Z]{2,4}\d{3,4})\b')

# Allowlist — only these module codes will be synced
SYNC_MODULES = {"FA565", "FN585", "FA583", "FN581", "LW570", "MA583"}


def should_sync_course(course_name: str) -> bool:
    """Return True only if course_name contains a module code in SYNC_MODULES."""
    m = MODULE_CODE_RE.search(course_name.upper())
    return bool(m and m.group(1) in SYNC_MODULES)


def local_path_for_course(course_name: str) -> str:
    """Return the local folder name for a given Blackboard course name."""
    if course_name in COURSE_OVERRIDES:
        return COURSE_OVERRIDES[course_name]
    m = MODULE_CODE_RE.search(course_name)
    if m:
        return m.group(1)
    # Fallback: sanitise course name as folder
    return re.sub(r'[^\w\-]', '_', course_name).strip('_')
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ~/University/scripts/bb_sync && python -m pytest test_config.py -v
```

Expected:
```
test_config.py::TestShouldSyncCourse::test_all_six_modules_are_synced PASSED
test_config.py::TestShouldSyncCourse::test_course_with_no_code_is_skipped PASSED
test_config.py::TestShouldSyncCourse::test_listed_module_is_synced PASSED
test_config.py::TestShouldSyncCourse::test_lowercase_code_in_title_is_matched PASSED
test_config.py::TestShouldSyncCourse::test_unlisted_module_is_skipped PASSED
5 passed
```

- [ ] **Step 5: Commit**

```bash
cd ~/University/scripts/bb_sync
git add test_config.py config.py
git commit -m "feat: add module allowlist (FA565 FN585 FA583 FN581 LW570 MA583)"
```

---

### Task 2: Apply allowlist filter in `__main__.py`

**Files:**
- Modify: `scripts/bb_sync/__main__.py`

- [ ] **Step 1: Write the failing test**

Add a test to a new file `test_main_filter.py` that monkeypatches the module list and asserts that unlisted courses are skipped:

```python
# scripts/bb_sync/test_main_filter.py
import sys
import unittest
from unittest.mock import MagicMock, patch
sys.path.insert(0, '.')

class TestMainFilter(unittest.TestCase):
    def test_unlisted_course_is_not_synced(self):
        """Courses outside SYNC_MODULES must not be passed to syncer.sync_course."""
        mock_client = MagicMock()
        mock_client.get_current_user.return_value = {"id": "u1", "userName": "testuser"}
        mock_client.get_courses.return_value = [
            {"id": "_1_1", "name": "BY150 - Introduction to Business"},
            {"id": "_2_1", "name": "FN585 - Corporate Finance"},
        ]

        mock_syncer = MagicMock()

        with patch('__main__.extract_bb_cookies', return_value={}), \
             patch('__main__.BlackboardClient', return_value=mock_client), \
             patch('__main__.Syncer', return_value=mock_syncer):
            import __main__
            __main__.main()

        synced_names = [
            call.args[1] for call in mock_syncer.sync_course.call_args_list
        ]
        self.assertNotIn("BY150 - Introduction to Business", synced_names)
        self.assertIn("FN585 - Corporate Finance", synced_names)

if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd ~/University/scripts/bb_sync && python -m pytest test_main_filter.py -v
```

Expected: `FAILED — AssertionError: 'BY150 - Introduction to Business' unexpectedly found` (or similar — the current code syncs everything).

- [ ] **Step 3: Add allowlist check to `__main__.py`**

Update the course-loop section. Replace the block starting at line 50 with:

```python
    print(f"Found {len(courses)} active course(s):")
    for c in courses:
        course_name = c.get("name", "")
        if not course_name:
            print(f"  [skip] Course {c.get('id', '?')} has no name, skipping")
            continue
        if not should_sync_course(course_name):
            print(f"  [skip] {course_name!r} not in module allowlist")
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
```

Also update the import at the top of `__main__.py`:

```python
from config import BB_BASE_URL, LOCAL_ROOT, local_path_for_course, should_sync_course
```

Full updated `__main__.py` for reference:

```python
# ~/University/scripts/bb_sync/__main__.py
import sys
from pathlib import Path

# Ensure the package directory is on sys.path when run as `python -m bb_sync`
sys.path.insert(0, str(Path(__file__).parent))

from config import BB_BASE_URL, LOCAL_ROOT, local_path_for_course, should_sync_course
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
        if not should_sync_course(course_name):
            print(f"  [skip] {course_name!r} not in module allowlist")
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
```

- [ ] **Step 4: Run all tests to verify everything passes**

```bash
cd ~/University/scripts/bb_sync && python -m pytest test_config.py test_main_filter.py test_syncer.py test_bb_client.py test_cookie_extractor.py -v
```

Expected: all tests pass, no failures.

- [ ] **Step 5: Commit**

```bash
cd ~/University/scripts/bb_sync
git add __main__.py test_main_filter.py
git commit -m "feat: skip courses not in module allowlist"
```
