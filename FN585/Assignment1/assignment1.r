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

# Set working directory
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

# Subset to 1963-2013 per assessment brief
inflt_q1 <- inflt["1963::2013"]

# Save figure 1
png("figures/fig1_inflation.png", width = 2400, height = 1600, res = 300)
plot(as.zoo(inflt_q1),
     col  = "steelblue",
     lwd  = 1.5,
     xlab = "Year",
     ylab = "Annualised Inflation Rate (%)",
     main = "Figure 1: U.S. Annualised Inflation Rate (1963-2013)")
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
     main = "Figure 4: First Difference of Inflation Rate (Delta inflt)")
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
# Q4: STATIONARITY OF inflt - THREE-LEVEL ANALYSIS
# ur.df() from urca package, exactly as taught (Weeks 6-7)
# ============================================================

# All three specifications as per Week 7 seminar
q4_none  <- ur.df(inflt_clean, type = "none",  selectlags = "BIC")
q4_drift <- ur.df(inflt_clean, type = "drift", selectlags = "BIC")
q4_trend <- ur.df(inflt_clean, type = "trend", selectlags = "BIC")

# Print summaries for all three (as taught in Week 7)
cat("\n--- Q4: Unit Root Tests for inflt ---\n")
cat("\nType = none:\n");  summary(q4_none)
cat("\nType = drift:\n"); summary(q4_drift)
cat("\nType = trend:\n"); summary(q4_trend)

# Most appropriate: "drift" - inflation has potential non-zero mean
# (Week 7: "model with drift is the best model")
q4_stat <- as.numeric(q4_drift@teststat[1, 1])   # tau_mu statistic
q4_cval <- q4_drift@cval[1, ]                     # critical values at 1%, 5%, 10%

cat("\nQ4 ADF (drift) test statistic:", round(q4_stat, 4), "\n")
cat("Q4 Critical values (1%, 5%, 10%):", round(q4_cval, 4), "\n")

# ============================================================
# Q5: STATIONARITY OF Delta inflt - THREE-LEVEL ANALYSIS
# ============================================================

q5_none  <- ur.df(diff_inflt_clean, type = "none",  selectlags = "BIC")
q5_drift <- ur.df(diff_inflt_clean, type = "drift", selectlags = "BIC")
q5_trend <- ur.df(diff_inflt_clean, type = "trend", selectlags = "BIC")

cat("\n--- Q5: Unit Root Tests for Delta inflt ---\n")
cat("\nType = none:\n");  summary(q5_none)
cat("\nType = drift:\n"); summary(q5_drift)
cat("\nType = trend:\n"); summary(q5_trend)

# Most appropriate: "none" - differenced series needs no drift/trend
# (Week 7: "no constant and no trend is the best model" for differenced series)
q5_stat <- as.numeric(q5_none@teststat[1, 1])
q5_cval <- q5_none@cval[1, ]

cat("\nQ5 ADF (none) test statistic:", round(q5_stat, 4), "\n")
cat("Q5 Critical values (1%, 5%, 10%):", round(q5_cval, 4), "\n")

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
# Q7: STATIONARITY OF uratet - THREE-LEVEL ANALYSIS
# ============================================================

png("figures/fig7_urate.png", width = 2400, height = 1600, res = 300)
plot(as.zoo(uratet),
     col  = "steelblue",
     lwd  = 1.5,
     xlab = "Year",
     ylab = "Unemployment Rate (%)",
     main = "Figure 7: U.S. Unemployment Rate (1962:Q3-2004:Q4)")
dev.off()

q7_none  <- ur.df(uratet, type = "none",  selectlags = "BIC")
q7_drift <- ur.df(uratet, type = "drift", selectlags = "BIC")
q7_trend <- ur.df(uratet, type = "trend", selectlags = "BIC")

cat("\n--- Q7: Unit Root Tests for uratet ---\n")
cat("\nType = none:\n");  summary(q7_none)
cat("\nType = drift:\n"); summary(q7_drift)
cat("\nType = trend:\n"); summary(q7_trend)

# Most appropriate: "drift" - unemployment fluctuates around non-zero mean
# (Week 7: "most credible model" for uratet is drift)
q7_stat <- as.numeric(q7_drift@teststat[1, 1])
q7_cval <- q7_drift@cval[1, ]

cat("\nQ7 ADF (drift) test statistic:", round(q7_stat, 4), "\n")
cat("Q7 Critical values (1%, 5%, 10%):", round(q7_cval, 4), "\n")

# ============================================================
# Q8: Delta inflt vs LAGGED uratet SCATTER
# Sample: 1962:Q4 to 2004:Q4
# ============================================================

# Build full inflt from full PCECTPI (extending back before 1963)
inflt_full      <- xts(400 * log(PCECTPI / lag(PCECTPI)))
diff_inflt_full <- diff(inflt_full)

# Align via merge: Delta inflt_t paired with urate_{t-1}
urate_lag1_full <- lag(UNRATE)
q8_merged <- merge(diff_inflt_full, urate_lag1_full, join = "inner")
q8_merged <- na.omit(q8_merged["1962::2004"])

y_q8 <- as.numeric(q8_merged[, 1])
x_q8 <- as.numeric(q8_merged[, 2])

# OLS with HAC standard errors
lm_q8     <- lm(y_q8 ~ x_q8)
lm_q8_hac <- coeftest(lm_q8, vcov. = vcovHAC)

q8_slope <- as.numeric(lm_q8_hac[2, 1])
q8_pval  <- as.numeric(lm_q8_hac[2, 4])
q8_rsq   <- summary(lm_q8)$r.squared

cat("\nQ8 OLS (HAC): slope =", round(q8_slope, 4),
    "| p-value =", round(q8_pval, 4),
    "| R^2 =", round(q8_rsq, 4), "\n")

png("figures/fig8_scatter.png", width = 2000, height = 2000, res = 300)
plot(x_q8, y_q8,
     col  = "steelblue",
     pch  = 16,
     cex  = 0.7,
     xlab = "Lagged Unemployment Rate, uratet-1 (%)",
     ylab = "Change in Inflation Rate, Delta inflt (pp)",
     main = "Figure 8: Delta inflt vs Lagged Unemployment Rate (1962:Q4-2004:Q4)")
abline(lm_q8, col = "red", lwd = 2)
abline(h = 0, lty = 2, col = "grey70")
legend("topright", legend = c("Observation", "OLS Fit"),
       col = c("steelblue", "red"), pch = c(16, NA), lty = c(NA, 1), lwd = 2)
dev.off()

# ============================================================
# Q9: ADL(2,2) MODEL - FULL SPECIFICATION
# Training period: 1963:Q4 to 2004:Q4
# ============================================================

# Prepare training series using merge for alignment
adl_merged <- merge(diff_inflt_full, UNRATE, join = "inner")
adl_merged <- na.omit(adl_merged["1963::2004"])

diff_inflt_train <- adl_merged[, 1]
urate_train      <- adl_merged[, 2]

cat("\nADL training observations:", nrow(adl_merged), "\n")

# ---- BIC grid across ADL(p,q) - exactly as Week 7 seminar ----
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

cat("\nBIC Matrix (ADL p=rows, q=cols):\n")
print(round(bic_matrix, 2))
cat("\nMinimum BIC at:", which(bic_matrix == min(bic_matrix), arr.ind = TRUE), "\n")

# ---- Estimate ADL(2,2) ----
adl22 <- dynlm(ts(diff_inflt_train) ~
                 L(ts(diff_inflt_train), 1) +
                 L(ts(diff_inflt_train), 2) +
                 L(ts(urate_train), 1) +
                 L(ts(urate_train), 2))

# HAC robust standard errors (as taught Weeks 5-7)
adl22_hac <- coeftest(adl22, vcov. = vcovHAC)

cat("\nADL(2,2) HAC Results:\n")
print(adl22_hac)

# ---- Joint F-test: H0: delta1 = delta2 = 0 ----
f_test <- linearHypothesis(adl22,
  c("L(ts(urate_train), 1) = 0",
    "L(ts(urate_train), 2) = 0"),
  vcov. = vcovHAC(adl22))

cat("\nJoint F-test (H0: delta1 = delta2 = 0):\n")
print(f_test)

f_stat <- as.numeric(f_test$F[2])
f_pval <- as.numeric(f_test$`Pr(>F)`[2])

# ---- Long-term effect ----
coefs <- coef(adl22)
# LTE = (delta1 + delta2) / (1 - beta1 - beta2)
# coefs: [1]=intercept, [2]=beta1, [3]=beta2, [4]=delta1, [5]=delta2
lte <- (coefs[4] + coefs[5]) / (1 - coefs[2] - coefs[3])
cat("\nLong-term effect of urate on Delta inflt:", round(lte, 4), "\n")

# Model fit
adl22_rsq     <- summary(adl22)$r.squared
adl22_adj_rsq <- summary(adl22)$adj.r.squared
adl22_nobs    <- nobs(adl22)

cat("R^2:", round(adl22_rsq, 4), "| Adj R^2:", round(adl22_adj_rsq, 4),
    "| N:", adl22_nobs, "\n")

# ============================================================
# Q10: OUT-OF-SAMPLE FORECAST - Q1 2005
# ============================================================

# Lagged values at end of training period
K <- nrow(diff_inflt_train)

q10_dinfl_t1    <- as.numeric(diff_inflt_train[K])       # Delta inflt at 2004:Q4
q10_dinfl_t2    <- as.numeric(diff_inflt_train[K - 1])   # Delta inflt at 2004:Q3
q10_urate_t1    <- as.numeric(urate_train[K])             # urate at 2004:Q4
q10_urate_t2    <- as.numeric(urate_train[K - 1])         # urate at 2004:Q3

# inflt level at 2004:Q4 (for converting forecast diff to level)
inflt_train_full <- inflt_full["1963::2004"]
q10_infl_2004q4  <- as.numeric(tail(inflt_train_full, 1))

# One-step-ahead forecast (matrix multiply, Week 5-7 convention)
q10_forecast_diff <- as.numeric(coefs %*% c(1, q10_dinfl_t1, q10_dinfl_t2,
                                              q10_urate_t1, q10_urate_t2))
q10_forecast_infl <- q10_infl_2004q4 + q10_forecast_diff

cat("\nQ10 Forecast for Q1 2005:\n")
cat("  Delta inflt(2005:Q1) =", round(q10_forecast_diff, 4), "pp\n")
cat("  inflt(2005:Q1)       =", round(q10_forecast_infl, 4), "%\n")

# ============================================================
# EXPORT ALL RESULTS TO JSON
# ============================================================

results <- list(
  # Q2
  acf_lag1          = acf_lag1,
  acov_lag0         = acov_lag0,
  # Q3
  diff_acf_lag1     = diff_acf_lag1,
  # Q4
  q4_stat           = q4_stat,
  q4_cval_1pct      = as.numeric(q4_cval[1]),
  q4_cval_5pct      = as.numeric(q4_cval[2]),
  q4_cval_10pct     = as.numeric(q4_cval[3]),
  # Q5
  q5_stat           = q5_stat,
  q5_cval_1pct      = as.numeric(q5_cval[1]),
  q5_cval_5pct      = as.numeric(q5_cval[2]),
  q5_cval_10pct     = as.numeric(q5_cval[3]),
  # Q6
  urate_acf_lag1    = urate_acf_lag1,
  # Q7
  q7_stat           = q7_stat,
  q7_cval_1pct      = as.numeric(q7_cval[1]),
  q7_cval_5pct      = as.numeric(q7_cval[2]),
  q7_cval_10pct     = as.numeric(q7_cval[3]),
  # Q8
  q8_slope          = q8_slope,
  q8_pval           = q8_pval,
  q8_rsq            = q8_rsq,
  # Q9 coefficients (HAC)
  adl22_const       = as.numeric(adl22_hac[1, 1]),
  adl22_beta1       = as.numeric(adl22_hac[2, 1]),
  adl22_beta2       = as.numeric(adl22_hac[3, 1]),
  adl22_delta1      = as.numeric(adl22_hac[4, 1]),
  adl22_delta2      = as.numeric(adl22_hac[5, 1]),
  adl22_se_const    = as.numeric(adl22_hac[1, 2]),
  adl22_se_beta1    = as.numeric(adl22_hac[2, 2]),
  adl22_se_beta2    = as.numeric(adl22_hac[3, 2]),
  adl22_se_delta1   = as.numeric(adl22_hac[4, 2]),
  adl22_se_delta2   = as.numeric(adl22_hac[5, 2]),
  adl22_t_const     = as.numeric(adl22_hac[1, 3]),
  adl22_t_beta1     = as.numeric(adl22_hac[2, 3]),
  adl22_t_beta2     = as.numeric(adl22_hac[3, 3]),
  adl22_t_delta1    = as.numeric(adl22_hac[4, 3]),
  adl22_t_delta2    = as.numeric(adl22_hac[5, 3]),
  adl22_p_const     = as.numeric(adl22_hac[1, 4]),
  adl22_p_beta1     = as.numeric(adl22_hac[2, 4]),
  adl22_p_beta2     = as.numeric(adl22_hac[3, 4]),
  adl22_p_delta1    = as.numeric(adl22_hac[4, 4]),
  adl22_p_delta2    = as.numeric(adl22_hac[5, 4]),
  adl22_rsq         = adl22_rsq,
  adl22_adj_rsq     = adl22_adj_rsq,
  adl22_nobs        = adl22_nobs,
  adl22_f_stat      = f_stat,
  adl22_f_pval      = f_pval,
  adl22_lte         = as.numeric(lte),
  # BIC matrix (all 16 cells)
  bic_adl11 = bic_matrix[1, 1], bic_adl12 = bic_matrix[1, 2],
  bic_adl13 = bic_matrix[1, 3], bic_adl14 = bic_matrix[1, 4],
  bic_adl21 = bic_matrix[2, 1], bic_adl22 = bic_matrix[2, 2],
  bic_adl23 = bic_matrix[2, 3], bic_adl24 = bic_matrix[2, 4],
  bic_adl31 = bic_matrix[3, 1], bic_adl32 = bic_matrix[3, 2],
  bic_adl33 = bic_matrix[3, 3], bic_adl34 = bic_matrix[3, 4],
  bic_adl41 = bic_matrix[4, 1], bic_adl42 = bic_matrix[4, 2],
  bic_adl43 = bic_matrix[4, 3], bic_adl44 = bic_matrix[4, 4],
  aic_adl11 = aic_matrix[1, 1], aic_adl12 = aic_matrix[1, 2],
  aic_adl21 = aic_matrix[2, 1], aic_adl22 = aic_matrix[2, 2],
  # Q10
  q10_dinfl_t1      = q10_dinfl_t1,
  q10_dinfl_t2      = q10_dinfl_t2,
  q10_urate_t1      = q10_urate_t1,
  q10_urate_t2      = q10_urate_t2,
  q10_infl_2004q4   = q10_infl_2004q4,
  q10_forecast_diff = q10_forecast_diff,
  q10_forecast_infl = q10_forecast_infl
)

write(toJSON(results, pretty = TRUE, auto_unbox = TRUE),
      "outputs/results.json")

cat("\n==============================================\n")
cat("All results saved to outputs/results.json\n")
cat("All figures saved to figures/\n")
cat("==============================================\n")
