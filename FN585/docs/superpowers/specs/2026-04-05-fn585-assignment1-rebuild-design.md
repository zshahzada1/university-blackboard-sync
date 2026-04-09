# FN585 Assignment 1 — Full Rebuild Design Spec
**Date:** 2026-04-05
**Deadline:** 2026-04-06
**Target:** High First Class (>80%)

---

## Goal

Rebuild FN585 Assignment 1 (Time Series & Forecasting) entirely from scratch to high first-class standard. Two outputs: a polished `.docx` converted to PDF via LibreOffice. Written analysis passes humanizer + Wikipedia AI writing guide checks.

---

## Marking Rubric Targets

| Component | Weight | Target |
|---|---|---|
| Data Management & Manipulation | 40% | Exceptional — all steps clearly explained, clean reproducible code |
| Statistical Methods Application | 40% | Excellent — correct interpretation, all three stationarity levels, BIC model selection |
| Presentation & Communication | 20% | Excellent — professional tables, captions, human-written prose |

---

## Section 1: R Analysis Script (`assignment1.r`)

Single script. Runs top to bottom. Saves all figures + `outputs/results.json`.

### Libraries
```r
library(AER)        # coeftest()
library(readxl)     # read_xlsx()
library(xts)        # xts(), time series subsetting
library(zoo)        # as.zoo(), as.yearqtr()
library(dynlm)      # dynlm(), L()
library(urca)       # ur.df() — unit root tests (as taught Weeks 6-7)
library(sandwich)   # vcovHAC()
library(lmtest)     # coeftest()
library(car)        # linearHypothesis() — joint F-test
library(jsonlite)   # toJSON() — save results
```

### Data Loading
- `read_xlsx("us_macro_quarterly.xlsx", sheet=1, col_types=c("text", rep("numeric",9)))`
- `as.yearqtr(date_col, format="%Y:0%q")` — exact format from Week 3 seminar
- `xts()` objects with `["YYYY::YYYY"]` subsetting throughout

### Q1 — Inflation Rate Construction & Plot (10 marks)
- `inflt <- xts(400 * log(PCECTPI / lag(PCECTPI)))["1963::2013"]`
- Base R plot via `plot(as.zoo(inflt), ...)` — matches template and seminar style
- Save as `figures/fig1_inflation.png` at 300 DPI

### Q2 — Autocovariance & ACF (10 marks)
- Autocovariance: `acf(na.omit(inflt), type="covariance", lag.max=20, plot=FALSE)` → plot
- Autocorrelation: `acf(na.omit(inflt), type="correlation", lag.max=20, plot=FALSE)` → plot
- Save as `fig2_autocovariance.png`, `fig3_acf_inflation.png`

### Q3 — First Differences (10 marks)
- `diff_inflt <- diff(inflt)`
- Plot of `diff_inflt`, ACF of `diff_inflt` (lag.max=20)
- Save as `fig4_diff_inflation.png`, `fig5_acf_diff_inflation.png`

### Q4 — Stationarity of inflt (10 marks)
- `ur.df(na.omit(inflt), type="none", selectlags="BIC")` — τ test
- `ur.df(na.omit(inflt), type="drift", selectlags="BIC")` — τ_μ test
- `ur.df(na.omit(inflt), type="trend", selectlags="BIC")` — τ_τ test
- Extract test statistic + critical values from each `summary()` output
- Decision: most appropriate spec is "drift" for inflation (as per Week 7 commentary)

### Q5 — Stationarity of Δinflt (10 marks)
- Same three `ur.df()` specs on `na.omit(diff_inflt)`
- "none" is most appropriate for differenced series (Week 7: "no constant/trend is best model")
- Confirm stationary: reject H₀

### Q6 — ACF of Unemployment Rate (5 marks)
- `uratet <- xts(urate_col)["1962::2004"]`
- `acf(na.omit(uratet), lag.max=20)` — plot first 20 autocorrelations
- Save as `fig6_acf_urate.png`

### Q7 — Stationarity of uratet (5 marks)
- `ur.df()` three specs on `na.omit(uratet)`
- "drift" most appropriate (near-unit root, persistent series)
- Save `fig7_urate.png`

### Q8 — Scatter: Δinflt vs lagged uratet (10 marks)
- `urate_lag1 <- lag(uratet)` aligned with `diff_inflt["1962::2004"]`
- `plot()` scatter with fitted OLS line
- Simple regression: `lm(diff_inflt ~ urate_lag1)` with `coeftest(vcovHAC)`
- Save as `fig8_scatter.png`

### Q9 — ADL(2,2) Model (30 marks: 25 + 5)

**Model estimation (training period: 1963:Q1–2004:Q4):**
```r
adl22 <- dynlm(ts(diff_inflt_train) ~
               L(ts(diff_inflt_train), 1) + L(ts(diff_inflt_train), 2) +
               L(ts(uratet_train), 1) + L(ts(uratet_train), 2))
adl22_hac <- coeftest(adl22, vcov.=vcovHAC)
```

**BIC grid (4×4 matrix, as Week 7):**
```r
bic_matrix <- matrix(nrow=4, ncol=4)
for(i in 1:4) for(j in 1:4) {
  m <- dynlm(ts(diff_inflt_train) ~ L(ts(diff_inflt_train), 1:i) + L(ts(uratet_train), 1:j))
  bic_matrix[i,j] <- BIC(m)
}
```

**Joint F-test:**
```r
linearHypothesis(adl22, c("L(ts(uratet_train), 1)=0", "L(ts(uratet_train), 2)=0"), vcov.=vcovHAC)
```

**Long-term effect:**
```r
lte <- (coef[4] + coef[5]) / (1 - coef[2] - coef[3])
```

### Q10 — Forecast Q1 2005 (5 marks)
```r
fcast_diff <- adl22$coefficients %*% c(1, diff_inflt[K], diff_inflt[K-1], uratet[K], uratet[K-1])
fcast_level <- inflt[K] + fcast_diff
```

### Results Export
All numerical results saved to `outputs/results.json` for use by docx builder.

---

## Section 2: Python docx Builder (`build_document.py`)

### Structure
```
Title / student info
Q1 → Q10 (numbered, sequential)
  - Written analysis (humanized, Arial 11pt, 1.5 line spacing)
  - Embedded figures with captions
  - Formatted Word tables (not raw R output)
References (Harvard)
Appendix: Full R code
```

### Formatting (exact per brief)
- Font: Arial, 11pt throughout
- Line spacing: 1.5
- Headings: numbered (1., 2., ..., 10.)
- Figures: numbered, self-sufficient captions
- Tables: rebuilt in `python-docx` table format

### Tables to Build
1. **ADL(2,2) Regression Results** — coefficients, robust SE, t-stats, p-values (standard + HAC cols)
2. **BIC Grid** — 4×4 ADL(p,q) comparison, minimum highlighted
3. **Q10 Lagged Values** — inputs used for forecast

### Written Analysis Standards
- Humanizer skill applied to all written sections
- Wikipedia AI writing guide checks: no em dashes, no "it is worth noting", no rule-of-three, no promotional hedging, no vague attributions, no excessive conjunctive phrases
- Economic interpretation grounded in Phillips curve literature
- References: Stock & Watson (2015), Friedman (1968), Phillips (1958), Granger & Newbold (1974)

### PDF Conversion
```bash
soffice --headless --convert-to pdf Assignment1_FINAL.docx
```

---

## Section 3: Post-Build Examiner Review

After PDF generation, a dedicated review pass checks:
- All 9 questions answered with three-level stationarity analysis where required
- No unfilled placeholders
- All figures embedded and captioned
- Tables professionally formatted (not raw software output)
- R code in appendix is complete and commented
- Written analysis reads as human-authored
- Rubric check: data management / statistical methods / presentation all at first-class level
- Flag any weaknesses before submission

---

## File Outputs
```
Assignment1/
├── assignment1.r           ← rebuilt R script
├── build_document.py       ← rebuilt docx builder
├── Assignment1_FINAL.docx  ← submission document
├── Assignment1_FINAL.pdf   ← final PDF
├── figures/                ← 8 PNG figures (300 DPI)
└── outputs/
    └── results.json        ← all numerical results
```
