# FA583 Submission Update — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace non-Melville ratios with the correct 8 textbook ratios, improve Excel presentation, and rewrite the Word document analysis with humanized writing.

**Architecture:** Python scripts using `openpyxl` for Excel edits and `python-docx` for Word edits. Each script is run once and produces the updated file in-place. Humanizer principles applied to all Word prose.

**Tech Stack:** Python 3, openpyxl, python-docx

---

## Pre-flight: verify dependencies

- [ ] **Step 1: Check Python packages are available**

Run: `python3 -c "import openpyxl, docx; print('OK')"`

Expected: `OK`

If missing: `pip install openpyxl python-docx`

---

## The 8 Melville ratios (reference — do not skip this)

All ratios from *Melville, International Financial Reporting, 7th ed., Ch.22*.

Calculated values using data already in the Excel file:

**Profitability**
| Ratio | Formula | 2022 | 2023 | 2024 |
|-------|---------|------|------|------|
| ROCE | EBIT / (Total assets − Current liabilities) | 21.8% | 28.5% | 30.4% |
| Gross profit margin | Gross profit / Revenue | 64.4% | 64.9% | 65.0% |
| Net profit margin | Net profit (shareholders) / Revenue | 19.1% | 19.4% | 20.5% |

**Liquidity — short-term**
| Ratio | Formula | 2022 | 2023 | 2024 |
|-------|---------|------|------|------|
| Current ratio | Current assets / Current liabilities | 0.59x | 0.52x | 0.52x |
| Quick assets ratio | (Current assets − Inventories) / Current liabilities | 0.53x | 0.46x | 0.47x |
| Inventory holding period | (Inventories / Cost of sales) × 365 | 37.1 days | 36.1 days | 36.6 days |
| Trade receivables collection period | (Trade receivables / Revenue) × 365 | 102.7 days | 92.6 days | 97.2 days |

**Liquidity — long-term / solvency**
| Ratio | Formula | 2022 | 2023 | 2024 |
|-------|---------|------|------|------|
| Capital gearing ratio | Long-term borrowings / (Long-term borrowings + Equity) | 60.8% | 60.0% | 59.6% |

**Ratios to REMOVE** (not in Melville Ch.22):
- Operating margin
- Return on Assets (ROA)
- Return on Equity (ROE)
- Gearing (net debt / equity)
- Interest coverage
- Debt-to-assets

---

## Task 1: Rewrite the Ratios sheet in Excel

**Files:**
- Modify: `FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx` — Sheet 4 (Ratios)

- [ ] **Step 1: Write the script**

Create `/home/zo/University/FA583/scripts/update_ratios_sheet.py`:

```python
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

wb = openpyxl.load_workbook(
    "/home/zo/University/FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx"
)

# ── grab source data from existing sheets ──────────────────────────────────
is_ws = wb["Income Statement"]
bs_ws = wb["Balance Sheet"]

# Income Statement references (row numbers from the sheet as-is)
# Revenue: row 5, Cost of sales: row 6, Gross profit: row 7, EBIT: row 11
# Net profit (shareholders): row 19
revenue      = {2022: is_ws["B5"].value, 2023: is_ws["C5"].value, 2024: is_ws["D5"].value}
cos          = {2022: abs(is_ws["B6"].value), 2023: abs(is_ws["C6"].value), 2024: abs(is_ws["D6"].value)}
gross_profit = {2022: is_ws["B7"].value, 2023: is_ws["C7"].value, 2024: is_ws["D7"].value}
ebit         = {2022: is_ws["B11"].value, 2023: is_ws["C11"].value, 2024: is_ws["D11"].value}
net_profit   = {2022: is_ws["B19"].value, 2023: is_ws["C19"].value, 2024: is_ws["D19"].value}

# Balance Sheet references
# Total assets: row 17, Current assets: row 15, Current liabilities: row 22
# Inventories: row 11, Trade receivables: row 12
# Long-term borrowings: row 27, Shareholders equity: row 32
total_assets  = {2022: bs_ws["B17"].value, 2023: bs_ws["C17"].value, 2024: bs_ws["D17"].value}
curr_assets   = {2022: bs_ws["B15"].value, 2023: bs_ws["C15"].value, 2024: bs_ws["D15"].value}
curr_liab     = {2022: bs_ws["B22"].value, 2023: bs_ws["C22"].value, 2024: bs_ws["D22"].value}
inventories   = {2022: bs_ws["B11"].value, 2023: bs_ws["C11"].value, 2024: bs_ws["D11"].value}
trade_rec     = {2022: bs_ws["B12"].value, 2023: bs_ws["C12"].value, 2024: bs_ws["D12"].value}
lt_borrowings = {2022: bs_ws["B27"].value, 2023: bs_ws["C27"].value, 2024: bs_ws["D27"].value}
equity        = {2022: bs_ws["B32"].value, 2023: bs_ws["C32"].value, 2024: bs_ws["D32"].value}

years = [2022, 2023, 2024]

def roce(y):
    return ebit[y] / (total_assets[y] - curr_liab[y])

def gpm(y):
    return gross_profit[y] / revenue[y]

def npm(y):
    return net_profit[y] / revenue[y]

def current_ratio(y):
    return curr_assets[y] / curr_liab[y]

def quick_ratio(y):
    return (curr_assets[y] - inventories[y]) / curr_liab[y]

def inv_days(y):
    return (inventories[y] / cos[y]) * 365

def rec_days(y):
    return (trade_rec[y] / revenue[y]) * 365

def cap_gearing(y):
    return lt_borrowings[y] / (lt_borrowings[y] + equity[y])

# ── rebuild ratios sheet ───────────────────────────────────────────────────
ws = wb["Ratios"]
ws.delete_rows(1, ws.max_row)   # clear everything

# ── styles ────────────────────────────────────────────────────────────────
BLUE   = PatternFill("solid", fgColor="1F3864")   # dark navy — section headers
LGREY  = PatternFill("solid", fgColor="D9E1F2")   # light blue-grey — alt rows
WHITE  = PatternFill("solid", fgColor="FFFFFF")
HDR_FG = Font(bold=True, color="FFFFFF", size=11)
SEC_FG = Font(bold=True, color="FFFFFF", size=10)
BODY   = Font(name="Calibri", size=10)
BOLD   = Font(name="Calibri", bold=True, size=10)
CENTER = Alignment(horizontal="center", vertical="center")
LEFT   = Alignment(horizontal="left",   vertical="center")

def thin_border():
    s = Side(style="thin", color="BFBFBF")
    return Border(left=s, right=s, top=s, bottom=s)

def write(ws, row, col, val, font=None, fill=None, align=None, num_fmt=None):
    c = ws.cell(row=row, column=col, value=val)
    if font:    c.font    = font
    if fill:    c.fill    = fill
    if align:   c.alignment = align
    if num_fmt: c.number_format = num_fmt
    c.border = thin_border()
    return c

# ── title ─────────────────────────────────────────────────────────────────
ws.merge_cells("A1:F1")
t = ws["A1"]
t.value = "RELX PLC — Financial Ratio Analysis (£m)"
t.font  = Font(bold=True, color="FFFFFF", size=12)
t.fill  = BLUE
t.alignment = CENTER

ws.merge_cells("A2:F2")
s = ws["A2"]
s.value = "Source: Melville, A. (2019) International Financial Reporting, 7th ed., Ch.22 | Data: RELX Annual Reports 2022–2024"
s.font  = Font(italic=True, size=9, color="595959")
s.alignment = LEFT

# ── column headers ────────────────────────────────────────────────────────
headers = ["Ratio", "2022", "2023", "2024", "Formula", "Notes"]
for col, h in enumerate(headers, 1):
    write(ws, 3, col, h, font=HDR_FG, fill=BLUE, align=CENTER)

# ── helper: section header ────────────────────────────────────────────────
def section_header(ws, row, label):
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=6)
    c = ws.cell(row=row, column=1, value=label)
    c.font = SEC_FG
    c.fill = PatternFill("solid", fgColor="2E5496")   # mid-blue
    c.alignment = LEFT
    c.border = thin_border()

# ── data rows ─────────────────────────────────────────────────────────────
PCT  = "0.0%"
XFMT = '0.00"x"'
DFMT = '0.0" days"'

rows = [
    # (label, [vals by year], formula_str, note, fmt)
    ("PROFITABILITY", None, None, None, None),
    ("ROCE",
     [roce(y)  for y in years],
     "EBIT / (Total assets − Current liabilities)",
     "Capital employed = total assets less current liabilities",
     PCT),
    ("Gross profit margin",
     [gpm(y)   for y in years],
     "Gross profit / Revenue",
     "Stable ~65% — subscription cost base is predictable",
     PCT),
    ("Net profit margin",
     [npm(y)   for y in years],
     "Net profit (attrib. to shareholders) / Revenue",
     "Improved despite UK tax rise to 25% (Apr 2023)",
     PCT),
    ("LIQUIDITY — SHORT-TERM", None, None, None, None),
    ("Current ratio",
     [current_ratio(y) for y in years],
     "Current assets / Current liabilities",
     "Below 1.0x — structural: ~£4bn deferred subscription income in CL",
     XFMT),
    ("Quick assets ratio (acid test)",
     [quick_ratio(y) for y in years],
     "(Current assets − Inventories) / Current liabilities",
     "Closely tracks current ratio — minimal inventory effect",
     XFMT),
    ("Inventory holding period",
     [inv_days(y) for y in years],
     "(Inventories / Cost of sales) × 365",
     "Stable ~37 days — mainly physical exhibition/print inventory",
     DFMT),
    ("Trade receivables collection period",
     [rec_days(y) for y in years],
     "(Trade receivables / Revenue) × 365",
     "Long but improving — B2B enterprise clients on annual contracts",
     DFMT),
    ("LIQUIDITY — LONG-TERM / SOLVENCY", None, None, None, None),
    ("Capital gearing ratio",
     [cap_gearing(y) for y in years],
     "Long-term borrowings / (Long-term borrowings + Equity)",
     "Elevated but slowly declining; equity base partly intangible",
     PCT),
]

data_row = 4
for item in rows:
    label, vals, formula, note, fmt = item
    if vals is None:
        section_header(ws, data_row, label)
    else:
        fill = LGREY if (data_row % 2 == 0) else WHITE
        write(ws, data_row, 1, label,   font=BODY, fill=fill, align=LEFT)
        for i, v in enumerate(vals):
            write(ws, data_row, 2+i, v, font=BODY, fill=fill, align=CENTER, num_fmt=fmt)
        write(ws, data_row, 5, formula, font=BODY, fill=fill, align=LEFT)
        write(ws, data_row, 6, note,    font=BODY, fill=fill, align=LEFT)
    data_row += 1

# ── column widths ─────────────────────────────────────────────────────────
ws.column_dimensions["A"].width = 36
ws.column_dimensions["B"].width = 10
ws.column_dimensions["C"].width = 10
ws.column_dimensions["D"].width = 10
ws.column_dimensions["E"].width = 44
ws.column_dimensions["F"].width = 50

# ── row heights ───────────────────────────────────────────────────────────
ws.row_dimensions[1].height = 22
ws.row_dimensions[2].height = 14
ws.row_dimensions[3].height = 18
for r in range(4, data_row):
    ws.row_dimensions[r].height = 16

# ── freeze panes below header ─────────────────────────────────────────────
ws.freeze_panes = "A4"

wb.save("/home/zo/University/FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx")
print("Ratios sheet written OK")
```

- [ ] **Step 2: Create scripts directory and run**

```bash
mkdir -p /home/zo/University/FA583/scripts
python3 /home/zo/University/FA583/scripts/update_ratios_sheet.py
```

Expected: `Ratios sheet written OK`

- [ ] **Step 3: Open the file and verify**

Open `/home/zo/University/FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx` in Excel/LibreOffice.

Check:
- Ratios sheet has exactly 8 data rows (ROCE, GPM, NPM, Current, Quick, Inventory days, Receivables days, Capital gearing)
- Section headers visible in mid-blue
- All values match the reference table at the top of this plan
- Number formats correct (%, x, days)

- [ ] **Step 4: Commit**

```bash
cd /home/zo/University
git add FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx FA583/scripts/update_ratios_sheet.py
git commit -m "fa583: rewrite ratios sheet with 8 Melville Ch.22 ratios"
```

---

## Task 2: Apply consistent presentation to all 4 Excel sheets

**Files:**
- Modify: `FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx` — all 4 sheets

- [ ] **Step 1: Write the presentation script**

Create `/home/zo/University/FA583/scripts/format_excel.py`:

```python
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

PATH = "/home/zo/University/FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx"
wb = openpyxl.load_workbook(PATH)

NAVY  = PatternFill("solid", fgColor="1F3864")
MID   = PatternFill("solid", fgColor="2E5496")
LGREY = PatternFill("solid", fgColor="D9E1F2")
WHITE = PatternFill("solid", fgColor="FFFFFF")
HDR_F = Font(bold=True, color="FFFFFF", size=11)
BODY  = Font(name="Calibri", size=10)

def thin():
    s = Side(style="thin", color="BFBFBF")
    return Border(left=s, right=s, top=s, bottom=s)

def style_sheet(ws, title, col_widths):
    """Apply consistent styling: title row, header row, alt-row shading, borders."""
    # Row 1 — title
    ws.row_dimensions[1].height = 20
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF", size=12)
        cell.fill = NAVY
        cell.alignment = Alignment(horizontal="left", vertical="center")
        cell.border = thin()

    # Row 2 — source (italic grey)
    ws.row_dimensions[2].height = 13
    for cell in ws[2]:
        cell.font = Font(italic=True, size=9, color="595959")
        cell.alignment = Alignment(horizontal="left", vertical="center")

    # Row 3 (blank) — skip if present
    # Row 4 — column headers
    for row in ws.iter_rows(min_row=4, max_row=4):
        for cell in row:
            if cell.value:
                cell.font = HDR_F
                cell.fill = NAVY
                cell.alignment = Alignment(horizontal="center", vertical="center")
                cell.border = thin()
                ws.row_dimensions[4].height = 16

    # Rows 5+ — data with alt shading
    for i, row in enumerate(ws.iter_rows(min_row=5, max_row=ws.max_row)):
        fill = LGREY if i % 2 == 0 else WHITE
        is_section = all(
            cell.value is None or (col == 0 and isinstance(cell.value, str) and
            cell.value.isupper())
            for col, cell in enumerate(row)
        )
        for cell in row:
            if cell.font and cell.font.bold and cell.fill and cell.fill.fgColor.rgb in ("FF2E5496", "FF1F3864"):
                pass  # already styled (section headers from Task 1 ratios sheet)
            else:
                cell.font = BODY
                cell.fill = fill
                cell.alignment = Alignment(horizontal="left" if cell.column == 1 else "center",
                                           vertical="center")
                cell.border = thin()
        ws.row_dimensions[5 + i].height = 15

    # Column widths
    for col_letter, width in col_widths.items():
        ws.column_dimensions[col_letter].width = width

    # Freeze panes below header
    ws.freeze_panes = "B5"

# ── Income Statement ───────────────────────────────────────────────────────
style_sheet(wb["Income Statement"], "Income Statement", {
    "A": 36, "B": 12, "C": 12, "D": 12, "E": 30
})
# Format number cells as comma-separated integers
for row in wb["Income Statement"].iter_rows(min_row=5, max_row=22, min_col=2, max_col=4):
    for cell in row:
        if isinstance(cell.value, (int, float)):
            cell.number_format = '#,##0'

# ── Balance Sheet ──────────────────────────────────────────────────────────
style_sheet(wb["Balance Sheet"], "Balance Sheet", {
    "A": 36, "B": 12, "C": 12, "D": 12, "E": 30
})
for row in wb["Balance Sheet"].iter_rows(min_row=5, max_row=37, min_col=2, max_col=4):
    for cell in row:
        if isinstance(cell.value, (int, float)):
            cell.number_format = '#,##0'

# ── Cash Flow ──────────────────────────────────────────────────────────────
style_sheet(wb["Cash Flow"], "Cash Flow Statement", {
    "A": 40, "B": 12, "C": 12, "D": 12
})
for row in wb["Cash Flow"].iter_rows(min_row=5, max_row=29, min_col=2, max_col=4):
    for cell in row:
        if isinstance(cell.value, (int, float)):
            cell.number_format = '#,##0'

# Note: Ratios sheet already fully styled by Task 1 script — skip here

wb.save(PATH)
print("All sheets formatted OK")
```

- [ ] **Step 2: Run the script**

```bash
python3 /home/zo/University/FA583/scripts/format_excel.py
```

Expected: `All sheets formatted OK`

- [ ] **Step 3: Verify visually**

Open the file. Check each sheet:
- Consistent navy header rows
- Alternating light-grey / white data rows
- Numbers with comma separators (no decimals for £m figures)
- Column widths are readable without text truncation

- [ ] **Step 4: Commit**

```bash
cd /home/zo/University
git add FA583/Admin/RELX_Financial_Analysis_FA583_FINAL.xlsx FA583/scripts/format_excel.py
git commit -m "fa583: apply consistent presentation formatting to all Excel sheets"
```

---

## Task 3: Rewrite the Word document

**Files:**
- Modify: `FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx`

This task rewrites: (a) both ratio tables, (b) the Profitability section analysis, (c) the Liquidity and Solvency section analysis, (d) the Conclusion. Humanizer principles are applied throughout — no AI vocabulary, no em dash overuse, no sycophantic phrasing, varied sentence rhythm, specific figures over vague claims.

- [ ] **Step 1: Write the rewrite script**

Create `/home/zo/University/FA583/scripts/rewrite_word.py`:

```python
from docx import Document
from docx.shared import Pt, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

PATH = "/home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx"
doc = Document(PATH)

# ─────────────────────────────────────────────────────────────────────────
# HELPER: clear a table and write new content
# ─────────────────────────────────────────────────────────────────────────
def set_cell(cell, text, bold=False, italic=False, size=10):
    cell.text = ""
    p = cell.paragraphs[0]
    run = p.add_run(text)
    run.bold = bold
    run.italic = italic
    run.font.size = Pt(size)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if bold else WD_ALIGN_PARAGRAPH.LEFT

def rebuild_table(table, headers, rows):
    """Overwrite an existing table with new headers and data rows."""
    # Expand or shrink rows as needed
    while len(table.rows) < len(rows) + 1:
        table.add_row()
    # Write headers
    for col_i, h in enumerate(headers):
        set_cell(table.rows[0].cells[col_i], h, bold=True)
    # Write data
    for row_i, row_data in enumerate(rows):
        for col_i, val in enumerate(row_data):
            set_cell(table.rows[row_i + 1].cells[col_i], val)

# ─────────────────────────────────────────────────────────────────────────
# TABLE 1 — Profitability Ratios (was 5 rows, now 3)
# The first table in the document is the profitability ratios table.
# ─────────────────────────────────────────────────────────────────────────
prof_headers = ["Ratio", "2022", "2023", "2024", "Formula"]
prof_rows = [
    ["ROCE",                "21.8%", "28.5%", "30.4%", "EBIT / (Total assets − Current liabilities)"],
    ["Gross profit margin", "64.4%", "64.9%", "65.0%", "Gross profit / Revenue"],
    ["Net profit margin",   "19.1%", "19.4%", "20.5%", "Net profit (attrib. shareholders) / Revenue"],
]

# ─────────────────────────────────────────────────────────────────────────
# TABLE 2 — Liquidity and Solvency Ratios (was 5 rows, now 5 rows — same count)
# ─────────────────────────────────────────────────────────────────────────
liq_headers = ["Ratio", "2022", "2023", "2024", "Formula"]
liq_rows = [
    ["Current ratio",                      "0.59x",     "0.52x",     "0.52x",     "Current assets / Current liabilities"],
    ["Quick assets ratio (acid test)",     "0.53x",     "0.46x",     "0.47x",     "(Current assets − Inventories) / Current liabilities"],
    ["Inventory holding period",           "37.1 days", "36.1 days", "36.6 days", "(Inventories / Cost of sales) × 365"],
    ["Trade receivables collection period","102.7 days","92.6 days", "97.2 days", "(Trade receivables / Revenue) × 365"],
    ["Capital gearing ratio",              "60.8%",     "60.0%",     "59.6%",     "Long-term borrowings / (Long-term borrowings + Equity)"],
]

# Find and update both ratio tables
# Strategy: tables are found by scanning for the keyword in the first cell of row 0
ratio_tables = []
for tbl in doc.tables:
    first_cell = tbl.rows[0].cells[0].text.strip()
    if "Ratio" in first_cell or "ratio" in first_cell.lower():
        ratio_tables.append(tbl)

if len(ratio_tables) >= 2:
    rebuild_table(ratio_tables[0], prof_headers, prof_rows)
    rebuild_table(ratio_tables[1], liq_headers, liq_rows)
    print("Tables updated OK")
else:
    print(f"WARNING: found {len(ratio_tables)} ratio tables — expected 2. Manual check needed.")

# ─────────────────────────────────────────────────────────────────────────
# PROSE SECTIONS — replace paragraph text by section heading
# Strategy: find the heading paragraph, then replace the following paragraphs
# until the next heading.
# ─────────────────────────────────────────────────────────────────────────

PROFITABILITY_TEXT = """RELX's ROCE rose from 21.8% in 2022 to 30.4% in 2024. That 8.6 percentage point improvement reflects genuine operational progress — the Risk division grew faster than the group average and carries higher margins, so the revenue mix shift alone explains much of the gain. The subscription model also creates natural operating leverage: once content costs are covered, additional revenue drops almost entirely to profit.

Gross profit margin held at roughly 65% across all three years. For a business where the majority of products are digital databases and analytics platforms, this stability is the point — it confirms that content costs are scaling in line with revenue rather than running ahead of it.

Net profit margin improved from 19.1% to 20.5% despite the UK corporation tax rate rising from 19% to 25% in April 2023. A full six percentage points of additional tax and the margins still improved. That says something useful about how much operational headroom RELX has built into its cost structure."""

LIQUIDITY_TEXT = """The current ratio fell from 0.59x to 0.52x over the three years, and the quick assets ratio moved in parallel from 0.53x to 0.47x. Both sit well below the conventional 1.0x benchmark, which looks like a problem until you examine what sits inside the current liabilities figure. Around £4.1bn relates to deferred subscription income — cash RELX has already collected from clients for future periods. This liability will be settled through content delivery rather than cash payment, so the standard interpretation of the current ratio does not apply cleanly here. The ratios reflect the subscription model, not financial stress.

Inventory holding has been consistent at 36-37 days throughout the period. Given that the bulk of RELX's revenue comes from digital products, physical inventory is a relatively small part of the business — mostly exhibition materials and print publications. The stability of this figure confirms there have been no meaningful supply-side disruptions.

Trade receivables collection improved from 102.7 days in 2022 to 97.2 days in 2024. The absolute figure looks long, but RELX's customers are large institutions and governments on annual contracts. Payment terms of 90+ days are standard in this market. The direction of travel — a five-day improvement over two years — suggests tighter credit management.

The capital gearing ratio edged down from 60.8% to 59.6% between 2022 and 2024. The direction is right, but the absolute level stays elevated. One structural issue matters here: RELX's equity base of £3.5bn sits underneath £8.2bn of goodwill — almost entirely the legacy of past acquisitions. In a stress scenario, the quality of that equity would depend heavily on whether those acquisitions could be sold at book value, which is not certain."""

CONCLUSION_TEXT = """RELX's financial performance over 2022-2024 is strong on profitability and structurally complicated on liquidity. ROCE improved by nearly nine percentage points, margins held steady despite a significant tax change, and revenue grew at a 5% compound rate. These are the numbers of a well-run business with pricing power and a product mix that is genuinely difficult to replicate.

The liquidity picture requires more care in interpretation. The ratios that look most alarming — a current ratio of 0.52x, a quick ratio of 0.47x — are substantially explained by deferred subscription income sitting in current liabilities. That is not the same as a company running out of cash. Free cash flow of £3.0bn in 2024 tells a different story. Capital gearing at 60% with an intangible-heavy balance sheet is the more legitimate concern, and it is one the company itself acknowledges in its debt covenants and credit rating disclosures.

A key limitation of this analysis is that standard ratio analysis was not designed with subscription businesses in mind. The receivables figure, the deferred income position, and the goodwill-dominated asset base all make the ratios harder to read than they would be for a manufacturer or retailer. Used alongside divisional organic revenue data and cash conversion figures, the ratios presented here give a reasonable picture. Used in isolation, some would be misleading."""

def replace_section_prose(doc, heading_keyword, new_text):
    """Replace all Normal-style paragraphs immediately following a heading
    that contains heading_keyword with the new_text paragraphs."""
    found_heading = False
    paras_to_replace = []

    for i, para in enumerate(doc.paragraphs):
        if heading_keyword.lower() in para.text.lower() and para.style.name.startswith("Heading"):
            found_heading = True
            heading_index = i
            continue
        if found_heading:
            if para.style.name.startswith("Heading"):
                break
            paras_to_replace.append(para)

    if not paras_to_replace:
        print(f"WARNING: no paragraphs found under heading '{heading_keyword}'")
        return

    # Replace text of first paragraph; clear the rest
    new_paras = [p.strip() for p in new_text.strip().split("\n\n") if p.strip()]

    # Set text in existing paragraphs; add more if needed
    for j, para in enumerate(paras_to_replace):
        if j < len(new_paras):
            para.clear()
            run = para.add_run(new_paras[j])
            run.font.size = Pt(11)
        else:
            # Remove extra paragraphs by clearing them
            para.clear()

    # If we need more paragraphs than exist, insert them after the last replaced
    if len(new_paras) > len(paras_to_replace):
        last_para = paras_to_replace[-1]
        for extra_text in new_paras[len(paras_to_replace):]:
            new_p = OxmlElement('w:p')
            last_para._element.addnext(new_p)
            new_para = last_para.__class__(new_p, last_para._parent)
            run = new_para.add_run(extra_text)
            run.font.size = Pt(11)
            last_para = new_para

    print(f"Section '{heading_keyword}' updated OK")

replace_section_prose(doc, "Profitability", PROFITABILITY_TEXT)
replace_section_prose(doc, "Liquidity", LIQUIDITY_TEXT)
replace_section_prose(doc, "Conclusion", CONCLUSION_TEXT)

doc.save(PATH)
print("Word document saved OK")
```

- [ ] **Step 2: Run the script**

```bash
python3 /home/zo/University/FA583/scripts/rewrite_word.py
```

Expected output:
```
Tables updated OK
Section 'Profitability' updated OK
Section 'Liquidity' updated OK
Section 'Conclusion' updated OK
Word document saved OK
```

- [ ] **Step 3: Verify the document**

Open `/home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx`. Check:

- Table 1 (Profitability) has 3 data rows: ROCE, Gross profit margin, Net profit margin
- Table 2 (Liquidity) has 5 data rows: Current ratio, Quick assets ratio, Inventory holding period, Trade receivables collection period, Capital gearing ratio
- ROCE values read 21.8%, 28.5%, 30.4%
- Capital gearing reads 60.8%, 60.0%, 59.6%
- Profitability prose does NOT mention ROA, ROE, or operating margin
- Liquidity prose does NOT mention interest coverage or net debt/equity
- Word count of the whole document is approximately 1,000 words (check with Word's word count tool)

If the table update fails (tables not found by the script), update manually:
- Replace Table 1 rows with ROCE / Gross profit margin / Net profit margin rows
- Replace Table 2 rows with the 5 liquidity rows listed above

- [ ] **Step 4: Commit**

```bash
cd /home/zo/University
git add FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx FA583/scripts/rewrite_word.py
git commit -m "fa583: update Word submission — Melville ratios, humanized prose"
```

---

## Task 4: Final check against brief requirements

Before submitting, run through this checklist manually:

- [ ] Total ratios in submission = 8 (no more, no fewer unless deliberately adding extras)
- [ ] Profitability ratios ≥ 3: ROCE, Gross profit margin, Net profit margin ✓
- [ ] Liquidity ratios ≥ 3: Current ratio, Quick ratio, Inventory days, Receivables days, Capital gearing ✓
- [ ] All 8 ratios can be found in Melville Ch.22 ✓
- [ ] Three years of data (2022, 2023, 2024) present in both Excel and Word tables ✓
- [ ] Word document ~1,000 words ✓
- [ ] No references to ROA, ROE, operating margin, interest coverage, or net debt/equity in the prose ✓
- [ ] Excel Ratios sheet formula column matches Melville's exact formula descriptions ✓
- [ ] References section in Word still includes Melville (2019) ✓

---

## Ratio reference card (keep this handy during execution)

| # | Ratio | Melville formula | 2022 | 2023 | 2024 |
|---|-------|-----------------|------|------|------|
| 1 | ROCE | EBIT / (Total assets − CL) | 21.8% | 28.5% | 30.4% |
| 2 | Gross profit margin | Gross profit / Revenue | 64.4% | 64.9% | 65.0% |
| 3 | Net profit margin | Net profit / Revenue | 19.1% | 19.4% | 20.5% |
| 4 | Current ratio | CA / CL | 0.59x | 0.52x | 0.52x |
| 5 | Quick assets ratio | (CA − Inv) / CL | 0.53x | 0.46x | 0.47x |
| 6 | Inventory holding period | (Inv / CoS) × 365 | 37.1d | 36.1d | 36.6d |
| 7 | Trade receivables collection | (Rec / Rev) × 365 | 102.7d | 92.6d | 97.2d |
| 8 | Capital gearing ratio | LT debt / (LT debt + Equity) | 60.8% | 60.0% | 59.6% |
