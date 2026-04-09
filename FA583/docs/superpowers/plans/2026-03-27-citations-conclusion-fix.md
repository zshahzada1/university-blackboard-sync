# FA583 Harvard Citations + Conclusion Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Harvard author-date in-text citations throughout the Word document, add source notes under ratio tables, fix the final conclusion sentence, and re-upload to GoFile.

**Architecture:** Single python-docx script that modifies paragraphs and table captions in-place. One Bash upload step.

**Tech Stack:** Python 3, python-docx, curl

---

## Harvard citation reference (use these exact strings)

- `(RELX PLC, 2024)` — single year figures
- `(RELX PLC, 2022, 2023, 2024)` — three-year data
- `(RELX PLC, 2022, 2024)` — two-year comparison (start and end)
- `(Melville, 2019)` — ratio definitions/methodology

---

## Exact paragraph replacements with citations

### Section 1 — Company Profile

**Current paragraph 1:**
> RELX PLC is a FTSE 100 information analytics group, incorporated in England and listed in London, Amsterdam, and New York. It runs four divisions: Risk (data analytics and decision tools, around 35% of 2024 revenue), Scientific, Technical and Medical (academic publishing and databases, roughly 30%), Legal (LexisNexis, approximately 26%), and Exhibitions (trade shows, 9%). About 75% of revenue comes through subscriptions, which makes the top line fairly predictable and gives management more forward visibility than most businesses of comparable size. Its main competitors are Thomson Reuters, Wolters Kluwer, and Clarivate.

**New paragraph 1:**
> RELX PLC is a FTSE 100 information analytics group, incorporated in England and listed in London, Amsterdam, and New York (RELX PLC, 2024). It runs four divisions: Risk (data analytics and decision tools, around 35% of 2024 revenue), Scientific, Technical and Medical (academic publishing and databases, roughly 30%), Legal (LexisNexis, approximately 26%), and Exhibitions (trade shows, 9%) (RELX PLC, 2024). About 75% of revenue comes through subscriptions, which makes the top line fairly predictable and gives management more forward visibility than most businesses of comparable size. Its main competitors are Thomson Reuters, Wolters Kluwer, and Clarivate.

---

### Section 2 — Profitability

**Current paragraph 1:**
> RELX's ROCE rose from 21.8% in 2022 to 30.4% in 2024. That 8.6 percentage point improvement is driven mainly by the Risk division, which grew faster than the rest of the group and runs at higher margins. The subscription model helps too: once content costs are covered, incremental revenue flows through at margins well above the headline figures.

**New paragraph 1:**
> RELX's ROCE rose from 21.8% in 2022 to 30.4% in 2024 (RELX PLC, 2022, 2024). That 8.6 percentage point improvement is driven mainly by the Risk division, which grew faster than the rest of the group and runs at higher margins. The subscription model helps too: once content costs are covered, incremental revenue flows through at margins well above the headline figures.

**Current paragraph 2:**
> Gross profit margin held at roughly 65% across all three years. For a business where most products are digital databases and analytics platforms, this is the expected pattern. It means content costs are scaling with revenue, which is what you want to see.

**New paragraph 2:**
> Gross profit margin held at roughly 65% across all three years (RELX PLC, 2022, 2023, 2024). For a business where most products are digital databases and analytics platforms, this is the expected pattern. It means content costs are scaling with revenue, which is what you want to see.

**Current paragraph 3:**
> Net profit margin improved from 19.1% to 20.5% despite the UK corporation tax rate rising from 19% to 25% in April 2023. The tax change alone should have knocked about 1.5 points off the margin. That it did not reflects how much operating leverage RELX has built up over this period.

**New paragraph 3:**
> Net profit margin improved from 19.1% to 20.5% despite the UK corporation tax rate rising from 19% to 25% in April 2023 (RELX PLC, 2022, 2024). The tax change alone should have knocked about 1.5 points off the margin. That it did not reflects how much operating leverage RELX has built up over this period.

---

### Section 3 — Liquidity and Solvency

**Current paragraph 1:**
> The current ratio fell from 0.59x to 0.52x over the three years, and the quick assets ratio tracked it closely, dropping from 0.53x to 0.47x. Both sit below the 1.0x level typically cited as adequate. What matters is what sits inside the current liabilities figure: around £4.1bn of deferred subscription income, representing cash already collected for periods not yet delivered. That obligation gets settled with content, not cash outflows. Strip it out and both ratios look materially less concerning.

**New paragraph 1:**
> The current ratio fell from 0.59x to 0.52x over the three years, and the quick assets ratio tracked it closely, dropping from 0.53x to 0.47x (RELX PLC, 2022, 2024). Both sit below the 1.0x level typically cited as adequate (Melville, 2019). What matters is what sits inside the current liabilities figure: around £4.1bn of deferred subscription income, representing cash already collected for periods not yet delivered (RELX PLC, 2024). That obligation gets settled with content, not cash outflows. Strip it out and both ratios look materially less concerning.

**Current paragraph 2:**
> Inventory holding period stayed around 36-37 days throughout. Most of RELX's revenue comes from digital products, so physical inventory is a small part of operations, mainly exhibition materials and some print. The number barely moved, which is about what you would expect from a business with this kind of product mix.

**New paragraph 2:**
> Inventory holding period stayed around 36-37 days throughout (RELX PLC, 2022, 2023, 2024). Most of RELX's revenue comes from digital products, so physical inventory is a small part of operations, mainly exhibition materials and some print. The number barely moved, which is about what you would expect from a business with this kind of product mix.

**Current paragraph 3:**
> Trade receivables collection came down from 102.7 days in 2022 to 97.2 days in 2024. On its own, 97 days looks long. RELX sells to governments, universities, and large enterprises on annual contracts, where 90-day terms are normal. The five-day improvement over two years points to tighter collection discipline.

**New paragraph 3:**
> Trade receivables collection came down from 102.7 days in 2022 to 97.2 days in 2024 (RELX PLC, 2022, 2024). On its own, 97 days looks long. RELX sells to governments, universities, and large enterprises on annual contracts, where 90-day terms are normal. The five-day improvement over two years points to tighter collection discipline.

**Current paragraph 4:**
> Capital gearing edged down from 60.8% to 59.6% between 2022 and 2024. That marginal improvement is better than nothing, but 60% remains high leverage, particularly when most of the equity supporting it is goodwill — £8.2bn, accumulated from past acquisitions. Whether that goodwill holds its value under pressure is a question the ratios cannot answer.

**New paragraph 4:**
> Capital gearing edged down from 60.8% to 59.6% between 2022 and 2024 (RELX PLC, 2022, 2024). That marginal improvement is better than nothing, but 60% remains high leverage, particularly when most of the equity supporting it is goodwill — £8.2bn, accumulated from past acquisitions (RELX PLC, 2024). Whether that goodwill holds its value under pressure is a question the ratios cannot answer.

---

### Section 4 — Conclusion (last paragraph only)

**Current last paragraph:**
> Standard ratio analysis was built around tangible-asset businesses with clear distinctions between cash and non-cash obligations. RELX does not fit that model well. The deferred income complicates the liquidity picture; the goodwill complicates the gearing calculation. Read in isolation the numbers can mislead — read alongside organic revenue growth and cash conversion data from the annual reports, they make considerably more sense.

Wait — the last sentence was already fixed in the previous task. Check what is actually in the document first:

The paragraph ends with either:
- "Taken in isolation, the numbers can mislead." + "The full picture needs annual report commentary on organic revenue growth and cash conversion alongside them."

OR the earlier version. Regardless, replace the ENTIRE last paragraph of the Conclusion with:

> Standard ratio analysis was built around tangible-asset businesses with clear distinctions between cash and non-cash obligations. RELX does not fit that model well. The deferred income complicates the liquidity picture; the goodwill complicates the gearing calculation. Taken in isolation, the numbers can mislead. The ratios make more sense read alongside the company's own commentary on organic revenue growth and cash conversion — information that does not appear in the headline numbers (RELX PLC, 2022, 2023, 2024).

Strategy: find the paragraph in the Conclusion section that contains "tangible-asset" and replace the full paragraph text.

---

## Table source notes

Add a source note paragraph immediately after Table 1 (Profitability Ratios) and Table 2 (Liquidity and Solvency Ratios). The note should read:

`Source: Calculated from RELX PLC (2022, 2023, 2024). Ratio definitions: Melville (2019).`

Font: italic, size 9, same style as a caption.

---

## Task 1: Apply all changes to Word document

**Files:**
- Modify: `FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx`

- [ ] **Step 1: Write the script**

Create `/home/zo/University/FA583/scripts/add_citations.py`:

```python
from docx import Document
from docx.shared import Pt
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph

PATH = "/home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx"
doc = Document(PATH)

# ── Paragraph text replacements ───────────────────────────────────────────
# Map: unique substring to identify paragraph → full new text
REPLACEMENTS = {
    # Company Profile
    "RELX PLC is a FTSE 100 information analytics group, incorporated":
        "RELX PLC is a FTSE 100 information analytics group, incorporated in England and listed in London, Amsterdam, and New York (RELX PLC, 2024). It runs four divisions: Risk (data analytics and decision tools, around 35% of 2024 revenue), Scientific, Technical and Medical (academic publishing and databases, roughly 30%), Legal (LexisNexis, approximately 26%), and Exhibitions (trade shows, 9%) (RELX PLC, 2024). About 75% of revenue comes through subscriptions, which makes the top line fairly predictable and gives management more forward visibility than most businesses of comparable size. Its main competitors are Thomson Reuters, Wolters Kluwer, and Clarivate.",

    # Profitability §1
    "RELX's ROCE rose from 21.8% in 2022 to 30.4% in 2024":
        "RELX's ROCE rose from 21.8% in 2022 to 30.4% in 2024 (RELX PLC, 2022, 2024). That 8.6 percentage point improvement is driven mainly by the Risk division, which grew faster than the rest of the group and runs at higher margins. The subscription model helps too: once content costs are covered, incremental revenue flows through at margins well above the headline figures.",

    # Profitability §2
    "Gross profit margin held at roughly 65% across all three years":
        "Gross profit margin held at roughly 65% across all three years (RELX PLC, 2022, 2023, 2024). For a business where most products are digital databases and analytics platforms, this is the expected pattern. It means content costs are scaling with revenue, which is what you want to see.",

    # Profitability §3
    "Net profit margin improved from 19.1% to 20.5% despite the UK corporation tax rate":
        "Net profit margin improved from 19.1% to 20.5% despite the UK corporation tax rate rising from 19% to 25% in April 2023 (RELX PLC, 2022, 2024). The tax change alone should have knocked about 1.5 points off the margin. That it did not reflects how much operating leverage RELX has built up over this period.",

    # Liquidity §1
    "The current ratio fell from 0.59x to 0.52x over the three years":
        "The current ratio fell from 0.59x to 0.52x over the three years, and the quick assets ratio tracked it closely, dropping from 0.53x to 0.47x (RELX PLC, 2022, 2024). Both sit below the 1.0x level typically cited as adequate (Melville, 2019). What matters is what sits inside the current liabilities figure: around \u00a34.1bn of deferred subscription income, representing cash already collected for periods not yet delivered (RELX PLC, 2024). That obligation gets settled with content, not cash outflows. Strip it out and both ratios look materially less concerning.",

    # Liquidity §2
    "Inventory holding period stayed around 36-37 days throughout":
        "Inventory holding period stayed around 36-37 days throughout (RELX PLC, 2022, 2023, 2024). Most of RELX's revenue comes from digital products, so physical inventory is a small part of operations, mainly exhibition materials and some print. The number barely moved, which is about what you would expect from a business with this kind of product mix.",

    # Liquidity §3
    "Trade receivables collection came down from 102.7 days in 2022 to 97.2 days in 2024":
        "Trade receivables collection came down from 102.7 days in 2022 to 97.2 days in 2024 (RELX PLC, 2022, 2024). On its own, 97 days looks long. RELX sells to governments, universities, and large enterprises on annual contracts, where 90-day terms are normal. The five-day improvement over two years points to tighter collection discipline.",

    # Liquidity §4
    "Capital gearing edged down from 60.8% to 59.6% between 2022 and 2024":
        "Capital gearing edged down from 60.8% to 59.6% between 2022 and 2024 (RELX PLC, 2022, 2024). That marginal improvement is better than nothing, but 60% remains high leverage, particularly when most of the equity supporting it is goodwill \u2014 \u00a38.2bn, accumulated from past acquisitions (RELX PLC, 2024). Whether that goodwill holds its value under pressure is a question the ratios cannot answer.",

    # Conclusion — last paragraph (match on "tangible-asset" which is unique)
    "tangible-asset businesses":
        "Standard ratio analysis was built around tangible-asset businesses with clear distinctions between cash and non-cash obligations. RELX does not fit that model well. The deferred income complicates the liquidity picture; the goodwill complicates the gearing calculation. Taken in isolation, the numbers can mislead. The ratios make more sense read alongside the company\u2019s own commentary on organic revenue growth and cash conversion \u2014 information that does not appear in the headline numbers (RELX PLC, 2022, 2023, 2024).",
}

# Also handle the split conclusion sentences from previous task
# (in case the paragraph was split into "Taken in isolation..." + "The full picture...")
SPLIT_PARA_MARKER = "Taken in isolation, the numbers can mislead."
SPLIT_FOLLOW = "The full picture needs annual report commentary"

changed = set()
paras_to_delete = []

for para in doc.paragraphs:
    text = para.text.strip()

    # Check replacements
    for key, new_text in REPLACEMENTS.items():
        if key in text and key not in changed:
            para.clear()
            run = para.add_run(new_text)
            run.font.size = Pt(11)
            changed.add(key)
            print(f"Updated: {key[:50]}...")
            break

    # Mark the orphan "The full picture..." paragraph for deletion
    if SPLIT_FOLLOW in text and SPLIT_PARA_MARKER not in text:
        paras_to_delete.append(para)

# Remove orphan paragraphs
for para in paras_to_delete:
    para._element.getparent().remove(para._element)
    print("Removed orphan paragraph: The full picture needs...")

# ── Add source notes after ratio tables ──────────────────────────────────
SOURCE_NOTE = "Source: Calculated from RELX PLC (2022, 2023, 2024). Ratio definitions: Melville (2019)."

def add_note_after_table(tbl):
    """Insert an italic caption paragraph immediately after this table."""
    new_p = OxmlElement("w:p")
    tbl._tbl.addnext(new_p)
    para = Paragraph(new_p, tbl._tbl.getparent())
    run = para.add_run(SOURCE_NOTE)
    run.font.size = Pt(9)
    run.font.italic = True

# Find Table 1 (Profitability — has ROCE) and Table 2 (Liquidity — has Current ratio)
# Only add notes to tables that don't already have source notes after them
ratio_tables = []
for tbl in doc.tables:
    all_text = " ".join(c.text for row in tbl.rows for c in row.cells)
    if "ROCE" in all_text and "Gross profit margin" in all_text and "Capital gearing" not in all_text:
        ratio_tables.append(("Table 1 (Profitability)", tbl))
    elif "Current ratio" in all_text and "Capital gearing" in all_text and "ROCE" not in all_text:
        ratio_tables.append(("Table 2 (Liquidity)", tbl))

for label, tbl in ratio_tables:
    add_note_after_table(tbl)
    print(f"Added source note after {label}")

doc.save(PATH)
print("Saved:", PATH)
```

- [ ] **Step 2: Run the script**

```bash
python3 /home/zo/University/FA583/scripts/add_citations.py
```

Expected output:
```
Updated: RELX PLC is a FTSE 100 information analytics group...
Updated: RELX's ROCE rose from 21.8% in 2022 to 30.4%...
Updated: Gross profit margin held at roughly 65%...
Updated: Net profit margin improved from 19.1% to 20.5%...
Updated: The current ratio fell from 0.59x to 0.52x...
Updated: Inventory holding period stayed around 36-37 days...
Updated: Trade receivables collection came down from 102.7 days...
Updated: Capital gearing edged down from 60.8% to 59.6%...
Updated: tangible-asset businesses...
Added source note after Table 1 (Profitability)
Added source note after Table 2 (Liquidity)
Saved: /home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx
```

- [ ] **Step 3: Verify**

```python
from docx import Document

doc = Document("/home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx")
full = " ".join(p.text for p in doc.paragraphs)

checks = [
    ("(RELX PLC, 2024)", True),
    ("(RELX PLC, 2022, 2024)", True),
    ("(RELX PLC, 2022, 2023, 2024)", True),
    ("(Melville, 2019)", True),
    ("does not appear in the headline numbers (RELX PLC, 2022, 2023, 2024)", True),
    ("The full picture needs annual report commentary", False),  # should be gone
    ("Taken in isolation, the numbers can mislead.", True),
]

for text, should_exist in checks:
    present = text in full
    status = "OK" if present == should_exist else "FAIL"
    print(f"  [{status}] {'present' if should_exist else 'absent'}: {text[:70]}")

# Check source notes
source_note = "Source: Calculated from RELX PLC (2022, 2023, 2024). Ratio definitions: Melville (2019)."
count = full.count(source_note)
print(f"\n  Source notes added: {count} (expect 2)")
```

- [ ] **Step 4: Copy to coursework directory**

```bash
cp "/home/zo/University/FA583/Admin/RELX_FA583_FINAL_SUBMISSION.docx" \
   "/home/zo/University/FA583/coursework/RELX_FA583_FINAL_SUBMISSION.docx"
```

---

## Task 2: Upload Word doc only to GoFile

Only the Word doc is submitted now (professor confirmed single file).

- [ ] **Step 1: Upload**

```bash
RESPONSE=$(curl -s \
  -F "file=@/home/zo/University/FA583/coursework/RELX_FA583_FINAL_SUBMISSION.docx" \
  https://store-eu-par-4.gofile.io/contents/uploadfile)
LINK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['downloadPage'])")
echo "Download link: $LINK"
```

- [ ] **Step 2: Return link to user**

Print the GoFile download link clearly.
