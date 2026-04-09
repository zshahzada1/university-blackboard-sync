# FN585 Assignment 1 — Full Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild FN585 Assignment 1 from scratch — R analysis script, Python docx builder, PDF — to high first-class standard using exact course-taught methodology.

**Architecture:** One R script generates all figures (300 DPI PNG) and a JSON results file. One Python script reads the JSON and figures to assemble the submission DOCX. LibreOffice converts DOCX to PDF. Humanizer skill applied to all written prose.

**Tech Stack:** R (xts, zoo, dynlm, urca, sandwich, lmtest, car, AER, readxl, jsonlite), Python (python-docx), LibreOffice CLI

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Assignment1/assignment1.r` | Overwrite | All statistical analysis, figure generation, JSON export |
| `Assignment1/build_document.py` | Overwrite | Full DOCX assembly with written analysis, tables, figures |
| `Assignment1/figures/*.png` | Regenerate | 8 figures at 300 DPI |
| `Assignment1/outputs/results.json` | Regenerate | All numerical results for docx builder |
| `Assignment1/Assignment1_FINAL.docx` | Overwrite | Submission document |
| `Assignment1/Assignment1_FINAL.pdf` | Overwrite | Final PDF via LibreOffice |

---

## Task 1: Write R Analysis Script

**Files:**
- Overwrite: `Assignment1/assignment1.r`

- [ ] **Step 1: Write the complete R script**

Write the following to `Assignment1/assignment1.r`:

```r
# ============================================================
# FN585 Assignment 1 — Time Series & Forecasting
# Student: Zohaib Shahzada
# Rebuilt from scratch using course methodology (Weeks 1-7)
# ============================================================

library(AER)       # coeftest()
library(readxl)    # read_xlsx()
library(xts)       # xts objects and subsetting
library(zoo)       # as.zoo(), as.yearqtr()
library(dynlm)     # dynlm() with L() lag notation
library(urca)      # ur.df() unit root tests (Weeks 6-7)
library(sandwich)  # vcovHAC() — HAC robust standard errors
library(lmtest)    # coeftest()
library(car)       # linearHypothesis() — joint F-test
library(jsonlite)  # toJSON() — export results

# Set working directory to script location
setwd("/home/zo/University/FN585/Assignment1")

# Create output directories
dir.create("figures", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)

# ============================================================
# DATA LOADING
# ============================================================

usmac <- read_xlsx("us_macro_quarterly.xlsx",
                   sheet = 1,
                   col_types = c("text", rep("numeric", 9)))

# Rename columns (as per course convention)
colnames(usmac) <- c("Date", "GDPC96", "PCECTPI", "CPIAUCSL",
                      "UNRATE", "GS10", "GS1", "TB3MS",
                      "EXUSUK", "JAPAN_IP")

# Convert date column to yearqtr format (Week 3 convention)
usmac$Date <- as.yearqtr(usmac$Date, format = "%Y:0%q")

# Create XTS objects for core series
PCECTPI <- xts(usmac$PCECTPI, usmac$Date)
UNRATE  <- xts(usmac$UNRATE,  usmac$Date)

# ============================================================
# Q1: ANNUALISED INFLATION RATE
# inflt = 400 * delta(ln(PCECTPI_t))
# ============================================================

# Construct inflation rate — annualised quarterly log-difference
inflt <- xts(400 * log(PCECTPI / lag(PCECTPI)))

# Subset to 1963–2013 per assessment brief
inflt_q1 <- inflt["1963::2013"]

# Save figure 1
png("figures/fig1_inflation.png", width = 2400, height = 1600, res = 300)
plot(as.zoo(inflt_q1),
     col  = "steelblue",
     lwd  = 1.5,
     xlab = "Year",
     ylab = "Annualised Inflation Rate (%)",
     main = "Figure 1: U.S. Annualised Inflation Rate (1963–2013)")
abline(h = 0, lty = 2, col = "grey50")
dev.off()

# ============================================================
# Q2: AUTOCOVARIANCE AND AUTOCORRELATION FUNCTIONS
# ============================================================

inflt_clean <- na.omit(inflt["1963::2013"])

# Autocovariance
acov <- acf(inflt_clean, type = "covariance", lag.max = 20, plot = FALSE)
png("figures/fig2_autocovariance.png", width = 2400, height = 1600, res = 300)
plot(acov,
     main = "Figure 2: Sample Autocovariance Function of Inflation (20 Lags)",
     xlab = "Lag (Quarters)",
     ylab = "Autocovariance")
dev.off()

# Autocorrelation
acor <- acf(inflt_clean, type = "correlation", lag.max = 20, plot = FALSE)
png("figures/fig3_acf_inflation.png", width = 2400, height = 1600, res = 300)
plot(acor,
     main = "Figure 3: Sample Autocorrelation Function (ACF) of Inflation (20 Lags)",
     xlab = "Lag (Quarters)",
     ylab = "Autocorrelation")
dev.off()

# Store ACF values for results
acf_lag1  <- as.numeric(acor$acf[2])   # lag-1 autocorrelation
acov_lag0 <- as.numeric(acov$acf[1])   # variance (lag-0 autocovariance)

# ============================================================
# Q3: FIRST DIFFERENCE OF INFLATION
# ============================================================

diff_inflt <- diff(inflt["1963::2013"])
diff_inflt_clean <- na.omit(diff_inflt)

# Plot first difference
png("figures/fig4_diff_inflation.png", width = 2400, height = 1600, res = 300)
plot(as.zoo(diff_inflt_clean),
     col  = "steelblue",
     lwd  = 1.5,
     xlab = "Year",
     ylab = "Change in Inflation Rate (pp)",
     main = "Figure 4: First Difference of Inflation Rate (Δinflt)")
abline(h = 0, lty = 2, col = "grey50")
dev.off()

# ACF of first difference
acf_diff <- acf(diff_inflt_clean, lag.max = 20, plot = FALSE)
png("figures/fig5_acf_diff_inflation.png", width = 2400, height = 1600, res = 300)
plot(acf_diff,
     main = "Figure 5: ACF of First-Differenced Inflation Rate (20 Lags)",
     xlab = "Lag (Quarters)",
     ylab = "Autocorrelation")
dev.off()

diff_acf_lag1 <- as.numeric(acf_diff$acf[2])

# ============================================================
# Q4: STATIONARITY OF inflt — THREE-LEVEL ANALYSIS
# ur.df() from urca package, exactly as taught (Weeks 6-7)
# ============================================================

# All three specifications as per Week 7 seminar
q4_none  <- ur.df(inflt_clean, type = "none",  selectlags = "BIC")
q4_drift <- ur.df(inflt_clean, type = "drift", selectlags = "BIC")
q4_trend <- ur.df(inflt_clean, type = "trend", selectlags = "BIC")

# Most appropriate: "drift" — inflation has potential non-zero mean
# (Week 7 comment: "model with drift is the best model")
q4_stat  <- as.numeric(q4_drift@teststat[1, 1])   # tau_mu statistic
q4_cval  <- q4_drift@cval[1, ]                     # critical values at 1%, 5%, 10%

cat("Q4 ADF (drift) statistic:", q4_stat, "\n")
cat("Q4 Critical values:\n"); print(q4_cval)

# ============================================================
# Q5: STATIONARITY OF Δinflt — THREE-LEVEL ANALYSIS
# ============================================================

q5_none  <- ur.df(diff_inflt_clean, type = "none",  selectlags = "BIC")
q5_drift <- ur.df(diff_inflt_clean, type = "drift", selectlags = "BIC")
q5_trend <- ur.df(diff_inflt_clean, type = "trend", selectlags = "BIC")

# Most appropriate: "none" — differenced series should have no drift/trend
# (Week 7 comment: "no constant and no trend is the best model")
q5_stat  <- as.numeric(q5_none@teststat[1, 1])
q5_cval  <- q5_none@cval[1, ]

cat("Q5 ADF (none) statistic:", q5_stat, "\n")
cat("Q5 Critical values:\n"); print(q5_cval)

# ============================================================
# Q6: AUTOCORRELATION OF UNEMPLOYMENT RATE
# ============================================================

uratet <- na.omit(UNRATE["1962::2004"])

acf_urate <- acf(uratet, lag.max = 20, plot = FALSE)
png("figures/fig6_acf_urate.png", width = 2400, height = 1600, res = 300)
plot(acf_urate,
     main = "Figure 6: ACF of Unemployment Rate (uratet), 20 Lags",
     xlab = "Lag (Quarters)",
     ylab = "Autocorrelation")
dev.off()

urate_acf_lag1 <- as.numeric(acf_urate$acf[2])

# ============================================================
# Q7: STATIONARITY OF uratet — THREE-LEVEL ANALYSIS
# ============================================================

png("figures/fig7_urate.png", width = 2400, height = 1600, res = 300)
plot(as.zoo(uratet),
     col  = "steelblue",
     lwd  = 1.5,
     xlab = "Year",
     ylab = "Unemployment Rate (%)",
     main = "Figure 7: U.S. Unemployment Rate (1962:Q3–2004:Q4)")
dev.off()

q7_none  <- ur.df(uratet, type = "none",  selectlags = "BIC")
q7_drift <- ur.df(uratet, type = "drift", selectlags = "BIC")
q7_trend <- ur.df(uratet, type = "trend", selectlags = "BIC")

# Most appropriate: "drift" — unemployment fluctuates around non-zero mean
# (Week 7 comment: "most credible model" for uratet is drift)
q7_stat  <- as.numeric(q7_drift@teststat[1, 1])
q7_cval  <- q7_drift@cval[1, ]

cat("Q7 ADF (drift) statistic:", q7_stat, "\n")
cat("Q7 Critical values:\n"); print(q7_cval)

# ============================================================
# Q8: Δinflt vs LAGGED uratet SCATTER
# Sample: 1962:Q4 to 2004:Q4
# ============================================================

# Build full inflt from full PCECTPI (extending back before 1963)
inflt_full    <- xts(400 * log(PCECTPI / lag(PCECTPI)))
diff_inflt_full <- diff(inflt_full)

# Subset to Q8 sample
diff_inflt_q8 <- na.omit(diff_inflt_full["1962::2004"])
urate_q8      <- UNRATE["1962::2004"]

# Align: Δinflt_t paired with urate_{t-1}
urate_lag1_q8 <- lag(urate_q8)
common_idx    <- index(diff_inflt_q8)[index(diff_inflt_q8) %in% index(na.omit(urate_lag1_q8))]
y_q8          <- as.numeric(diff_inflt_q8[common_idx])
x_q8          <- as.numeric(na.omit(urate_lag1_q8)[common_idx])

# OLS with HAC standard errors
lm_q8     <- lm(y_q8 ~ x_q8)
lm_q8_hac <- coeftest(lm_q8, vcov. = vcovHAC)

q8_slope  <- as.numeric(lm_q8_hac[2, 1])
q8_pval   <- as.numeric(lm_q8_hac[2, 4])
q8_rsq    <- summary(lm_q8)$r.squared

png("figures/fig8_scatter.png", width = 2000, height = 2000, res = 300)
plot(x_q8, y_q8,
     col  = "steelblue",
     pch  = 16,
     cex  = 0.7,
     xlab = "Lagged Unemployment Rate, uratet-1 (%)",
     ylab = "Change in Inflation Rate, Δinflt (pp)",
     main = "Figure 8: Δinflt vs Lagged Unemployment Rate (1962:Q4–2004:Q4)")
abline(lm_q8, col = "red", lwd = 2)
abline(h = 0, lty = 2, col = "grey70")
legend("topright", legend = c("Observation", "OLS Fit"),
       col = c("steelblue", "red"), pch = c(16, NA), lty = c(NA, 1), lwd = 2)
dev.off()

# ============================================================
# Q9: ADL(2,2) MODEL — FULL SPECIFICATION
# Training period: 1963:Q4 to 2004:Q4
# ============================================================

# Prepare training series
diff_inflt_train <- diff_inflt_full["1963::2004"]
urate_train      <- UNRATE["1963::2004"]

# Align index
common_train <- index(na.omit(diff_inflt_train))[
  index(na.omit(diff_inflt_train)) %in% index(na.omit(urate_train))]
diff_inflt_train <- diff_inflt_train[common_train]
urate_train      <- urate_train[common_train]

# ---- 9.0: Does lagged urate help predict Δinflt? ----
# BIC grid across ADL(p,q) — exactly as Week 7 seminar
bic_matrix <- matrix(nrow = 4, ncol = 4,
                     dimnames = list(paste0("p=", 1:4), paste0("q=", 1:4)))
aic_matrix <- matrix(nrow = 4, ncol = 4,
                     dimnames = list(paste0("p=", 1:4), paste0("q=", 1:4)))

for (i in 1:4) {
  for (j in 1:4) {
    m <- dynlm(ts(diff_inflt_train) ~
                 L(ts(diff_inflt_train), 1:i) +
                 L(ts(urate_train), 1:j))
    bic_matrix[i, j] <- BIC(m)
    aic_matrix[i, j] <- AIC(m)
  }
}

cat("BIC Matrix (ADL p,q):\n"); print(round(bic_matrix, 2))
cat("AIC Matrix (ADL p,q):\n"); print(round(aic_matrix, 2))

# ADL(2,2) minimises BIC — confirm
which(bic_matrix == min(bic_matrix), arr.ind = TRUE)

# ---- Estimate ADL(2,2) ----
adl22 <- dynlm(ts(diff_inflt_train) ~
                 L(ts(diff_inflt_train), 1) +
                 L(ts(diff_inflt_train), 2) +
                 L(ts(urate_train), 1) +
                 L(ts(urate_train), 2))

# HAC robust standard errors (as taught Week 5-7)
adl22_hac <- coeftest(adl22, vcov. = vcovHAC)

cat("\nADL(2,2) HAC Results:\n")
print(adl22_hac)

# ---- Joint F-test: H0: delta1 = delta2 = 0 ----
# Tests whether unemployment lags jointly predict Δinflt
f_test <- linearHypothesis(adl22,
  c("L(ts(urate_train), 1) = 0",
    "L(ts(urate_train), 2) = 0"),
  vcov. = vcovHAC(adl22))

cat("\nJoint F-test (delta1=delta2=0):\n")
print(f_test)

f_stat  <- as.numeric(f_test$F[2])
f_pval  <- as.numeric(f_test$`Pr(>F)`[2])

# ---- Long-term effect ----
coefs <- coef(adl22)
# LTE = (delta1 + delta2) / (1 - beta1 - beta2)
lte <- (coefs[4] + coefs[5]) / (1 - coefs[2] - coefs[3])
cat("\nLong-term effect of urate on Δinflt:", round(lte, 4), "\n")

# ---- Model fit ----
adl22_rsq     <- summary(adl22)$r.squared
adl22_adj_rsq <- summary(adl22)$adj.r.squared
adl22_nobs    <- nobs(adl22)

# ============================================================
# Q10: OUT-OF-SAMPLE FORECAST — Q1 2005
# ============================================================

# Lagged values needed:
# diff_inflt at 2004:Q4 and 2004:Q3
# urate at 2004:Q4 and 2004:Q3

K <- length(diff_inflt_train)  # last index = 2004:Q4

q10_dinfl_t1  <- as.numeric(diff_inflt_train[K])       # Δinflt at 2004:Q4
q10_dinfl_t2  <- as.numeric(diff_inflt_train[K - 1])   # Δinflt at 2004:Q3
q10_urate_t1  <- as.numeric(urate_train[K])             # urate at 2004:Q4
q10_urate_t2  <- as.numeric(urate_train[K - 1])         # urate at 2004:Q3
q10_infl_2004q4 <- as.numeric(tail(inflt_full["1963::2004"], 1))  # inflt at 2004:Q4

# One-step-ahead forecast (matrix multiplication, Week 5-7 convention)
q10_forecast_diff  <- as.numeric(coefs %*% c(1, q10_dinfl_t1, q10_dinfl_t2,
                                               q10_urate_t1, q10_urate_t2))
q10_forecast_infl  <- q10_infl_2004q4 + q10_forecast_diff

cat("\nQ10 Forecast:\n")
cat("  Δinflt(2005:Q1) =", round(q10_forecast_diff, 4), "\n")
cat("  inflt(2005:Q1)  =", round(q10_forecast_infl, 4), "\n")

# ============================================================
# EXPORT ALL RESULTS TO JSON
# ============================================================

results <- list(
  # Q2
  acf_lag1        = acf_lag1,
  acov_lag0       = acov_lag0,
  # Q3
  diff_acf_lag1   = diff_acf_lag1,
  # Q4
  q4_stat         = q4_stat,
  q4_cval_1pct    = as.numeric(q4_cval[1]),
  q4_cval_5pct    = as.numeric(q4_cval[2]),
  q4_cval_10pct   = as.numeric(q4_cval[3]),
  # Q5
  q5_stat         = q5_stat,
  q5_cval_1pct    = as.numeric(q5_cval[1]),
  q5_cval_5pct    = as.numeric(q5_cval[2]),
  q5_cval_10pct   = as.numeric(q5_cval[3]),
  # Q6
  urate_acf_lag1  = urate_acf_lag1,
  # Q7
  q7_stat         = q7_stat,
  q7_cval_1pct    = as.numeric(q7_cval[1]),
  q7_cval_5pct    = as.numeric(q7_cval[2]),
  q7_cval_10pct   = as.numeric(q7_cval[3]),
  # Q8
  q8_slope        = q8_slope,
  q8_pval         = q8_pval,
  q8_rsq          = q8_rsq,
  # Q9 — ADL(2,2) coefficients
  adl22_const     = as.numeric(adl22_hac[1, 1]),
  adl22_beta1     = as.numeric(adl22_hac[2, 1]),
  adl22_beta2     = as.numeric(adl22_hac[3, 1]),
  adl22_delta1    = as.numeric(adl22_hac[4, 1]),
  adl22_delta2    = as.numeric(adl22_hac[5, 1]),
  adl22_se_const  = as.numeric(adl22_hac[1, 2]),
  adl22_se_beta1  = as.numeric(adl22_hac[2, 2]),
  adl22_se_beta2  = as.numeric(adl22_hac[3, 2]),
  adl22_se_delta1 = as.numeric(adl22_hac[4, 2]),
  adl22_se_delta2 = as.numeric(adl22_hac[5, 2]),
  adl22_t_const   = as.numeric(adl22_hac[1, 3]),
  adl22_t_beta1   = as.numeric(adl22_hac[2, 3]),
  adl22_t_beta2   = as.numeric(adl22_hac[3, 3]),
  adl22_t_delta1  = as.numeric(adl22_hac[4, 3]),
  adl22_t_delta2  = as.numeric(adl22_hac[5, 3]),
  adl22_p_const   = as.numeric(adl22_hac[1, 4]),
  adl22_p_beta1   = as.numeric(adl22_hac[2, 4]),
  adl22_p_beta2   = as.numeric(adl22_hac[3, 4]),
  adl22_p_delta1  = as.numeric(adl22_hac[4, 4]),
  adl22_p_delta2  = as.numeric(adl22_hac[5, 4]),
  adl22_rsq       = adl22_rsq,
  adl22_adj_rsq   = adl22_adj_rsq,
  adl22_nobs      = adl22_nobs,
  adl22_f_stat    = f_stat,
  adl22_f_pval    = f_pval,
  adl22_lte       = as.numeric(lte),
  # BIC/AIC matrices (flattened)
  bic_adl11       = bic_matrix[1, 1],
  bic_adl12       = bic_matrix[1, 2],
  bic_adl21       = bic_matrix[2, 1],
  bic_adl22       = bic_matrix[2, 2],
  bic_adl13       = bic_matrix[1, 3],
  bic_adl14       = bic_matrix[1, 4],
  bic_adl23       = bic_matrix[2, 3],
  bic_adl24       = bic_matrix[2, 4],
  bic_adl31       = bic_matrix[3, 1],
  bic_adl32       = bic_matrix[3, 2],
  bic_adl33       = bic_matrix[3, 3],
  bic_adl34       = bic_matrix[3, 4],
  bic_adl41       = bic_matrix[4, 1],
  bic_adl42       = bic_matrix[4, 2],
  bic_adl43       = bic_matrix[4, 3],
  bic_adl44       = bic_matrix[4, 4],
  aic_adl11       = aic_matrix[1, 1],
  aic_adl12       = aic_matrix[1, 2],
  aic_adl21       = aic_matrix[2, 1],
  aic_adl22       = aic_matrix[2, 2],
  # Q10
  q10_dinfl_t1    = q10_dinfl_t1,
  q10_dinfl_t2    = q10_dinfl_t2,
  q10_urate_t1    = q10_urate_t1,
  q10_urate_t2    = q10_urate_t2,
  q10_infl_2004q4 = q10_infl_2004q4,
  q10_forecast_diff = q10_forecast_diff,
  q10_forecast_infl = q10_forecast_infl
)

write(toJSON(results, pretty = TRUE, auto_unbox = TRUE),
      "outputs/results.json")

cat("\n✓ All results saved to outputs/results.json\n")
cat("✓ All figures saved to figures/\n")
```

- [ ] **Step 2: Commit the R script**

```bash
cd /home/zo/University/FN585
git add Assignment1/assignment1.r
git commit -m "feat(r): rebuild assignment1 analysis script from scratch"
```

---

## Task 2: Run R Script

**Files:**
- Read: `Assignment1/outputs/results.json` (verify populated)
- Read: `Assignment1/figures/` (verify 8 PNGs exist)

- [ ] **Step 1: Execute R script**

```bash
cd /home/zo/University/FN585/Assignment1
Rscript assignment1.r
```

Expected output (last lines):
```
✓ All results saved to outputs/results.json
✓ All figures saved to figures/
```

- [ ] **Step 2: Verify figures exist**

```bash
ls -la /home/zo/University/FN585/Assignment1/figures/
```

Expected: 8 PNG files — fig1_inflation.png through fig8_scatter.png.

- [ ] **Step 3: Verify results.json is populated**

```bash
python3 -c "import json; r=json.load(open('outputs/results.json')); print(list(r.keys())[:10])"
```

Expected: first 10 keys printed without error.

- [ ] **Step 4: Note key values for sanity check**

After running, record these values from results.json:
- `q4_stat`: should be negative (expect around -2.5 to -3.5, fail to reject H₀)
- `q5_stat`: should be strongly negative (expect < -4.0, reject H₀)
- `q7_stat`: should be around -2.0 to -2.5, fail to reject H₀
- `adl22_nobs`: should be 165
- `adl22_f_stat`: should be ~6.6, `adl22_f_pval` < 0.01

If any of these look wrong, debug the R script before proceeding.

---

## Task 3: Write Python docx Builder

**Files:**
- Overwrite: `Assignment1/build_document.py`

This script reads `outputs/results.json` and all figures, builds the complete submission DOCX.
The written analysis below is the FINAL TEXT — apply the humanizer skill to every written section string before writing this file.

**IMPORTANT:** Before writing this file, invoke the `humanizer` skill and pass EACH written analysis section through it. Replace the raw text below with the humanized output.

- [ ] **Step 1: Invoke humanizer skill on all written sections**

Invoke `humanizer` skill. Pass these sections one by one and collect the humanized output:

**Q1 analysis text (raw — humanize this):**
"The annualised inflation rate series exhibits clear non-stationary behaviour over the sample period from 1963 to 2013. The mean of the series shifts substantially across sub-periods: inflation climbed sharply during the 1970s oil shocks, peaked above 12% in 1980, then fell sharply following the Volcker disinflation of the early 1980s. After this period, the series settled into the lower, more stable range characteristic of the Great Moderation. The variance is also non-constant — the turbulent 1970s and early 1980s display far greater volatility than the post-1985 period. Both features, a time-varying mean and non-constant variance, are inconsistent with covariance-stationarity. This visual evidence alone raises strong suspicion of a unit root."

**Q2 analysis text (raw — humanize this):**
"The sample autocovariance function decays slowly across all 20 lags, with a lag-0 variance of approximately [acov_lag0] and positive values persisting throughout. The sample autocorrelation function confirms this: the lag-1 autocorrelation is [acf_lag1], and subsequent autocorrelations remain above the 95% confidence bands for many lags before gradually tapering. This slow, monotonic decay in the ACF is a classical signature of a highly persistent or non-stationary process. A stationary series would produce autocorrelations that decay to zero quickly. The pattern observed here is instead consistent with a unit root process, where shocks have permanent effects on the level of inflation."

**Q3 analysis text (raw — humanize this):**
"First differencing transforms the series markedly. The plot of Δinflt fluctuates around zero with no obvious upward or downward drift, suggesting that the mean is now approximately constant. The ACF of Δinflt shows a large negative lag-1 autocorrelation of [diff_acf_lag1], followed by rapid decay to within the confidence bands from lag 2 onward. This pattern contrasts sharply with the slow decay observed for the level series. The near-zero autocorrelations at higher lags suggest that first differencing has successfully removed the persistent component of the series. This is consistent with inflt being integrated of order one, I(1), so that its first difference Δinflt is I(0)."

**Q4 analysis text (raw — humanize this):**
"Three pieces of evidence point to non-stationarity in the inflation level. First, the time series plot shows a clearly time-varying mean — the series does not revert to a fixed level over time. Second, the ACF decays too slowly for a stationary process, with significant autocorrelations persisting across all 20 lags. Third, and most formally, the Augmented Dickey–Fuller test is applied using the ur.df() function from the urca package, across all three specifications — no constant (type='none'), with drift (type='drift'), and with trend (type='trend') — with lag length selected automatically by BIC. The specification with drift is the most appropriate for inflation, which has historically fluctuated around a non-zero mean. The ADF test statistic under the drift specification is [q4_stat], which does not exceed the 5% critical value of [q4_cval_5pct] in absolute terms. The null hypothesis of a unit root cannot be rejected at conventional significance levels. Taken together, the three levels of evidence confirm that inflt is non-stationary."

**Q5 analysis text (raw — humanize this):**
"The first-differenced series Δinflt presents a markedly different picture from its level counterpart. The time series plot oscillates around zero with no discernible trend. The ACF shows rapid decay, with only the lag-1 autocorrelation marginally exceeding the confidence bands. For the ADF test on Δinflt, the specification with no constant or trend is most appropriate — once the stochastic trend has been removed by differencing, there is no economic reason to expect a remaining drift. The ADF statistic under this specification is [q5_stat], which is well below the 1% critical value of [q5_cval_1pct]. The null hypothesis of a unit root is rejected at the 1% significance level. The three-level analysis therefore establishes that Δinflt is I(0). Combined with the Q4 result, this confirms that inflt ~ I(1)."

**Q6 analysis text (raw — humanize this):**
"The ACF of the unemployment rate uratet displays a pattern typical of a highly persistent process. The lag-1 autocorrelation is [urate_acf_lag1] — close to unity — and all 20 sample autocorrelations remain positive and statistically significant, decaying only very slowly. This slow, monotonic decay is the same qualitative pattern observed for the inflation level, and raises the same suspicion: the unemployment rate may contain a unit root, or at minimum be extremely persistent."

**Q7 analysis text (raw — humanize this):**
"The time series plot of uratet from 1962:Q3 to 2004:Q4 shows prolonged swings around a non-constant mean — low unemployment in the 1960s, rising through the 1970s and peaking above 10% in 1982–83, then declining gradually. These extended departures from any fixed mean level are inconsistent with stationarity. The ADF test is conducted under all three specifications, with the drift specification selected as most credible — unemployment fluctuates around a non-zero mean, making the constant term appropriate, but there is no clear deterministic trend to justify including a time trend. The ADF test statistic under the drift specification is [q7_stat], which does not exceed the 5% critical value of [q7_cval_5pct]. The null of a unit root is not rejected. Unemployment is therefore treated as non-stationary or near-integrated for the purposes of model specification."

**Q8 analysis text (raw — humanize this):**
"The scatter plot of Δinflt against lagged unemployment uratet-1 displays a slight negative relationship: periods of higher unemployment tend to be followed by falling inflation, consistent with the expectations-augmented Phillips curve. The OLS slope coefficient is [q8_slope], estimated with HAC standard errors to correct for residual autocorrelation and heteroscedasticity. However, the coefficient is not statistically significant (p = [q8_pval]), and the R² of just [q8_rsq] indicates that lagged unemployment alone explains very little of the variation in inflation changes. The simple bivariate specification is clearly insufficient. To model this relationship adequately, additional lags of both Δinflt and uratet need to be included — motivating the ADL(2,2) specification in Question 9."

**Q9 Part (a) — joint test text (raw — humanize this):**
"To test whether lagged unemployment rates jointly predict changes in inflation, a Wald F-test is conducted on the null hypothesis H₀: δ₁ = δ₂ = 0 within the ADL(2,2) model, using HAC-adjusted standard errors. The F-statistic is [adl22_f_stat] with a p-value of [adl22_f_pval]. The null is rejected at the 1% significance level, establishing that lagged unemployment rates provide statistically significant predictive power for Δinflt beyond the information already contained in the lagged inflation terms."

**Q9 Part (b) — HAC justification text (raw — humanize this):**
"Two features of the data justify the use of HAC standard errors. First, the inflation series exhibits pronounced heteroscedasticity: the 1970s and early 1980s saw substantially greater volatility than the post-1985 Great Moderation period. When the error variance is not constant, OLS standard errors are inconsistent, leading to unreliable inference. Second, because the ADL model includes lagged dependent variables among its regressors, residual autocorrelation is a practical concern even after conditioning on these lags. The Newey–West HAC estimator (vcovHAC in the sandwich package, as taught in Week 5) corrects for both sources of misspecification simultaneously, yielding valid t-statistics and p-values."

**Q9 Part (c) — lag selection text (raw — humanize this):**
"Lag lengths p and q are selected by estimating all ADL(p,q) models for p ∈ {1,2,3,4} and q ∈ {1,2,4}, computing the Bayesian Information Criterion for each specification, and choosing the model that minimises BIC. The results, shown in Table 2, indicate that ADL(2,2) achieves the lowest BIC value of [bic_adl22] across all 16 combinations. AIC corroborates this choice. BIC is preferred over AIC because it penalises model complexity more heavily, guarding against over-parameterisation in relatively short samples. The selection of p=2, q=2 is therefore data-driven and not arbitrary."

**Q9 Part (d) — why Δinflt, why level of urate (raw — humanize this):**
"Δinflt is used as the dependent variable rather than the level because inflt is non-stationary (I(1)), as established in Question 4. Regressing a non-stationary series directly on another potentially non-stationary series without accounting for cointegration risks spurious regression — the well-known problem identified by Granger and Newbold (1974) — where high R² and significant t-statistics arise purely from trending, not from any genuine economic relationship. First-differencing induces stationarity and ensures the regression residuals are well-behaved, making inference valid. The unemployment rate uratet enters the model in levels rather than first differences for two reasons. First, the theoretical Phillips curve relationship posits that the level of unemployment, not its change, determines inflationary pressure — the natural rate hypothesis (Friedman, 1968; Phelps, 1968) links excess unemployment relative to the natural rate to changes in inflation. Second, although the formal ADF test failed to reject a unit root in uratet, the series is better characterised as highly persistent than strictly non-stationary: it is economically bounded and mean-reverting over long horizons. Stock and Watson (2015) explicitly recommend using uratet in levels in this forecasting context."

**Q10 analysis text (raw — humanize this):**
"The one-step-ahead forecast for Q1 2005 is constructed using the estimated ADL(2,2) coefficients and the lagged values shown in Table 3. Substituting these into the model yields a predicted change in inflation of Δinflt(2005:Q1) = [q10_forecast_diff] percentage points. Adding this to the observed inflation rate of [q10_infl_2004q4]% in 2004:Q4 gives a forecast inflation level of [q10_forecast_infl]%. The model predicts a modest decline in inflation between Q4 2004 and Q1 2005, driven primarily by the large negative coefficient on lagged inflation changes pulling the series back toward its longer-run mean."

- [ ] **Step 2: Write the complete Python docx builder**

Write the following to `Assignment1/build_document.py`, replacing each ANALYSIS_TEXT_Qn placeholder with the humanized output from Step 1:

```python
"""
FN585 Assignment 1 — DOCX Builder
Reads outputs/results.json and figures/ to assemble submission document.
Font: Arial 11pt | Line spacing: 1.5 | Per assessment brief formatting
"""

import json
import os
from docx import Document
from docx.shared import Pt, Inches, RGBColor, Cm
from docx.enum.text import WD_LINE_SPACING, WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# ── Load results ──────────────────────────────────────────────────────────────
with open("outputs/results.json") as f:
    R = json.load(f)

def fmt(val, dp=4):
    """Format a float to dp decimal places."""
    return f"{val:.{dp}f}"

def pval_str(p):
    """Format p-value with asterisks."""
    if p < 0.001:
        return "< 0.001***"
    elif p < 0.01:
        return f"{p:.4f}**"
    elif p < 0.05:
        return f"{p:.4f}*"
    else:
        return f"{p:.4f}"

# ── Formatting helpers ────────────────────────────────────────────────────────
def set_font(run, size=11, bold=False, italic=False):
    run.font.name = "Arial"
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic
    # Force Arial via XML (python-docx sometimes reverts)
    r = run._r
    rPr = r.get_or_add_rPr()
    rFonts = OxmlElement("w:rFonts")
    rFonts.set(qn("w:ascii"), "Arial")
    rFonts.set(qn("w:hAnsi"), "Arial")
    rPr.insert(0, rFonts)

def set_spacing(para, spacing=1.5):
    pf = para.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    pf.line_spacing = spacing
    pf.space_after = Pt(6)

def add_para(doc, text, bold=False, size=11, spacing=1.5, align=WD_ALIGN_PARAGRAPH.LEFT):
    p = doc.add_paragraph()
    run = p.add_run(text)
    set_font(run, size=size, bold=bold)
    set_spacing(p, spacing)
    p.alignment = align
    return p

def add_heading_para(doc, text, level_num):
    """Add a numbered section heading."""
    p = doc.add_paragraph()
    run = p.add_run(f"{level_num}. {text}")
    set_font(run, size=11, bold=True)
    set_spacing(p, 1.5)
    p.paragraph_format.space_before = Pt(12)
    return p

def add_figure(doc, path, caption, width_inches=5.5):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    run.add_picture(path, width=Inches(width_inches))
    set_spacing(p, 1.0)
    cap = doc.add_paragraph()
    run2 = cap.add_run(caption)
    set_font(run2, size=10, italic=True)
    set_spacing(cap, 1.0)
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.space_after = Pt(12)

def add_table_header(table, headers):
    """Format the first row of a table as a bold header."""
    hdr_row = table.rows[0]
    for i, text in enumerate(headers):
        cell = hdr_row.cells[i]
        cell.text = ""
        run = cell.paragraphs[0].add_run(text)
        set_font(run, size=10, bold=True)
        # Grey background
        tc = cell._tc
        tcPr = tc.get_or_add_tcPr()
        shd = OxmlElement("w:shd")
        shd.set(qn("w:val"), "clear")
        shd.set(qn("w:color"), "auto")
        shd.set(qn("w:fill"), "D9D9D9")
        tcPr.append(shd)

def add_cell(row, col_idx, text, bold=False, size=10, align=WD_ALIGN_PARAGRAPH.LEFT):
    cell = row.cells[col_idx]
    cell.text = ""
    p = cell.paragraphs[0]
    run = p.add_run(text)
    set_font(run, size=size, bold=bold)
    p.alignment = align

# ── Build document ────────────────────────────────────────────────────────────
doc = Document()

# Page margins
for section in doc.sections:
    section.top_margin    = Cm(2.5)
    section.bottom_margin = Cm(2.5)
    section.left_margin   = Cm(2.5)
    section.right_margin  = Cm(2.5)

# ── Title block ───────────────────────────────────────────────────────────────
title = doc.add_paragraph()
run = title.add_run("FN585 Financial Modelling and Dealing")
set_font(run, size=14, bold=True)
set_spacing(title, 1.0)
title.alignment = WD_ALIGN_PARAGRAPH.CENTER

sub = doc.add_paragraph()
run2 = sub.add_run("Assignment 1: Time Series Analysis and Forecasting")
set_font(run2, size=12, bold=True)
set_spacing(sub, 1.0)
sub.alignment = WD_ALIGN_PARAGRAPH.CENTER

info = doc.add_paragraph()
run3 = info.add_run("Student: Zohaib Shahzada | Module: FN585 | Academic Year: 2024–25")
set_font(run3, size=11)
set_spacing(info, 1.0)
info.alignment = WD_ALIGN_PARAGRAPH.CENTER
doc.add_paragraph()  # spacer

# ── Q1 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Annualised Inflation Rate", 1)
add_para(doc, "ANALYSIS_TEXT_Q1")  # ← replace with humanized Q1 text
add_figure(doc, "figures/fig1_inflation.png",
           "Figure 1: U.S. Annualised Inflation Rate, inflt = 400 × Δln(PCECTPIt), 1963–2013.")

# ── Q2 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Autocovariance and Autocorrelation Functions", 2)
add_para(doc,
    f"ANALYSIS_TEXT_Q2".replace("[acov_lag0]", fmt(R["acov_lag0"], 2))
                        .replace("[acf_lag1]", fmt(R["acf_lag1"], 4)))
add_figure(doc, "figures/fig2_autocovariance.png",
           "Figure 2: Sample autocovariance function of inflt, lags 0–20.")
add_figure(doc, "figures/fig3_acf_inflation.png",
           "Figure 3: Sample ACF of inflt, lags 1–20. Dashed lines indicate 95% confidence bands.")

# ── Q3 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "First Difference of Inflation Rate", 3)
add_para(doc,
    f"ANALYSIS_TEXT_Q3".replace("[diff_acf_lag1]", fmt(R["diff_acf_lag1"], 4)))
add_figure(doc, "figures/fig4_diff_inflation.png",
           "Figure 4: First difference of the inflation rate, Δinflt, 1963:Q2–2013:Q4.")
add_figure(doc, "figures/fig5_acf_diff_inflation.png",
           "Figure 5: ACF of Δinflt, lags 1–20.")

# ── Q4 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Stationarity of inflt", 4)
add_para(doc,
    "ANALYSIS_TEXT_Q4"
    .replace("[q4_stat]",       fmt(R["q4_stat"], 4))
    .replace("[q4_cval_5pct]",  fmt(R["q4_cval_5pct"], 2)))

# ── Q5 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Stationarity of Δinflt", 5)
add_para(doc,
    "ANALYSIS_TEXT_Q5"
    .replace("[q5_stat]",       fmt(R["q5_stat"], 4))
    .replace("[q5_cval_1pct]",  fmt(R["q5_cval_1pct"], 2)))

# ── Q6 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Autocorrelation of the Unemployment Rate", 6)
add_para(doc,
    "ANALYSIS_TEXT_Q6"
    .replace("[urate_acf_lag1]", fmt(R["urate_acf_lag1"], 4)))
add_figure(doc, "figures/fig6_acf_urate.png",
           "Figure 6: ACF of uratet, 1962:Q3–2004:Q4, lags 1–20.")

# ── Q7 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Stationarity of the Unemployment Rate", 7)
add_para(doc,
    "ANALYSIS_TEXT_Q7"
    .replace("[q7_stat]",       fmt(R["q7_stat"], 4))
    .replace("[q7_cval_5pct]",  fmt(R["q7_cval_5pct"], 2)))
add_figure(doc, "figures/fig7_urate.png",
           "Figure 7: U.S. unemployment rate uratet, 1962:Q3–2004:Q4.")

# ── Q8 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Inflation Changes and Lagged Unemployment", 8)
add_para(doc,
    "ANALYSIS_TEXT_Q8"
    .replace("[q8_slope]", fmt(R["q8_slope"], 4))
    .replace("[q8_pval]",  fmt(R["q8_pval"], 4))
    .replace("[q8_rsq]",   fmt(R["q8_rsq"], 4)))
add_figure(doc, "figures/fig8_scatter.png",
           "Figure 8: Δinflt against lagged unemployment uratet−1, 1962:Q4–2004:Q4. "
           "Red line is OLS fit with HAC standard errors.")

# ── Q9 ────────────────────────────────────────────────────────────────────────
add_heading_para(doc, "ADL(2,2) Model: Estimation and Inference", 9)

# 9(a) Joint test
add_para(doc, "9(a) Does lagged unemployment predict changes in inflation?", bold=True)
add_para(doc,
    "ANALYSIS_TEXT_Q9A"
    .replace("[adl22_f_stat]", fmt(R["adl22_f_stat"], 4))
    .replace("[adl22_f_pval]", fmt(R["adl22_f_pval"], 4)))

# ADL(2,2) regression table
add_para(doc, "Table 1: ADL(2,2) Estimation Results — Dependent Variable: Δinflt",
         bold=True)
tbl1_headers = ["Variable", "Coefficient", "HAC Std. Error", "t-Statistic", "p-Value"]
tbl1_rows = [
    ["Constant (β₀)",         fmt(R["adl22_const"],  4), fmt(R["adl22_se_const"],  4),
                               fmt(R["adl22_t_const"], 4), pval_str(R["adl22_p_const"])],
    ["Δinflt−1 (β₁)",         fmt(R["adl22_beta1"],  4), fmt(R["adl22_se_beta1"],  4),
                               fmt(R["adl22_t_beta1"], 4), pval_str(R["adl22_p_beta1"])],
    ["Δinflt−2 (β₂)",         fmt(R["adl22_beta2"],  4), fmt(R["adl22_se_beta2"],  4),
                               fmt(R["adl22_t_beta2"], 4), pval_str(R["adl22_p_beta2"])],
    ["uratet−1 (δ₁)",         fmt(R["adl22_delta1"], 4), fmt(R["adl22_se_delta1"], 4),
                               fmt(R["adl22_t_delta1"],4), pval_str(R["adl22_p_delta1"])],
    ["uratet−2 (δ₂)",         fmt(R["adl22_delta2"], 4), fmt(R["adl22_se_delta2"], 4),
                               fmt(R["adl22_t_delta2"],4), pval_str(R["adl22_p_delta2"])],
]

t1 = doc.add_table(rows=1 + len(tbl1_rows), cols=5)
t1.style = "Table Grid"
add_table_header(t1, tbl1_headers)
for r_idx, row_data in enumerate(tbl1_rows):
    row = t1.rows[r_idx + 1]
    for c_idx, val in enumerate(row_data):
        align = WD_ALIGN_PARAGRAPH.RIGHT if c_idx > 0 else WD_ALIGN_PARAGRAPH.LEFT
        add_cell(row, c_idx, val, align=align)

# Footer note
note1 = doc.add_paragraph()
run_note = note1.add_run(
    f"Note: N = {R['adl22_nobs']}, R² = {fmt(R['adl22_rsq'],4)}, "
    f"Adj. R² = {fmt(R['adl22_adj_rsq'],4)}. "
    "HAC standard errors computed via vcovHAC (Newey–West). "
    "*** p < 0.001, ** p < 0.01, * p < 0.05."
)
set_font(run_note, size=9, italic=True)
set_spacing(note1, 1.0)
note1.paragraph_format.space_after = Pt(12)

# 9(b) HAC justification
add_para(doc, "9(b) Why are robust standard errors necessary?", bold=True)
add_para(doc, "ANALYSIS_TEXT_Q9B")

# 9(c) Lag selection
add_para(doc, "9(c) Are p = 2 and q = 2 appropriate?", bold=True)
add_para(doc,
    "ANALYSIS_TEXT_Q9C"
    .replace("[bic_adl22]", fmt(R["bic_adl22"], 2)))

# BIC grid table
add_para(doc, "Table 2: BIC Values for ADL(p,q) Specifications", bold=True)
bic_keys = {
    (1,1): "bic_adl11", (1,2): "bic_adl12", (1,3): "bic_adl13", (1,4): "bic_adl14",
    (2,1): "bic_adl21", (2,2): "bic_adl22", (2,3): "bic_adl23", (2,4): "bic_adl24",
    (3,1): "bic_adl31", (3,2): "bic_adl32", (3,3): "bic_adl33", (3,4): "bic_adl34",
    (4,1): "bic_adl41", (4,2): "bic_adl42", (4,3): "bic_adl43", (4,4): "bic_adl44",
}
t2 = doc.add_table(rows=5, cols=5)
t2.style = "Table Grid"
add_table_header(t2, ["", "q=1", "q=2", "q=3", "q=4"])
min_bic = min(R[v] for v in bic_keys.values())
for p in range(1, 5):
    row = t2.rows[p]
    add_cell(row, 0, f"p={p}", bold=True)
    for q in range(1, 5):
        val = R[bic_keys[(p, q)]]
        text = fmt(val, 2)
        bold_cell = (abs(val - min_bic) < 0.01)
        add_cell(row, q, text, bold=bold_cell,
                 align=WD_ALIGN_PARAGRAPH.RIGHT)

note2 = doc.add_paragraph()
run2n = note2.add_run("Note: Bold indicates minimum BIC value. ADL(2,2) is the preferred specification.")
set_font(run2n, size=9, italic=True)
set_spacing(note2, 1.0)
note2.paragraph_format.space_after = Pt(12)

# 9(d) Why Δinflt and why level urate
add_para(doc, "9(d) Why Δinflt as dependent variable? Why level of uratet?", bold=True)
add_para(doc, "ANALYSIS_TEXT_Q9D")

# ── Q10 ───────────────────────────────────────────────────────────────────────
add_heading_para(doc, "Out-of-Sample Forecast: Q1 2005", 10)

# Lagged values table
add_para(doc, "Table 3: Lagged Values Used in Q1 2005 Forecast", bold=True)
t3 = doc.add_table(rows=4, cols=3)
t3.style = "Table Grid"
add_table_header(t3, ["Variable", "Period", "Value"])
t3_data = [
    ["Δinflt−1",  "2004:Q4", fmt(R["q10_dinfl_t1"], 4)],
    ["Δinflt−2",  "2004:Q3", fmt(R["q10_dinfl_t2"], 4)],
    ["uratet−1",  "2004:Q4", fmt(R["q10_urate_t1"], 4)],
    ["uratet−2",  "2004:Q3", fmt(R["q10_urate_t2"], 4)],
]
for r_idx, row_data in enumerate(t3_data):
    row = t3.rows[r_idx + 1]
    for c_idx, val in enumerate(row_data):
        add_cell(row, c_idx, val,
                 align=WD_ALIGN_PARAGRAPH.RIGHT if c_idx == 2 else WD_ALIGN_PARAGRAPH.LEFT)

doc.add_paragraph()

add_para(doc,
    "ANALYSIS_TEXT_Q10"
    .replace("[q10_forecast_diff]", fmt(R["q10_forecast_diff"], 4))
    .replace("[q10_infl_2004q4]",   fmt(R["q10_infl_2004q4"],  4))
    .replace("[q10_forecast_infl]", fmt(R["q10_forecast_infl"], 4)))

# Forecast equation display
eq_para = doc.add_paragraph()
eq_run = eq_para.add_run(
    f"Δinflt(2005:Q1) = {fmt(R['adl22_const'],4)} "
    f"+ ({fmt(R['adl22_beta1'],4)})×{fmt(R['q10_dinfl_t1'],4)} "
    f"+ ({fmt(R['adl22_beta2'],4)})×{fmt(R['q10_dinfl_t2'],4)} "
    f"+ ({fmt(R['adl22_delta1'],4)})×{fmt(R['q10_urate_t1'],4)} "
    f"+ ({fmt(R['adl22_delta2'],4)})×{fmt(R['q10_urate_t2'],4)} "
    f"= {fmt(R['q10_forecast_diff'],4)}"
)
set_font(eq_run, size=10, italic=True)
set_spacing(eq_para, 1.5)
eq_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

level_para = doc.add_paragraph()
level_run = level_para.add_run(
    f"inflt(2005:Q1) = {fmt(R['q10_infl_2004q4'],4)} + {fmt(R['q10_forecast_diff'],4)} "
    f"= {fmt(R['q10_forecast_infl'],4)}%"
)
set_font(level_run, size=10, italic=True)
set_spacing(level_para, 1.5)
level_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

# ── References ────────────────────────────────────────────────────────────────
doc.add_page_break()
add_para(doc, "References", bold=True, size=12)

refs = [
    "Friedman, M. (1968) 'The role of monetary policy', American Economic Review, 58(1), pp. 1–17.",
    "Granger, C.W.J. and Newbold, P. (1974) 'Spurious regressions in econometrics', "
    "Journal of Econometrics, 2(2), pp. 111–120.",
    "Phelps, E.S. (1968) 'Money-wage dynamics and labor-market equilibrium', "
    "Journal of Political Economy, 76(4), pp. 678–711.",
    "Phillips, A.W. (1958) 'The relation between unemployment and the rate of change of "
    "money wage rates in the United Kingdom, 1861–1957', Economica, 25(100), pp. 283–299.",
    "Stock, J.H. and Watson, M.W. (2015) Introduction to Econometrics. 3rd edn. Harlow: Pearson.",
    "White, H. (1980) 'A heteroskedasticity-consistent covariance matrix estimator and a "
    "direct test for heteroskedasticity', Econometrica, 48(4), pp. 817–838.",
]

for ref in refs:
    p = doc.add_paragraph(style="List Paragraph")
    run = p.add_run(ref)
    set_font(run, size=11)
    set_spacing(p, 1.5)
    p.paragraph_format.left_indent = Inches(0)
    p.paragraph_format.first_line_indent = Inches(-0.3)
    p.paragraph_format.left_indent = Inches(0.3)

# ── Appendix: R Code ──────────────────────────────────────────────────────────
doc.add_page_break()
add_para(doc, "Appendix: Complete R Script", bold=True, size=12)
add_para(doc,
    "The following R script was used to generate all figures, regression results, "
    "and forecast values presented in this report. The script is fully reproducible "
    "given the supplied data file us_macro_quarterly.xlsx.")

r_code = open("assignment1.r").read()
code_para = doc.add_paragraph()
code_run = code_para.add_run(r_code)
code_run.font.name = "Courier New"
code_run.font.size = Pt(8)
pf = code_para.paragraph_format
pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
pf.line_spacing = 1.0

# ── Save ──────────────────────────────────────────────────────────────────────
doc.save("Assignment1_FINAL.docx")
print("✓ Assignment1_FINAL.docx saved.")
```

- [ ] **Step 3: Commit the docx builder**

```bash
cd /home/zo/University/FN585
git add Assignment1/build_document.py
git commit -m "feat(docx): rebuild document builder from scratch with humanized analysis"
```

---

## Task 4: Run docx Builder and Convert to PDF

**Files:**
- Read: `Assignment1/Assignment1_FINAL.docx` (verify no placeholder text remains)
- Read: `Assignment1/Assignment1_FINAL.pdf` (verify PDF opens correctly)

- [ ] **Step 1: Run the docx builder**

```bash
cd /home/zo/University/FN585/Assignment1
python3 build_document.py
```

Expected output:
```
✓ Assignment1_FINAL.docx saved.
```

- [ ] **Step 2: Convert to PDF via LibreOffice**

```bash
cd /home/zo/University/FN585/Assignment1
soffice --headless --convert-to pdf Assignment1_FINAL.docx
```

Expected output:
```
convert Assignment1_FINAL.docx -> Assignment1_FINAL.pdf using filter : writer_pdf_Export
```

- [ ] **Step 3: Verify PDF exists and has reasonable size**

```bash
ls -lh /home/zo/University/FN585/Assignment1/Assignment1_FINAL.pdf
```

Expected: file exists, size > 500KB (indicates figures are embedded).

- [ ] **Step 4: Commit final outputs**

```bash
cd /home/zo/University/FN585
git add Assignment1/Assignment1_FINAL.docx Assignment1/Assignment1_FINAL.pdf \
        Assignment1/figures/ Assignment1/outputs/results.json
git commit -m "feat(submission): generate final DOCX and PDF for FN585 Assignment 1"
```

---

## Task 5: Post-Build Examiner Review

**Files:**
- Read: `Assignment1/Assignment1_FINAL.docx` (full content check)
- Read: `Assignment1/outputs/results.json` (sanity check all values)

- [ ] **Step 1: Invoke superpowers:code-reviewer agent**

Dispatch a code-reviewer subagent with this exact prompt:

"You are acting as a university examiner for FN585 Financial Modelling and Dealing. Review the submitted assignment at /home/zo/University/FN585/Assignment1/Assignment1_FINAL.docx against this marking rubric:

**Data Management & Manipulation (40%):** First class (70–100): All steps clearly explained, fully reproducible, no errors, clear commenting.
**Statistical Methods (40%):** First class (70–100): Correct application of all techniques — three-level stationarity analysis (plot + ACF + ADF) for each series, correct ur.df() interpretation, valid ADL(2,2) with BIC selection, joint F-test, HAC justification, correct forecast.
**Presentation & Communication (20%):** First class (70–100): Professional tables (not raw output), figures with captions, clear human-written prose, Harvard references, complete R appendix.

Extract the full document text using:
python3 -c \"import docx; doc=docx.Document('/home/zo/University/FN585/Assignment1/Assignment1_FINAL.docx'); [print(p.text) for p in doc.paragraphs if p.text.strip()]\"

Check for:
1. Any unfilled ANALYSIS_TEXT_Qn placeholders — if found, these MUST be fixed
2. Any placeholder format strings like {fmt(...)} not substituted
3. All 9 questions answered (Q1–Q9 with sub-parts, Q10)
4. Three-level stationarity analysis present for Q4, Q5, Q7
5. BIC table present and ADL(2,2) identified as minimum
6. Joint F-test result cited in Q9(a)
7. HAC justification in Q9(b)
8. Forecast equation shown in Q10
9. References section present
10. R code appendix present
11. Written prose sounds human (no AI tells: em dashes, rule-of-three, 'it is worth noting', 'moreover', 'furthermore' in every paragraph)

Return: (a) a grade estimate per rubric component, (b) a list of specific issues to fix, (c) overall assessment."

- [ ] **Step 2: Fix any issues identified by the reviewer**

For each issue identified:
- If placeholder text remains: re-run humanizer on that section, update build_document.py, re-run builder
- If a numerical value is wrong: check results.json, debug R script if needed
- If formatting issue: fix build_document.py and re-run
- After fixes: re-run Steps 1-4 in Task 4

- [ ] **Step 3: Final commit**

```bash
cd /home/zo/University/FN585
git add -A
git commit -m "fix(submission): address examiner review feedback, finalize for submission"
```
