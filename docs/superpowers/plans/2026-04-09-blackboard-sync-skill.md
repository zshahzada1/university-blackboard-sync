# Blackboard Sync Interactive Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the blackboard sync CLI with `--list-courses` and `--modules` flags, then rewrite the `blackboard-sync` skill so it interactively asks the user which modules to sync instead of using a hardcoded allowlist.

**Architecture:** The Python CLI gets two new flags: `--list-courses` outputs all enrolled courses as JSON (status to stderr, clean JSON to stdout); `--modules CODE...` overrides the config allowlist for a single run. The SKILL.md orchestrates the interaction: run `--list-courses`, present the list via `AskUserQuestion`, then run `--modules` with whatever the user picks.

**Tech Stack:** Python 3, argparse, unittest + unittest.mock, existing bb_sync package at `~/University/scripts/bb_sync/`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `scripts/bb_sync/__main__.py` | Add `--list-courses` and `--modules` flags via argparse |
| Modify | `scripts/bb_sync/test_main_filter.py` | Add tests for both new flags |
| Modify | `~/.claude/skills/blackboard-sync/SKILL.md` | Rewrite with interactive sync workflow |

---

## Task 1: Add `--list-courses` flag to `__main__.py`

**Files:**
- Modify: `scripts/bb_sync/__main__.py`
- Test: `scripts/bb_sync/test_main_filter.py`

- [ ] **Step 1: Write the failing test**

Add these imports and the test class method to `scripts/bb_sync/test_main_filter.py`. Add `import io`, `import json`, and `import pathlib` to the top of the file, then add `_load_main_module` helper and the new test inside `TestMainFilter`:

```python
# Add to top of test_main_filter.py (after existing imports):
import io
import json
import pathlib
import importlib.util
```

```python
# Add inside class TestMainFilter (after the existing test method):

    def _load_main_module(self):
        """Load __main__.py fresh so patches bind into its namespace."""
        sys.modules.pop('bb_sync_main', None)
        spec = importlib.util.spec_from_file_location(
            'bb_sync_main',
            pathlib.Path(__file__).parent / '__main__.py'
        )
        main_mod = importlib.util.module_from_spec(spec)
        sys.modules['bb_sync_main'] = main_mod
        spec.loader.exec_module(main_mod)
        return main_mod

    def test_list_courses_outputs_all_as_json(self):
        """--list-courses prints JSON of ALL courses (not filtered) to stdout and exits 0."""
        mock_client = MagicMock()
        mock_client.get_current_user.return_value = {"id": "u1", "userName": "testuser"}
        mock_client.get_courses.return_value = [
            {"id": "_1_1", "name": "FA565 - Financial Reporting"},
            {"id": "_2_1", "name": "BY150 - Introduction to Business"},
        ]
        main_mod = self._load_main_module()

        buf = io.StringIO()
        with patch('bb_sync_main.extract_bb_cookies', return_value={}), \
             patch('bb_sync_main.BlackboardClient', return_value=mock_client), \
             patch('bb_sync_main.Syncer', return_value=MagicMock()), \
             patch('sys.argv', ['bb_sync', '--list-courses']), \
             patch('sys.stdout', buf):
            with self.assertRaises(SystemExit) as ctx:
                main_mod.main()

        self.assertEqual(ctx.exception.code, 0)
        data = json.loads(buf.getvalue())
        self.assertEqual(len(data), 2)
        codes = [item["code"] for item in data]
        self.assertIn("FA565", codes)
        self.assertIn("BY150", codes)
        # Both courses present even though BY150 is not in SYNC_MODULES
        names = [item["name"] for item in data]
        self.assertIn("FA565 - Financial Reporting", names)
        self.assertIn("BY150 - Introduction to Business", names)
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_main_filter.py::TestMainFilter::test_list_courses_outputs_all_as_json -v
```

Expected: `FAILED` — `AttributeError` or `ImportError` because `--list-courses` doesn't exist yet.

- [ ] **Step 3: Implement `--list-courses` in `__main__.py`**

Replace the entire contents of `scripts/bb_sync/__main__.py` with:

```python
# ~/University/scripts/bb_sync/__main__.py
import sys
import json
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from config import BB_BASE_URL, LOCAL_ROOT, local_path_for_course, should_sync_course, MODULE_CODE_RE
from cookie_extractor import extract_bb_cookies
from bb_client import BlackboardClient
from syncer import Syncer


def main():
    parser = argparse.ArgumentParser(description="Blackboard file sync")
    parser.add_argument("--refresh-cookies", action="store_true",
                        help="Force re-extract cookies from Edge")
    parser.add_argument("--list-courses", action="store_true",
                        help="Output enrolled courses as JSON and exit")
    parser.add_argument("--modules", nargs="+", metavar="CODE",
                        help="Module codes to sync (overrides config allowlist)")
    args = parser.parse_args()

    # In --list-courses mode all status goes to stderr so stdout stays clean JSON
    out = sys.stderr if args.list_courses else sys.stdout

    print(f"Blackboard Sync — {BB_BASE_URL}", file=out)

    print("Extracting Edge cookies from Windows…", file=out)
    try:
        cookies = extract_bb_cookies(force_refresh=args.refresh_cookies)
    except RuntimeError as e:
        print(f"ERROR: {e}", file=out)
        print("\nFix: open Windows PowerShell and run: pip install browser-cookie3", file=out)
        print("Also make sure you are logged in to Blackboard in Edge.", file=out)
        sys.exit(1)

    client = BlackboardClient(cookies)
    syncer = Syncer(client, LOCAL_ROOT)

    print("Checking authentication…", file=out)
    try:
        me = client.get_current_user()
    except Exception as e:
        print(f"ERROR: Could not authenticate with Blackboard: {e}", file=out)
        print("Try: python -m bb_sync --refresh-cookies", file=out)
        sys.exit(1)

    user_id = me.get("id")
    if not user_id:
        print("ERROR: Could not retrieve user ID from Blackboard response.", file=out)
        sys.exit(1)
    print(f"Logged in as: {me.get('userName', user_id)}", file=out)

    print("Fetching enrolled courses…", file=out)
    courses = client.get_courses(user_id)
    if not courses:
        print("No active courses found.", file=out)
        if args.list_courses:
            print("[]")
        sys.exit(0)

    if args.list_courses:
        result = []
        for c in courses:
            name = c.get("name", "") or ""
            match = MODULE_CODE_RE.search(name) if name else None
            result.append({
                "id": c["id"],
                "name": name,
                "code": match.group(1) if match else None,
            })
        print(json.dumps(result))
        sys.exit(0)

    # Determine filter set: explicit --modules overrides config allowlist
    modules_filter = set(args.modules) if args.modules else None

    print(f"Found {len(courses)} active course(s):")
    for c in courses:
        course_name = c.get("name", "")
        if not course_name:
            print(f"  [skip] Course {c.get('id', '?')} has no name, skipping")
            continue

        if modules_filter is not None:
            m = MODULE_CODE_RE.search(course_name)
            if not m or m.group(1) not in modules_filter:
                print(f"  [skip] {course_name!r} not in selected modules")
                continue
        elif not should_sync_course(course_name):
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

- [ ] **Step 4: Run test to confirm it passes**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_main_filter.py::TestMainFilter::test_list_courses_outputs_all_as_json -v
```

Expected: `PASSED`

- [ ] **Step 5: Confirm existing tests still pass**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest -v
```

Expected: all tests `PASSED` (20+ tests)

- [ ] **Step 6: Commit**

```bash
cd ~/University && git add scripts/bb_sync/__main__.py scripts/bb_sync/test_main_filter.py
git commit -m "feat: add --list-courses flag to output enrolled courses as JSON"
```

---

## Task 2: Add `--modules` override flag

**Files:**
- Test: `scripts/bb_sync/test_main_filter.py` (add two tests)
- `scripts/bb_sync/__main__.py` is already updated from Task 1

- [ ] **Step 1: Write failing tests for `--modules`**

Add these two test methods inside `class TestMainFilter` in `test_main_filter.py`:

```python
    def test_modules_flag_syncs_only_selected(self):
        """--modules FA565 syncs only FA565 even when FN585 is available."""
        mock_client = MagicMock()
        mock_client.get_current_user.return_value = {"id": "u1", "userName": "testuser"}
        mock_client.get_courses.return_value = [
            {"id": "_1_1", "name": "FA565 - Financial Reporting"},
            {"id": "_2_1", "name": "FN585 - Corporate Finance"},
        ]
        mock_syncer = MagicMock()
        main_mod = self._load_main_module()

        with patch('bb_sync_main.extract_bb_cookies', return_value={}), \
             patch('bb_sync_main.BlackboardClient', return_value=mock_client), \
             patch('bb_sync_main.Syncer', return_value=mock_syncer), \
             patch('sys.argv', ['bb_sync', '--modules', 'FA565']):
            main_mod.main()

        synced = [call.args[1] for call in mock_syncer.sync_course.call_args_list]
        self.assertIn("FA565 - Financial Reporting", synced)
        self.assertNotIn("FN585 - Corporate Finance", synced)

    def test_modules_flag_accepts_multiple_codes(self):
        """--modules FA565 FN585 syncs both specified modules."""
        mock_client = MagicMock()
        mock_client.get_current_user.return_value = {"id": "u1", "userName": "testuser"}
        mock_client.get_courses.return_value = [
            {"id": "_1_1", "name": "FA565 - Financial Reporting"},
            {"id": "_2_1", "name": "FN585 - Corporate Finance"},
            {"id": "_3_1", "name": "BY150 - Introduction to Business"},
        ]
        mock_syncer = MagicMock()
        main_mod = self._load_main_module()

        with patch('bb_sync_main.extract_bb_cookies', return_value={}), \
             patch('bb_sync_main.BlackboardClient', return_value=mock_client), \
             patch('bb_sync_main.Syncer', return_value=mock_syncer), \
             patch('sys.argv', ['bb_sync', '--modules', 'FA565', 'FN585']):
            main_mod.main()

        synced = [call.args[1] for call in mock_syncer.sync_course.call_args_list]
        self.assertIn("FA565 - Financial Reporting", synced)
        self.assertIn("FN585 - Corporate Finance", synced)
        self.assertNotIn("BY150 - Introduction to Business", synced)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest test_main_filter.py::TestMainFilter::test_modules_flag_syncs_only_selected test_main_filter.py::TestMainFilter::test_modules_flag_accepts_multiple_codes -v
```

Expected: `FAILED` — the `--modules` logic is already written in Task 1, so these should actually pass. If they do pass, skip Step 3.

> **Note:** If the tests pass here (they may, since `__main__.py` was fully rewritten in Task 1), skip to Step 4 to verify all tests pass.

- [ ] **Step 3: (Only if tests failed) Verify `__main__.py` has the `--modules` implementation**

Check that `scripts/bb_sync/__main__.py` contains `parser.add_argument("--modules", ...)` and the `modules_filter` logic. If not, re-apply the full file from Task 1 Step 3.

- [ ] **Step 4: Run all tests**

```bash
cd ~/University/scripts/bb_sync && python3 -m pytest -v
```

Expected: all tests `PASSED`

- [ ] **Step 5: Commit**

```bash
cd ~/University && git add scripts/bb_sync/test_main_filter.py
git commit -m "test: add coverage for --modules flag single and multiple code selection"
```

---

## Task 3: Rewrite `blackboard-sync` SKILL.md with interactive workflow

**Files:**
- Modify: `~/.claude/skills/blackboard-sync/SKILL.md`

No code tests for this task — skill correctness is verified by running `/blackboard-sync` in Claude Code.

- [ ] **Step 1: Rewrite `~/.claude/skills/blackboard-sync/SKILL.md`**

Replace the entire file with:

```markdown
---
name: blackboard-sync
version: 2.0.0
description: |
  Sync University of Brighton Blackboard course files interactively.
  Use when the user mentions syncing Blackboard, downloading course files,
  or anything related to studentcentral.brighton.ac.uk.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Blackboard Sync — University of Brighton

A Python CLI at `~/University/scripts/bb_sync/` that syncs Blackboard course files to `~/University/<MODULE>/` folders on WSL2.

## Tool Overview

```
~/University/scripts/bb_sync/
├── __main__.py        # Entry point — run as: python3 .
├── config.py          # BB_BASE_URL, LOCAL_ROOT, SYNC_MODULES allowlist, module-code regex
├── cookie_extractor.py  # Extracts Edge cookies via Windows Python/powershell.exe
├── bb_client.py       # Blackboard REST API client (courses, contents, attachments)
├── syncer.py          # Walks content tree, atomic downloads, skip-existing
└── requirements.txt   # requests, pytest
```

**CLI flags:**
- `python3 .` — sync using config allowlist (FA565, FN585, FA583)
- `python3 . --refresh-cookies` — force re-extract cookies from Edge
- `python3 . --list-courses` — output all enrolled courses as JSON, exit
- `python3 . --modules FA565 FN585` — sync only the specified module codes

Run tests: `cd ~/University/scripts/bb_sync && python3 -m pytest`

---

## Interactive Sync Workflow

When the user asks to sync Blackboard (or asks which modules are available):

### Step 1 — Discover available modules

```bash
cd ~/University/scripts/bb_sync && python3 . --list-courses 2>/dev/null
```

This outputs a JSON array to stdout (all status/error messages go to stderr):

```json
[
  {"id": "_1_1", "name": "FA565 - Financial Reporting", "code": "FA565"},
  {"id": "_2_1", "name": "FN585 - Corporate Finance",   "code": "FN585"},
  {"id": "_3_1", "name": "FA583 - Advanced Accounting", "code": "FA583"}
]
```

If the command fails (non-zero exit, empty output, or invalid JSON), check cookies first:
- Run: `python3 . --refresh-cookies --list-courses 2>&1 | head -20` to see errors
- Then follow the troubleshooting section below

### Step 2 — Ask the user which modules to sync

Use the **AskUserQuestion** tool. Present the list as a numbered menu:

> Found N enrolled modules:
> 1. FA565 — FA565 - Financial Reporting
> 2. FN585 — FN585 - Corporate Finance
> 3. FA583 — FA583 - Advanced Accounting
>
> Which would you like to sync? Enter numbers (e.g. `1 3`), module codes (e.g. `FA565 FA583`), or `all`.

Parse the user's response to build the list of codes to sync.

### Step 3 — Run the sync

**For specific modules** (user chose a subset):

```bash
cd ~/University/scripts/bb_sync && python3 . --modules FA565 FN585
```

Replace `FA565 FN585` with the codes the user selected.

**For all modules** (user said "all"):

```bash
cd ~/University/scripts/bb_sync && python3 . --modules FA565 FN585 FA583
```

Pass every code from the `--list-courses` output.

### Step 4 — Report results

After the sync command completes, summarise:
- Which modules were synced
- Any `[error]` lines from stdout
- Where files landed (e.g. `~/University/FA565/`)

---

## How Cookie Extraction Works

`cookie_extractor.py` calls `powershell.exe` from WSL to invoke Windows Python with `browser_cookie3`, which decrypts Edge cookies using DPAPI (Windows-only). Cookies are cached to `~/.cache/bb_sync/cookies.json` for 1 hour.

**Requires:**
- WSL interop enabled (`interop.enabled = true` in `/etc/wsl.conf`)
- `browser_cookie3` installed in Windows Python: `pip install browser-cookie3` (run in Windows PowerShell)
- Edge signed in to `studentcentral.brighton.ac.uk`

## WSL Setup (if interop is disabled)

Check `/etc/wsl.conf`. It must have:
```ini
[automount]
enabled = true

[interop]
enabled = true
appendWindowsPath = true
```

After editing, restart WSL from Windows PowerShell: `wsl --shutdown`, then reopen.

## Known Issue: DPAPI / Admin Error

`browser_cookie3` fails if:
1. **Running PowerShell as Admin** — DPAPI keys are per-user; admin context can't decrypt them. Run as **normal user**.
2. **Edge is open** — cookie DB is locked. Fix: **close Edge completely** (check Task Manager for background Edge processes) before running.

Correct flow:
1. Close Edge completely (all windows + background processes)
2. Open normal (non-admin) PowerShell
3. Run `python3 .` from WSL (or it'll be called automatically)

## Module Folder Mapping

Blackboard course names → local folders via regex `\b([A-Z]{2,4}\d{3,4})\b`:
- `"FN585 - Corporate Finance"` → `~/University/FN585/`
- `"FA565 Financial Accounting"` → `~/University/FA565/`

Add overrides in `config.py` → `COURSE_OVERRIDES` dict if auto-detection misses any.

## Troubleshooting

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

- [ ] **Step 2: Smoke-test the skill trigger**

In Claude Code, type `/blackboard-sync` or ask "sync my Blackboard modules" and confirm the skill loads and runs Step 1 (`--list-courses`) automatically.

- [ ] **Step 3: Commit**

```bash
cd ~ && git -C ~/.claude add skills/blackboard-sync/SKILL.md 2>/dev/null || true
# If skills aren't in a git repo, skip git and just verify the file is saved
```

---

## Self-Review

### Spec coverage

| Requirement | Covered by |
|-------------|-----------|
| Find all modules from Blackboard | Task 1: `--list-courses` fetches all enrolled courses |
| Ask user which to sync | Task 3: SKILL.md Step 2 uses AskUserQuestion |
| Sync only selected modules | Task 2: `--modules` flag, Task 3 Step 3 passes user selection |
| Follow skill guide best practices | Task 3: YAML frontmatter, clear trigger description, AskUserQuestion tool listed |
| Backward compatible (existing `python3 .` still works) | Task 1 implementation preserves argparse default behaviour |

### Placeholder scan

No TBDs, TODOs, or "add error handling" phrases present.

### Type consistency

- `MODULE_CODE_RE` imported from `config` in `__main__.py` (Task 1) — matches definition in `config.py:14`
- `match.group(1)` pattern used identically in `config.py:local_path_for_course` and new `__main__.py` list-courses block
- `--modules` parsed as `nargs="+"` → `list[str]` → wrapped in `set()` as `modules_filter` — consistent throughout

---
