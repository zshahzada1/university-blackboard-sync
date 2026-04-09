# FN585 Assignment 1 Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Questions 4–10 of FN585 Assignment 1 (70 remaining marks), produce a full R script and written answers in Word, and submit as PDF by 30/03/2026 12:00 PM.

**Architecture:** Extend `assignment1.r` with Q4–10 code; write corresponding answers in `Assignment 1.docx`. Each question needs: working R code + a written interpretation paragraph.

**Tech Stack:** R (dynlm, sandwich, lmtest, tseries, AER, quantmod, readxl, tidyverse), Microsoft Word

**Deadline: 30/03/2026 12:00 PM — 3 days away. Q9 = 25 marks. Do not skip.**

---

## Current State

- `Assignment1/assignment1.r` — Q1–3 complete
- `Assignment1/Assignment 1.docx` — Q1–3 written answers complete
- Q4–10 (70 marks) are missing entirely

---

## Task 1: Add required packages to R script

**Files:**
- Modify: `Assignment1/assignment1.r` (top of file, library section)

- [ ] **Step 1: Add missing library calls after existing ones**

Add these lines after the existing `library(tidyverse)` line:

```r
library(tseries)   # adf.test() for Dickey-Fuller tests
library(dynlm)     # dynlm() for ADL models
library(sandwich)  # vcovHC() for robust standard errors
library(lmtest)    # coeftest() for robust inference
```

- [ ] **Step 2: Install packages if not already installed (run once in console, not in script)**

```r
install.packages(c("tseries", "dynlm", "sandwich", "lmtest"))
```

- [ ] **Step 3: Run the full script up to Q3 to confirm no errors before adding new code**

---

## Task 2: Q4 — Stationarity of inflt (10 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

**What's needed:** Visual plot of inflt to assess stationarity, then ADF test.

Note: The inflt plot was already produced in Q1 (Figure 1). Q4 requires re-using that visual assessment and running a formal ADF test.

- [ ] **Step 1: Add Q4 R code to script**

```r
# Question 4 - Stationarity of inflt (1963:Q1 to 2013:Q4)
# Visual analysis: refer to Figure 1 (already plotted in Q1)
# The plot shows changing mean and variance -> likely non-stationary

# Augmented Dickey-Fuller test on inflt
# H0: inflt has a unit root (non-stationary)
# H1: inflt is stationary
adf_infl <- adf.test(na.omit(as.numeric(infl)), alternative = "stationary")
print(adf_infl)
```

- [ ] **Step 2: Run the code, note the p-value and test statistic**

Expected result: p-value > 0.05, fail to reject H0 (inflation is non-stationary / has unit root).

- [ ] **Step 3: Write Q4 answer in Word document**

Structure:
1. Visual analysis: Reference Figure 1. Note the mean shifts across sub-periods (low 1960s, peaks 1970s–80s, stable 1990s–2000s, drop 2008). A stationary series has constant mean and variance — inflt clearly does not.
2. ADF test: State H0 (unit root present), report the test statistic and p-value from R output. Since p > 0.05, we fail to reject H0 → inflt is non-stationary (contains a unit root).

---

## Task 3: Q5 — Stationarity of Δinflt (10 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

**What's needed:** Plot Δinflt and run ADF test to confirm it is stationary.

Note: diff_infl was already computed in Q3 (Figure 4 shows the plot). Q5 requires re-referencing that plot and running ADF on diff_infl.

- [ ] **Step 1: Add Q5 R code to script**

```r
# Question 5 - Stationarity of Δinflt (1963:Q2 to 2013:Q4)
# Visual analysis: refer to Figure 4 (already plotted in Q3)
# The first-differenced series fluctuates around zero -> consistent with stationarity

# Augmented Dickey-Fuller test on Δinflt
# H0: Δinflt has a unit root (non-stationary)
# H1: Δinflt is stationary
adf_diff_infl <- adf.test(na.omit(as.numeric(diff_infl)), alternative = "stationary")
print(adf_diff_infl)
```

- [ ] **Step 2: Run and note output**

Expected: p-value < 0.05, reject H0 → Δinflt is stationary.

- [ ] **Step 3: Write Q5 answer in Word document**

Structure:
1. Visual: Reference Figure 4. The series fluctuates around a near-zero mean with no obvious trend → visually consistent with stationarity.
2. ADF: State H0, report statistic and p-value. Since p < 0.05, reject H0 → Δinflt is stationary. This confirms inflt is integrated of order 1, I(1).

---

## Task 4: Q6 — ACF of unemployment rate (5 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

- [ ] **Step 1: Add Q6 R code**

```r
# Question 6 - First 20 autocorrelations of unemployment rate (uratet)
# Extract UNRATE as xts object
urate <- xts(usmac$UNRATE, order.by = usmac$Date)

# Figure 6: ACF of unemployment rate (20 lags)
acf(urate, lag.max = 20, type = "correlation", na.action = na.pass,
    main = "Autocorrelation Function of Unemployment Rate")
```

- [ ] **Step 2: Run and observe the ACF plot**

Expected: Autocorrelations decay very slowly, remaining large and significant across all 20 lags — similar pattern to inflt in Q2.

- [ ] **Step 3: Write Q6 answer in Word document**

The ACF of uratet shows slowly decaying, persistently significant autocorrelations across all 20 lags (similar to the inflt ACF in Q2). This pattern is characteristic of a non-stationary or highly persistent process. A truly stationary series would show autocorrelations that decay quickly to zero. The slow decay suggests the unemployment rate is non-stationary or near-integrated.

---

## Task 5: Q7 — Plot uratet with Dickey-Fuller test (5 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

- [ ] **Step 1: Add Q7 R code**

```r
# Question 7 - Plot uratet (1962:Q3 to 2004:Q4) and test stationarity
# Filter unemployment rate to required date range
urate_sub <- urate["1962-07/2004-10"]

# Convert to tibble for ggplot
urate_df <- tibble(
  date = index(urate_sub),
  urate = as.numeric(urate_sub)
)

# Figure 7: Plot unemployment rate 1962:Q3 to 2004:Q4
urate_df %>%
  ggplot(aes(x = date, y = urate)) +
  geom_line() +
  theme_bw() +
  labs(x = NULL,
       y = "Unemployment Rate (%)",
       title = "US Unemployment Rate (1962:Q3 – 2004:Q4)")

# Augmented Dickey-Fuller test on uratet
adf_urate <- adf.test(na.omit(as.numeric(urate_sub)), alternative = "stationary")
print(adf_urate)
```

- [ ] **Step 2: Run and note output**

Expected: Unemployment rate plot shows clear cycles but also persistent long-run movements. ADF likely fails to reject H0 at conventional significance levels (p > 0.05 depending on the test specification), suggesting non-stationarity, though unemployment is often described as borderline.

- [ ] **Step 3: Write Q7 answer in Word document**

Structure:
1. Visual: Reference Figure 7. The series shows cyclical patterns tied to recessions but also substantial long-run variation. The mean does not appear constant — it rises through the 1970s, peaks in the early 1980s, declines through the 1990s. This is not consistent with strict stationarity.
2. ADF: Report H0, statistic, and p-value. Interpret whether H0 is rejected. Conclude whether uratet appears stationary or non-stationary.

---

## Task 6: Q8 — Scatter plot of Δinflt vs. lagged unemployment (10 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

**What's needed:** Scatter plot of Δinflt (y-axis) against uratet-1 (x-axis), both filtered to 1962:Q4–2004:Q4. Add a regression line. Describe relationship.

- [ ] **Step 1: Add Q8 R code**

```r
# Question 8 - Scatter plot of Δinflt vs lagged unemployment (1962:Q4 to 2004:Q4)
# Get lagged unemployment (uratet-1)
lag_urate <- lag(urate, 1)

# Filter both series to 1962:Q4 to 2004:Q4
diff_infl_q8 <- diff_infl["1962-10/2004-10"]
lag_urate_q8 <- lag_urate["1962-10/2004-10"]

# Combine into tibble (align by date)
scatter_df <- tibble(
  date      = index(diff_infl_q8),
  diff_infl = as.numeric(diff_infl_q8),
  lag_urate = as.numeric(lag_urate_q8)
) %>% drop_na()

# Figure 8: Scatter plot with OLS regression line
scatter_df %>%
  ggplot(aes(x = lag_urate, y = diff_infl)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, colour = "red") +
  theme_bw() +
  labs(x = "Lagged Unemployment Rate, uratet-1 (%)",
       y = "Change in Inflation, Δinflt",
       title = "Change in Inflation vs. Lagged Unemployment Rate (1962:Q4 – 2004:Q4)")

# Print simple regression to quantify relationship
q8_lm <- lm(diff_infl ~ lag_urate, data = scatter_df)
summary(q8_lm)
```

- [ ] **Step 2: Run and observe scatter plot and regression output**

Expected: Negative slope — higher unemployment predicts falling inflation (Phillips Curve relationship). But likely a weak relationship with low R².

- [ ] **Step 3: Write Q8 answer in Word document**

Structure:
1. Describe the scatter plot (Figure 8): Reference the downward-sloping regression line indicating a negative relationship.
2. Interpret: Higher unemployment in the previous quarter (uratet-1) is associated with lower subsequent changes in inflation. This is consistent with the Phillips Curve — labour market slack reduces inflationary pressure.
3. Statistical assessment: Report the coefficient and p-value from the simple regression. Discuss whether uratet-1 is a statistically significant predictor of Δinflt in this univariate model.
4. Note limitations: The relationship is weak and subject to structural breaks (the 1970s supply shocks and Volcker disinflation distort the relationship).

---

## Task 7: Q9 — ADL(2,2) Model (25 marks — most important task)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

**Model:** Δinflt = β0 + β1·Δinflt-1 + β2·Δinflt-2 + β3·uratet-1 + β4·uratet-2 + εt

**Estimation sample:** 1962:Q4 to 2004:Q4

**Required in written answer:**
1. Results table with robust SEs (worth ~50% of Q9 marks)
2. Why robust SEs are necessary
3. Whether p=2, q=2 lags are appropriate (use AIC/BIC)
4. Why Δinflt is used instead of inflt
5. Why not Δuratet

- [ ] **Step 1: Add ADL(2,2) estimation R code**

```r
# Question 9 - ADL(2,2) Model: Δinflt on Δinflt-1, Δinflt-2, uratet-1, uratet-2
# Estimation sample: 1962:Q4 to 2004:Q4

# Prepare data as ts objects for dynlm
# dynlm works with ts objects and handles lags with L()
diff_infl_ts <- ts(as.numeric(diff_infl),
                   start = c(1963, 2),
                   frequency = 4)

urate_ts <- ts(as.numeric(urate),
               start = c(as.numeric(format(start(urate), "%Y")),
                         as.numeric(format(start(urate), "%q"))),
               frequency = 4)

# Estimate ADL(2,2) using dynlm
adl22 <- dynlm(diff_infl_ts ~ L(diff_infl_ts, 1) + L(diff_infl_ts, 2) +
                               L(urate_ts, 1) + L(urate_ts, 2),
               start = c(1962, 4), end = c(2004, 4))

# OLS standard errors (for comparison)
summary(adl22)

# Robust standard errors (heteroskedasticity-consistent, HC1)
robust_se <- coeftest(adl22, vcov = vcovHC(adl22, type = "HC1"))
print(robust_se)
```

- [ ] **Step 2: Run and record coefficient estimates, robust SEs, t-stats, p-values**

You will use these numbers to build the results table in Word manually.

- [ ] **Step 3: Add AIC/BIC comparison for lag selection**

```r
# Compare ADL models with different lag orders using AIC and BIC
# Estimate restricted models to compare

adl11 <- dynlm(diff_infl_ts ~ L(diff_infl_ts, 1) + L(urate_ts, 1),
               start = c(1962, 4), end = c(2004, 4))

adl12 <- dynlm(diff_infl_ts ~ L(diff_infl_ts, 1) + L(urate_ts, 1) + L(urate_ts, 2),
               start = c(1962, 4), end = c(2004, 4))

adl21 <- dynlm(diff_infl_ts ~ L(diff_infl_ts, 1) + L(diff_infl_ts, 2) + L(urate_ts, 1),
               start = c(1962, 4), end = c(2004, 4))

adl22_alt <- adl22  # already estimated above

# Compare AIC and BIC
AIC(adl11, adl12, adl21, adl22_alt)
BIC(adl11, adl12, adl21, adl22_alt)
```

- [ ] **Step 4: Write Q9 results table in Word**

Create a table like this manually in Word (do NOT paste R output):

| Variable | Coefficient | Robust Std. Error | t-statistic | p-value |
|----------|-------------|-------------------|-------------|---------|
| Intercept | [value] | [value] | [value] | [value] |
| Δinflt-1 | [value] | [value] | [value] | [value] |
| Δinflt-2 | [value] | [value] | [value] | [value] |
| uratet-1 | [value] | [value] | [value] | [value] |
| uratet-2 | [value] | [value] | [value] | [value] |

Below the table add: Observations: N, R²: [value], Adjusted R²: [value]

Fill in the actual numbers from the R output. Round to 4 decimal places.

- [ ] **Step 5: Write Q9 written analysis in Word (address all 4 sub-questions)**

**Sub-question 1 (Why robust SEs):**
The residuals of time-series regressions frequently exhibit heteroskedasticity — periods of high inflation volatility (e.g., the 1970s oil shocks) produce larger residuals than stable periods. OLS standard errors assume homoskedastic errors; if violated, these SEs are inconsistent and t-tests are unreliable. Robust (heteroskedasticity-consistent, HC1) standard errors remain valid under heteroskedasticity, producing correct inference even when error variance is non-constant. The Breusch-Pagan or White test could formally test for heteroskedasticity to motivate this choice.

**Sub-question 2 (Lag order selection using AIC/BIC):**
Report the AIC and BIC values for ADL(1,1), ADL(1,2), ADL(2,1), and ADL(2,2). The model with the lowest AIC/BIC is preferred. Discuss whether ADL(2,2) is selected. Note that AIC and BIC can disagree (BIC penalises extra parameters more heavily). Conclude which specification the information criteria support, and whether p=q=2 is justified.

**Sub-question 3 (Why Δinflt not inflt):**
Q4 showed that inflt is non-stationary (contains a unit root). Using a non-stationary dependent variable in an OLS regression leads to spurious results — standard t-statistics and F-statistics are not valid. Q5 showed that Δinflt is stationary. Using Δinflt ensures the regression satisfies the stationarity assumption required for valid inference.

**Sub-question 4 (Why not Δuratet):**
The model uses the level of uratet-1 (not the change). Unlike inflation, the unemployment rate is often considered a more slowly-evolving variable that influences the level of price changes rather than the acceleration of price changes. The Phillips Curve relationship (as in the Stock & Watson formulation) posits that the level of unemployment relative to its natural rate determines inflationary pressure. Using Δuratet would estimate the effect of changes in unemployment on changes in inflation, which is a different and less economically motivated relationship. Moreover, if uratet is borderline stationary (as the ADF in Q7 may suggest), using its level is appropriate.

---

## Task 8: Q10 — Forecast Q1 2005 (5 marks)

**Files:**
- Modify: `Assignment1/assignment1.r`
- Modify: `Assignment1/Assignment 1.docx`

**What's needed:** Use the ADL(2,2) model to forecast Δinfl for Q1 2005, then compute the predicted inflation level.

- [ ] **Step 1: Add Q10 forecasting code**

```r
# Question 10 - Forecast Δinflt for Q1 2005 using the ADL(2,2) model

# Extract the values needed for the forecast:
# Δinflt-1 = Δinfl in 2004:Q4 (the last observation in the estimation sample)
# Δinflt-2 = Δinfl in 2004:Q3
# uratet-1 = urate in 2004:Q4
# uratet-2 = urate in 2004:Q3

# Get the coefficient estimates from the ADL(2,2) model
coefs <- coef(adl22)
print(coefs)

# Extract the required lagged values
diff_infl_2004Q4 <- as.numeric(diff_infl["2004-10"])  # Δinflt-1
diff_infl_2004Q3 <- as.numeric(diff_infl["2004-07"])  # Δinflt-2
urate_2004Q4     <- as.numeric(urate["2004-10"])       # uratet-1
urate_2004Q3     <- as.numeric(urate["2004-07"])       # uratet-2
infl_2004Q4      <- as.numeric(infl["2004-10"])        # inflt (level, for final forecast)

cat("Δinflt-1 (2004:Q4):", diff_infl_2004Q4, "\n")
cat("Δinflt-2 (2004:Q3):", diff_infl_2004Q3, "\n")
cat("uratet-1 (2004:Q4):", urate_2004Q4, "\n")
cat("uratet-2 (2004:Q3):", urate_2004Q3, "\n")
cat("inflt    (2004:Q4):", infl_2004Q4, "\n")

# Compute forecast for Δinfl in Q1 2005
forecast_diff_infl_2005Q1 <- coefs[1] +
                              coefs[2] * diff_infl_2004Q4 +
                              coefs[3] * diff_infl_2004Q3 +
                              coefs[4] * urate_2004Q4 +
                              coefs[5] * urate_2004Q3

cat("\nForecast Δinflt for Q1 2005:", forecast_diff_infl_2005Q1, "\n")

# Forecast inflation level for Q1 2005
# inflt = Δinflt + inflt-1 (reverse the first-difference)
forecast_infl_2005Q1 <- infl_2004Q4 + forecast_diff_infl_2005Q1
cat("Forecast inflt for Q1 2005:", forecast_infl_2005Q1, "\n")
```

- [ ] **Step 2: Run and note the two forecast values**

You will report these numbers in the written answer.

- [ ] **Step 3: Write Q10 answer in Word**

State clearly:
1. The formula used: Δinfl̂(2005:Q1) = β̂0 + β̂1·Δinfl(2004:Q4) + β̂2·Δinfl(2004:Q3) + β̂3·urate(2004:Q4) + β̂4·urate(2004:Q3)
2. The actual input values plugged in (from the cat() output above)
3. The forecast result: Δinfl̂(2005:Q1) = [value from R]
4. The predicted inflation level: infl̂(2005:Q1) = infl(2004:Q4) + Δinfl̂(2005:Q1) = [value from R]
5. Brief interpretation: Is the model predicting a rise or fall in inflation?

---

## Task 9: Finalise document and export to PDF

**Files:**
- Modify: `Assignment1/Assignment 1.docx`

- [ ] **Step 1: Check formatting requirements from the brief**
  - Arial 11pt font, 1.5 line spacing throughout
  - Numbered headings for each question (Q1, Q2, ... Q10)
  - Every figure has a caption (Figure 1, Figure 2, ...)
  - Every table has a caption (Table 1, ...)
  - Written answer present for every question (no bare R output)

- [ ] **Step 2: Add complete R script as Appendix**

Copy the full `assignment1.r` file into the Appendix section of the Word document. Format as monospace/code font (Courier New or similar).

- [ ] **Step 3: Insert all figures into the document**

Export each plot from R using `ggsave()` or `png()`, insert into Word in the correct question section.

```r
# Example: save Q8 scatter plot to file
ggsave("scatter_q8.png", width = 7, height = 5, dpi = 300)
```

- [ ] **Step 4: Export Word document to PDF**

File → Save As → PDF in Word, or use LibreOffice:
```bash
libreoffice --headless --convert-to pdf "Assignment 1.docx"
```

- [ ] **Step 5: Verify final PDF**
  - All 10 questions answered
  - All figures present and captioned
  - Results table in Q9 uses real numbers (not placeholders)
  - R script in appendix
  - File is a single PDF

- [ ] **Step 6: Submit via the university portal before 30/03/2026 12:00 PM**

---

## Priority Order (given 3 days)

1. **Today (2026-03-27):** Tasks 2–6 (Q4–Q8) — mechanical, each takes 20–30 min
2. **Tomorrow (2026-03-28):** Task 7 (Q9) — the most work, budget 2–3 hours for code + written analysis
3. **Day before deadline (2026-03-29):** Task 8 (Q10), Task 9 (formatting + PDF export)
