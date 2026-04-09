library(tidyfinance)
library(tidyverse)
library(scales)

# downloads prices for selected tickr, with required dates
prices <- download_data(type = "stock_prices",
                        symbols = "MSFT",
                        start_date = "2010-01-01",
                        end_date = "2025-02-02")

head(prices)

# calculates returns, creates two new columns (log returns and simple returns), selects certain columns to keep and drops the rest
returns <- prices %>%
  arrange(date) %>%
  mutate(logret = log(adjusted_close / lag(adjusted_close))) %>%
  mutate(ret = adjusted_close / lag(adjusted_close) - 1) %>%
  select(symbol, date, adjusted_close, ret, logret)

# removes na values from ret and logret column
returns <- returns %>%
  drop_na(ret, logret)

head(returns)

# calculates 10th percentile (10% of days are worse than this). creates a histogram and then shows x axis as percentages. simple and log returns done.
quantile_10 <- quantile(returns$ret, prob = 0.1)

returns %>%
  ggplot(aes(x = ret)) + 
  geom_histogram(bins = 100) + 
  geom_vline(aes(xintercept = quantile_10), linetype = "dashed") + 
  labs(x = NULL,
       y = NULL,
       title = "Simple return distribution of MSFT returns from start of 2010 to end of 2024") + 
  scale_x_continuous(labels = percent) + 
  theme_bw()

returns %>%
  ggplot(aes(x = logret)) + 
  geom_histogram(bins = 100) + 
  geom_vline(aes(xintercept = quantile_10), linetype = "dashed") + 
  labs(x = NULL,
       y = NULL,
       title = "Log returns distribution of MSFT returns from start of 2010 to end of 2024") + 
  scale_x_continuous(labels = percent) + 
  theme_bw()

# Suammrises log returns overall
returns %>%
  summarise(across(logret,
                   list(mean = mean,
                        strd = sd,
                        median = median,
                        max = max,
                        min = min),
                        .names = "{.fn}"))

# summarises log returns year by year
returns %>%
  group_by(year = year(date)) %>%
  summarise(across(logret,
                   list(mean = mean,
                        strd = sd,
                        median = median,
                        max = max,
                        min = min),
                   .names = "{.fn}")) %>%
  print(n = Inf)

