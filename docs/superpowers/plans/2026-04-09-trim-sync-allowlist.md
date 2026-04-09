# Trim Sync Allowlist to FA565, FN585, FA583 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict Blackboard sync to only FA565, FN585, and FA583, and delete all local module directories that are not those three.

**Architecture:** Two changes — update the allowlist constant in `config.py`, then delete all stale local module directories. Tests are updated in sync with the config change.

**Tech Stack:** Python, unittest, bash

---

### Task 1: Update SYNC_MODULES and fix tests

**Files:**
- Modify: `scripts/bb_sync/config.py:17`
- Modify: `scripts/bb_sync/test_config.py`

- [ ] **Step 1: Write the failing test first**

Replace the existing `test_all_six_modules_are_synced` test and add negative cases for the removed modules in `scripts/bb_sync/test_config.py`:

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

    def test_only_three_modules_are_synced(self):
        cases = [
            "FA565 - Financial Reporting",
            "FN585 - Corporate Finance",
            "FA583 - Advanced Accounting",
        ]
        for course_name in cases:
            with self.subTest(course_name=course_name):
                self.assertTrue(should_sync_course(course_name))

    def test_removed_modules_are_not_synced(self):
        cases = [
            "FN581 - Investments",
            "LW570 - Business Law",
            "MA583 - Quantitative Methods",
        ]
        for course_name in cases:
            with self.subTest(course_name=course_name):
                self.assertFalse(should_sync_course(course_name))

    def test_course_with_no_code_is_skipped(self):
        self.assertFalse(should_sync_course("General Resources"))

if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/zo/University/scripts/bb_sync
python -m pytest test_config.py -v
```

Expected: `test_removed_modules_are_not_synced` FAILS (modules still in allowlist)

- [ ] **Step 3: Update SYNC_MODULES in config.py**

In `scripts/bb_sync/config.py`, change line 17:

```python
# Before:
SYNC_MODULES = {"FA565", "FN585", "FA583", "FN581", "LW570", "MA583"}

# After:
SYNC_MODULES = {"FA565", "FN585", "FA583"}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/zo/University/scripts/bb_sync
python -m pytest test_config.py -v
```

Expected: all 5 tests PASS

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
cd /home/zo/University/scripts/bb_sync
python -m pytest -v
```

Expected: all tests PASS (no regressions in test_main_filter.py, test_bb_client.py, etc.)

- [ ] **Step 6: Commit**

```bash
cd /home/zo/University
git add scripts/bb_sync/config.py scripts/bb_sync/test_config.py
git commit -m "feat: restrict sync allowlist to FA565, FN585, FA583 only"
```

---

### Task 2: Delete all stale local module directories

Keep only: `FA565/`, `FN585/`, `FA583/`, `docs/`, `scripts/`

**Directories to delete:**
- `BSc__Hons__Accounting_and_Finance/`
- `BY138/`, `BY150/`, `BY152/`, `BY153/`, `BY154/`, `BY155/`
- `EC463/`
- `FA454/`
- `FN442/`, `FN581/`
- `HR473/`
- `LW570/`
- `MA452/`, `MA583/`
- `ML450/`

- [ ] **Step 1: List each directory to confirm contents are Blackboard downloads**

```bash
ls /home/zo/University/BSc__Hons__Accounting_and_Finance /home/zo/University/BY138 /home/zo/University/BY150 /home/zo/University/BY152 /home/zo/University/BY153 /home/zo/University/BY154 /home/zo/University/BY155 /home/zo/University/EC463 /home/zo/University/FA454 /home/zo/University/FN442 /home/zo/University/FN581 /home/zo/University/HR473 /home/zo/University/LW570 /home/zo/University/MA452 /home/zo/University/MA583 /home/zo/University/ML450 2>/dev/null
```

- [ ] **Step 2: Delete all stale module directories**

```bash
rm -rf \
  /home/zo/University/BSc__Hons__Accounting_and_Finance \
  /home/zo/University/BY138 \
  /home/zo/University/BY150 \
  /home/zo/University/BY152 \
  /home/zo/University/BY153 \
  /home/zo/University/BY154 \
  /home/zo/University/BY155 \
  /home/zo/University/EC463 \
  /home/zo/University/FA454 \
  /home/zo/University/FN442 \
  /home/zo/University/FN581 \
  /home/zo/University/HR473 \
  /home/zo/University/LW570 \
  /home/zo/University/MA452 \
  /home/zo/University/MA583 \
  /home/zo/University/ML450
```

- [ ] **Step 3: Verify only the three allowed modules remain (plus docs/ and scripts/)**

```bash
ls /home/zo/University/
```

Expected output contains only: `FA565  FA583  FN585  docs  scripts` (plus any hidden files)

- [ ] **Step 4: Commit the deletion**

```bash
cd /home/zo/University
git add -A
git commit -m "chore: remove all local dirs for modules no longer synced"
```
