# Pagination Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure `get_contents()` fetches all content items from a Blackboard course folder by following `paging.nextPage` links until exhausted.

**Architecture:** The Blackboard REST API returns a `paging` object alongside `results` when there are more pages. The current code requests `limit: 200` but discards `paging`, so anything beyond the first page is silently dropped. The fix is in `get_contents` in `bb_client.py` — accumulate results across pages using the `nextPage` URL until the response contains no `paging.nextPage`.

**Tech Stack:** Python 3, requests, unittest (stdlib)

---

## File Map

| File | Change |
|---|---|
| `scripts/bb_sync/bb_client.py` | Replace `get_contents` single-request body with a pagination loop |
| `scripts/bb_sync/test_bb_client.py` | Add tests for multi-page and single-page responses |

---

### Task 1: Test and fix `get_contents` pagination

**Files:**
- Modify: `scripts/bb_sync/bb_client.py:45-51`
- Modify: `scripts/bb_sync/test_bb_client.py`

#### Background: what the API returns

A paginated response looks like:
```json
{
  "results": [{"id": "_1_1", "title": "Week 1"}, ...],
  "paging": {
    "nextPage": "/learn/api/public/v1/courses/_123_1/contents?offset=200&limit=200"
  }
}
```
When there are no more pages, the `paging` key is absent (or `paging.nextPage` is absent).

The `nextPage` value is a **path** (starting with `/learn/...`), not a full URL.

- [ ] **Step 1: Read the existing test file**

```bash
cat /home/zo/University/scripts/bb_sync/test_bb_client.py
```

This tells you what's already tested so you don't break it or duplicate it.

- [ ] **Step 2: Write failing tests for pagination**

Open `test_bb_client.py` and add the following two test methods inside the existing test class (or at the end of the file if no class exists):

```python
def test_get_contents_follows_next_page(self):
    """get_contents must return items from all pages, not just the first."""
    client = BlackboardClient({"session": "fake"})

    page1 = {
        "results": [{"id": "_1_1", "title": "Week 1"}],
        "paging": {"nextPage": "/learn/api/public/v1/courses/_c_1/contents?offset=1&limit=1"},
    }
    page2 = {
        "results": [{"id": "_2_1", "title": "Week 2"}],
        # no paging key = last page
    }

    with patch.object(client, '_get', side_effect=[page1, page2]) as mock_get:
        results = client.get_contents("_c_1")

    assert len(results) == 2
    assert results[0]["title"] == "Week 1"
    assert results[1]["title"] == "Week 2"
    # Second call must use the nextPage path, not re-request the root
    second_call_path = mock_get.call_args_list[1][0][0]
    assert "offset=1" in second_call_path

def test_get_contents_single_page_unchanged(self):
    """get_contents with no paging key returns results normally."""
    client = BlackboardClient({"session": "fake"})

    single_page = {"results": [{"id": "_1_1", "title": "Week 1"}]}

    with patch.object(client, '_get', return_value=single_page):
        results = client.get_contents("_c_1")

    assert results == [{"id": "_1_1", "title": "Week 1"}]
```

Also add `from unittest.mock import patch` at the top of the file if it isn't already imported.

- [ ] **Step 3: Run the new tests to verify they fail**

```bash
cd /home/zo/University/scripts/bb_sync && python -m pytest test_bb_client.py::TestBlackboardClient::test_get_contents_follows_next_page test_bb_client.py::TestBlackboardClient::test_get_contents_single_page_unchanged -v 2>&1 | tail -20
```

(Replace `TestBlackboardClient` with the actual class name from step 1 if different.)

Expected: both FAIL — `test_get_contents_follows_next_page` fails because only 1 result is returned instead of 2.

- [ ] **Step 4: Replace `get_contents` in `bb_client.py`**

Replace lines 45–51 (the current `get_contents` method) with:

```python
def get_contents(self, course_id: str, parent_id: str = None) -> list:
    if parent_id:
        path = f"/learn/api/public/v1/courses/{course_id}/contents/{parent_id}/children"
    else:
        path = f"/learn/api/public/v1/courses/{course_id}/contents"

    params = {"limit": 200}
    all_results = []
    while path:
        data = self._get(path, params=params)
        all_results.extend(data.get("results", []))
        path = (data.get("paging") or {}).get("nextPage")
        params = {}  # nextPage URL already contains all query params
    return all_results
```

- [ ] **Step 5: Run the new tests to verify they pass**

```bash
cd /home/zo/University/scripts/bb_sync && python -m pytest test_bb_client.py::TestBlackboardClient::test_get_contents_follows_next_page test_bb_client.py::TestBlackboardClient::test_get_contents_single_page_unchanged -v
```

Expected: both PASS.

- [ ] **Step 6: Run the full test suite**

```bash
cd /home/zo/University/scripts/bb_sync && python -m pytest test_bb_client.py test_syncer.py test_config.py test_main_filter.py test_cookie_extractor.py -v
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /home/zo/University && git add scripts/bb_sync/bb_client.py scripts/bb_sync/test_bb_client.py
git commit -m "fix: paginate get_contents to fetch all course content items"
```
