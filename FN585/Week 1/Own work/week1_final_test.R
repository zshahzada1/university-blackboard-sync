library(tidyfinance)
library(tidyverse)
library(scales)

# Downloads Tesla prices, and shows them
tsla_prices <- download_data(type = "stock_prices",
                             symbols = "TSLA",
                             start_date = "2019-01-01",
                             end_date = "2026-01-01"
                             )

head(tsla_prices)

# Calculates log and simple returns. Drops NA values
returns <- tsla_prices %>%
  arrange(date) %>%
  mutate(logret = log(adjusted_close / lag(adjusted_close))) %>%
  mutate(ret = adjusted_close / lag(adjusted_close) - 1) %>%
  select(symbol, date, adjusted_close, logret, ret)

returns <- returns %>%
  drop_na(logret,ret)

head(returns)

# Plotting graph of log returns
returns %>%
  ggplot(aes(x = date, y = logret)) + 
  theme_bw() + 
  geom_line() + 
  labs(x = "Date",
       y = "Log returns",
       title = "Log returns of Tesla from start of 2019 to start of 2026"
  )

# Creating a histogram of the 15th percentile
quantile_15 <- quantile(returns$logret, probability = 0.15)

