# ============================================================
# FN585 Assignment 1 — Full Analysis Script (Q1–Q10)
# Author: Zohaib Shahzada
# ============================================================

library(AER)
library(quantmod)
library(readxl)
library(stats)
library(tidyverse)
library(tseries)
library(dynlm)
library(sandwich)
library(lmtest)
library(jsonlite)
library(zoo)

# ── Paths ────────────────────────────────────────────────────
script_dir <- dirname(normalizePath(commandArgs(trailingOnly = FALSE)[
  grep("--file=", commandArgs(trailingOnly = FALSE))
], mustWork = FALSE))
if (length(script_dir) == 0 || script_dir == "") script_dir <- getwd()

fig_dir <- file.path(script_dir, "figures")
out_dir <- file.path(script_dir, "outputs")
dir.create(fig_dir, showWarnings = FALSE)
dir.create(out_dir, showWarnings = FALSE)

# ── Data ─────────────────────────────────────────────────────
usmac <- read_excel(file.path(script_dir, "us_macro_quarterly.xlsx"))
usmac$...1 <- as.yearqtr(usmac$...1, format = "%Y:0%q")
colnames(usmac) <- c("Date", "GDPC96", "JAPAN_IP", "PCECTPI",
                     "GS10", "GS1", "TB3MS", "UNRATE", "EXUSUK", "CPIAUCSL")

# ── Q1: Annualised inflation ─────────────────────────────────
PCEC <- xts(usmac$PCECTPI, order.by = usmac$Date)
infl <- 400 * (log(PCEC) - log(lag(PCEC)))
infl <- infl["1963/2013"]

infl_df <- tibble(date = as.numeric(index(infl)), inflation = as.numeric(infl))

p1 <- infl_df %>%
  ggplot(aes(x = date, y = inflation)) +
  geom_line(colour = "#2c3e50", linewidth = 0.6) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = NULL, y = "Annualised Inflation Rate (%)",
       title = "Figure 1: Annualised US Inflation Rate (1963–2013)")
ggsave(file.path(fig_dir, "fig1_inflation.png"), plot = p1,
       width = 8, height = 4.5, dpi = 300)

# ── Q2: Autocovariance & ACF ─────────────────────────────────
infl_vec <- na.omit(as.numeric(infl))

png(file.path(fig_dir, "fig2_autocovariance.png"), width = 2400, height = 1600, res = 300)
acf(infl_vec, lag.max = 20, type = "covariance",
    main = "Figure 2: Autocovariance Function of Annualised Inflation Rate",
    xlab = "Lag (quarters)", ylab = "Autocovariance")
dev.off()

png(file.path(fig_dir, "fig3_acf_inflation.png"), width = 2400, height = 1600, res = 300)
acf(infl_vec, lag.max = 20, type = "correlation",
    main = "Figure 3: Autocorrelation Function of Annualised Inflation Rate",
    xlab = "Lag (quarters)", ylab = "ACF")
dev.off()

acf_vals <- acf(infl_vec, lag.max = 20, type = "correlation", plot = FALSE)
acf_lag1 <- round(acf_vals$acf[2], 4)   # lag 0 is index 1, lag 1 is index 2

# ── Q3: First difference of inflation ────────────────────────
diff_infl <- diff(infl)
diff_infl_vec <- na.omit(as.numeric(diff_infl))

diff_infl_df <- tibble(
  date = as.numeric(index(diff_infl)),
  diff_inflation = as.numeric(diff_infl)
)

p4 <- diff_infl_df %>%
  ggplot(aes(x = date, y = diff_inflation)) +
  geom_line(colour = "#2c3e50", linewidth = 0.6) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = NULL, y = "Change in Inflation Rate",
       title = "Figure 4: First Difference of Annualised US Inflation Rate (1963–2013)")
ggsave(file.path(fig_dir, "fig4_diff_inflation.png"), plot = p4,
       width = 8, height = 4.5, dpi = 300)

png(file.path(fig_dir, "fig5_acf_diff_inflation.png"), width = 2400, height = 1600, res = 300)
acf(diff_infl_vec, lag.max = 20, type = "correlation",
    main = "Figure 5: ACF of First-Differenced Inflation Rate",
    xlab = "Lag (quarters)", ylab = "ACF")
dev.off()

diff_acf_vals <- acf(diff_infl_vec, lag.max = 20, type = "correlation", plot = FALSE)
diff_acf_lag1 <- round(diff_acf_vals$acf[2], 4)

# ── Q4: ADF test on inflt ────────────────────────────────────
adf_infl <- adf.test(infl_vec, alternative = "stationary")
q4_stat   <- round(as.numeric(adf_infl$statistic), 4)
q4_pval   <- round(adf_infl$p.value, 4)

# ── Q5: ADF test on Δinflt ───────────────────────────────────
adf_diff  <- adf.test(diff_infl_vec, alternative = "stationary")
q5_stat   <- round(as.numeric(adf_diff$statistic), 4)
q5_pval   <- round(adf_diff$p.value, 4)

# ── Q6: ACF of unemployment rate ─────────────────────────────
urate <- xts(usmac$UNRATE, order.by = usmac$Date)
urate_vec_full <- na.omit(as.numeric(urate))

png(file.path(fig_dir, "fig6_acf_urate.png"), width = 2400, height = 1600, res = 300)
acf(urate_vec_full, lag.max = 20, type = "correlation",
    main = "Figure 6: Autocorrelation Function of Unemployment Rate",
    xlab = "Lag (quarters)", ylab = "ACF")
dev.off()

urate_acf_lag1 <- round(acf(urate_vec_full, lag.max = 20,
                             type = "correlation", plot = FALSE)$acf[2], 4)

# ── Q7: Plot uratet (1962:Q3–2004:Q4) & ADF ──────────────────
urate_q7 <- window(urate,
                   start = as.yearqtr("1962 Q3"),
                   end   = as.yearqtr("2004 Q4"))

urate_q7_df <- tibble(
  date  = as.numeric(index(urate_q7)),
  urate = as.numeric(urate_q7)
)

p7 <- urate_q7_df %>%
  ggplot(aes(x = date, y = urate)) +
  geom_line(colour = "#2c3e50", linewidth = 0.6) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = NULL, y = "Unemployment Rate (%)",
       title = "Figure 7: US Unemployment Rate (1962:Q3–2004:Q4)")
ggsave(file.path(fig_dir, "fig7_urate.png"), plot = p7,
       width = 8, height = 4.5, dpi = 300)

urate_q7_vec <- na.omit(as.numeric(urate_q7))
adf_urate    <- adf.test(urate_q7_vec, alternative = "stationary")
q7_stat      <- round(as.numeric(adf_urate$statistic), 4)
q7_pval      <- round(adf_urate$p.value, 4)

# ── Q8: Scatter Δinflt vs uratet-1 (1962:Q4–2004:Q4) ────────
# Merge series by date, then manually lag urate
q8_merged <- merge(diff_infl, urate, join = "inner")
colnames(q8_merged) <- c("diff_infl", "urate")
q8_df <- as.data.frame(q8_merged)
q8_df$date      <- index(q8_merged)
q8_df$lag_urate <- c(NA, head(q8_df$urate, -1))
scatter_df <- q8_df %>%
  filter(date >= as.yearqtr("1962 Q4") & date <= as.yearqtr("2004 Q4")) %>%
  drop_na() %>%
  select(diff_infl, lag_urate)

q8_lm    <- lm(diff_infl ~ lag_urate, data = scatter_df)
q8_slope <- round(coef(q8_lm)[2], 4)
q8_pval  <- round(summary(q8_lm)$coefficients[2, 4], 4)
q8_rsq   <- round(summary(q8_lm)$r.squared, 4)

p8 <- scatter_df %>%
  ggplot(aes(x = lag_urate, y = diff_infl)) +
  geom_point(alpha = 0.55, colour = "#2c3e50", size = 1.8) +
  geom_smooth(method = "lm", se = TRUE, colour = "#e74c3c",
              fill = "#e74c3c", alpha = 0.12, linewidth = 0.9) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "Lagged Unemployment Rate, uratet−1 (%)",
       y = "Change in Inflation Rate, Δinflt",
       title = "Figure 8: Change in Inflation vs. Lagged Unemployment Rate (1962:Q4–2004:Q4)")
ggsave(file.path(fig_dir, "fig8_scatter.png"), plot = p8,
       width = 8, height = 5, dpi = 300)

# ── Q9: ADL(2,2) model ───────────────────────────────────────
# Build aligned data frame spanning the full diff_infl range
merged_xts <- merge(diff_infl, urate, join = "left")
colnames(merged_xts) <- c("diff_infl", "urate")

model_df_raw <- as.data.frame(merged_xts)
model_df_raw$date <- index(merged_xts)
model_df_raw$diff_infl_l1 <- c(NA, head(model_df_raw$diff_infl, -1))
model_df_raw$diff_infl_l2 <- c(NA, NA, head(model_df_raw$diff_infl, -2))
model_df_raw$urate_l1     <- c(NA, head(model_df_raw$urate, -1))
model_df_raw$urate_l2     <- c(NA, NA, head(model_df_raw$urate, -2))

model_df <- model_df_raw %>%
  filter(date <= as.yearqtr("2004 Q4")) %>%
  drop_na()

adl22 <- lm(diff_infl ~ diff_infl_l1 + diff_infl_l2 + urate_l1 + urate_l2,
             data = model_df)

# Robust (HC1) standard errors
robust_test <- coeftest(adl22, vcov = vcovHC(adl22, type = "HC1"))

coef_names <- c("intercept", "diff_infl_l1", "diff_infl_l2", "urate_l1", "urate_l2")
adl22_coefs     <- setNames(round(robust_test[, 1], 4), coef_names)
adl22_robust_se <- setNames(round(robust_test[, 2], 4), coef_names)
adl22_robust_t  <- setNames(round(robust_test[, 3], 4), coef_names)
adl22_robust_p  <- setNames(round(robust_test[, 4], 4), coef_names)

adl22_rsq     <- round(summary(adl22)$r.squared, 4)
adl22_adj_rsq <- round(summary(adl22)$adj.r.squared, 4)
adl22_nobs    <- nrow(model_df)

# Joint F-test for lagged unemployment (H0: urate_l1 = urate_l2 = 0)
f_test <- waldtest(adl22, c("urate_l1", "urate_l2"), vcov = vcovHC(adl22, type = "HC1"))
adl22_f_stat <- round(f_test$F[2], 4)
adl22_f_pval <- round(f_test$`Pr(>F)`[2], 4)

# AIC / BIC comparison across lag specifications
adl11 <- lm(diff_infl ~ diff_infl_l1 + urate_l1, data = model_df)
adl12 <- lm(diff_infl ~ diff_infl_l1 + urate_l1 + urate_l2, data = model_df)
adl21 <- lm(diff_infl ~ diff_infl_l1 + diff_infl_l2 + urate_l1, data = model_df)

aic_vals <- c(adl11 = AIC(adl11), adl12 = AIC(adl12),
              adl21 = AIC(adl21), adl22 = AIC(adl22))
bic_vals <- c(adl11 = BIC(adl11), adl12 = BIC(adl12),
              adl21 = BIC(adl21), adl22 = BIC(adl22))

# ── Q10: Forecast Q1 2005 ────────────────────────────────────
# Extract directly from xts for clarity
q10_dinfl_t1 <- round(as.numeric(diff_infl[as.yearqtr("2004 Q4")]), 4)  # Δinfl 2004Q4
q10_dinfl_t2 <- round(as.numeric(diff_infl[as.yearqtr("2004 Q3")]), 4)  # Δinfl 2004Q3
q10_urate_t1 <- round(as.numeric(urate[as.yearqtr("2004 Q4")]), 4)      # urate 2004Q4
q10_urate_t2 <- round(as.numeric(urate[as.yearqtr("2004 Q3")]), 4)      # urate 2004Q3
q10_infl_2004q4 <- round(as.numeric(infl[as.yearqtr("2004 Q4")]), 4)

b <- coef(adl22)
q10_forecast_diff <- round(b[1] + b[2]*q10_dinfl_t1 + b[3]*q10_dinfl_t2 +
                              b[4]*q10_urate_t1 + b[5]*q10_urate_t2, 4)
q10_forecast_infl <- round(q10_infl_2004q4 + q10_forecast_diff, 4)

# ── Save all results ─────────────────────────────────────────
results <- list(
  acf_lag1           = acf_lag1,
  diff_acf_lag1      = diff_acf_lag1,
  urate_acf_lag1     = urate_acf_lag1,

  q4_stat = q4_stat, q4_pval = q4_pval,
  q5_stat = q5_stat, q5_pval = q5_pval,
  q7_stat = q7_stat, q7_pval = q7_pval,

  q8_slope = q8_slope, q8_pval = q8_pval, q8_rsq = q8_rsq,

  adl22_coefs      = as.list(adl22_coefs),
  adl22_robust_se  = as.list(adl22_robust_se),
  adl22_robust_t   = as.list(adl22_robust_t),
  adl22_robust_p   = as.list(adl22_robust_p),
  adl22_rsq        = adl22_rsq,
  adl22_adj_rsq    = adl22_adj_rsq,
  adl22_nobs       = adl22_nobs,
  adl22_f_stat     = adl22_f_stat,
  adl22_f_pval     = adl22_f_pval,

  aic_adl11 = round(aic_vals["adl11"], 2),
  aic_adl12 = round(aic_vals["adl12"], 2),
  aic_adl21 = round(aic_vals["adl21"], 2),
  aic_adl22 = round(aic_vals["adl22"], 2),
  bic_adl11 = round(bic_vals["adl11"], 2),
  bic_adl12 = round(bic_vals["adl12"], 2),
  bic_adl21 = round(bic_vals["adl21"], 2),
  bic_adl22 = round(bic_vals["adl22"], 2),

  q10_dinfl_t1      = q10_dinfl_t1,
  q10_dinfl_t2      = q10_dinfl_t2,
  q10_urate_t1      = q10_urate_t1,
  q10_urate_t2      = q10_urate_t2,
  q10_infl_2004q4   = q10_infl_2004q4,
  q10_forecast_diff = q10_forecast_diff,
  q10_forecast_infl = q10_forecast_infl
)

write_json(results, file.path(out_dir, "results.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Analysis complete. Results saved to outputs/results.json\n")
cat("Figures saved to figures/\n")
