# FA583 Excel Audit & Cleanup Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the two "fluff" items from the Excel that make it look like it's doing analytical work beyond what the brief requires.

**Architecture:** Direct edits to `coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx` via a Python script using openpyxl. One script, one commit.

**Tech Stack:** Python 3, openpyxl

---

## Audit Summary

**What's correct (do not touch):**
- 8 ratios, all from Melville Ch.22, Chapter 22 — ROCE, Gross profit margin, Net profit margin, Current ratio, Quick assets ratio (acid test), Inventory holding period, Trade receivables collection period, Capital gearing ratio.
- 4 sheets: Income Statement, Balance Sheet, Cash Flow, Ratios.
- Formula column in Ratios sheet — shows the Melville formula text. Fine to keep.

**What needs removing:**

### Issue 1: Notes column in Ratios sheet (col F)
The column contains analytical commentary that belongs in the Word essay, not the spreadsheet:
- "Below 1.0x — structural: ~£4bn deferred subscription income in CL"
- "Long but improving — B2B enterprise clients on annual contracts"
- "Elevated but slowly declining; equity base partly intangible"

This makes the Excel look like it's doing the analysis. The brief says Excel is for quantitative presentation; analysis goes in the written submission.

**Fix:** Delete the entire Notes column (col F) from the Ratios sheet.

### Issue 2: MEMO rows in Balance Sheet and Cash Flow
- Balance Sheet row 30: `('MEMO: Net debt', 6604, 6446, 6563, None)` — derived calculation, not in the original RELX balance sheet
- Cash Flow row 25: `('MEMO: Free cash flow (approx.)', None, 2608, 3007)` — derived calculation, not in the original RELX cash flow statement

These are helpful for the analyst but are not part of the published financial statements. Including calculated memos in the "input" sheets blurs the line between raw data and analysis.

**Fix:** Delete both MEMO rows.

---

## Task 1: Remove Notes column from Ratios sheet

**Files:**
- Modify: `coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx`
- Script: `scripts/strip_excel_fluff.py` (new, one-off)

- [ ] **Step 1: Write the script**

Create `scripts/strip_excel_fluff.py`:

```python
import openpyxl
from copy import copy

PATH = "coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx"
wb = openpyxl.load_workbook(PATH)

# --- Fix 1: Delete Notes column (col 6) from Ratios sheet ---
ws_ratios = wb["Ratios"]
ws_ratios.delete_cols(6)  # col F = Notes

# --- Fix 2: Delete MEMO row from Balance Sheet ---
ws_bs = wb["Balance Sheet"]
for row in ws_bs.iter_rows():
    for cell in row:
        if cell.value and str(cell.value).startswith("MEMO: Net debt"):
            ws_bs.delete_rows(cell.row)
            break

# --- Fix 3: Delete MEMO row from Cash Flow ---
ws_cf = wb["Cash Flow"]
for row in ws_cf.iter_rows():
    for cell in row:
        if cell.value and str(cell.value).startswith("MEMO: Free cash flow"):
            ws_cf.delete_rows(cell.row)
            break

wb.save(PATH)
print("Done. Verify the Ratios sheet now has 5 columns, and no MEMO rows exist.")
```

- [ ] **Step 2: Run the script**

```bash
cd /home/zo/University/FA583
python3 scripts/strip_excel_fluff.py
```

Expected output:
```
Done. Verify the Ratios sheet now has 5 columns, and no MEMO rows exist.
```

- [ ] **Step 3: Verify the result**

```bash
cd /home/zo/University/FA583
python3 -c "
import openpyxl
wb = openpyxl.load_workbook('coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx')

ws = wb['Ratios']
print('Ratios columns:', ws.max_column, '(expect 5)')
print('Ratios header row:', [ws.cell(3, c).value for c in range(1, ws.max_column+1)])

ws_bs = wb['Balance Sheet']
memo_rows = [r for r in ws_bs.iter_rows(values_only=True) if r[0] and 'MEMO' in str(r[0])]
print('BS MEMO rows remaining:', memo_rows, '(expect [])')

ws_cf = wb['Cash Flow']
memo_rows_cf = [r for r in ws_cf.iter_rows(values_only=True) if r[0] and 'MEMO' in str(r[0])]
print('CF MEMO rows remaining:', memo_rows_cf, '(expect [])')
"
```

Expected output:
```
Ratios columns: 5 (expect 5)
Ratios header row: ['Ratio', '2022', '2023', '2024', 'Formula']
BS MEMO rows remaining: [] (expect [])
CF MEMO rows remaining: [] (expect [])
```

- [ ] **Step 4: Copy to Admin folder to keep in sync**

```bash
cp coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx "Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx"
```

- [ ] **Step 5: Commit**

```bash
git add coursework/RELX_Financial_Analysis_FA583_FINAL.xlsx "Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx" scripts/strip_excel_fluff.py
git commit -m "fix(excel): remove Notes column and MEMO rows — keep only Melville Ch.22 ratios and source data"
```

---

## Final State

After cleanup the Excel will contain:
- **Ratios sheet**: 5 columns — Ratio, 2022, 2023, 2024, Formula. No interpretive text.
- **Balance Sheet**: Source data only, no derived MEMO row.
- **Cash Flow**: Source data only, no derived MEMO row.
- **Income Statement**: Unchanged (Notes column entries are source-level labels, not analysis).
