# FN585 Assignment 1 Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement examiner feedback by adding a joint F-test to Q9, reordering Q1 narrative, adding R-squared analysis to Q8, and ensuring strict formatting compliance.

**Architecture:** Modify the R script to calculate and output the Q8 R-squared and the ADL(2,2) joint F-test. Then, update `build_document.py` to integrate these new statistical results and narrative improvements into the final Word document.

**Tech Stack:** R, Python (`python-docx`)

---

### Task 1: Update `run_analysis.r` to output Q8 R-squared

**Files:**
- Modify: `University/FN585/Assignment1/run_analysis.r`

- [ ] **Step 1: Calculate R-squared for Q8**

Modify `run_analysis.r` to extract the R-squared from the Q8 linear model and add it to the results list.

- [ ] **Step 2: Add `q8_rsq` to the JSON output list**

### Task 2: Reorder Q1 Narrative in `build_document.py`

**Files:**
- Modify: `University/FN585/Assignment1/build_document.py`

- [ ] **Step 1: Replace Q1 text blocks**

In `build_document.py`, replace the two `add_para` calls for Q1 to describe the plot first, then the stationarity criteria.

### Task 3: Enhance Q8 Narrative with R-squared in `build_document.py`

**Files:**
- Modify: `University/FN585/Assignment1/build_document.py`

- [ ] **Step 1: Update the second paragraph of Q8**

In `build_document.py`, replace the second `add_para` for Q8 with the text that includes the $R^2$ analysis.

### Task 4: Add Joint F-test to Q9 in `build_document.py`

**Files:**
- Modify: `University/FN585/Assignment1/build_document.py`

- [ ] **Step 1: Insert Joint F-test discussion**

In `build_document.py`, after the ADL(2,2) model results and before the AIC/BIC table, add a new paragraph addressing the joint significance of the unemployment lags.

### Task 5: Run Scripts to Generate Final Document

**Files:**
- Run: Shell commands

- [ ] **Step 1: Run the R script**
- [ ] **Step 2: Run `build_document.py` to generate the new Word document**
