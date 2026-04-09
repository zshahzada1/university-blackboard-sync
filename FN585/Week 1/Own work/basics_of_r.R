library(tidyfinance)
library(tidyverse)
library(scales)

# downloads stock prices and also the tickr, start and end date. stores in an object called prices.
prices <- download_data(type = "stock_prices",
                        symbols = "AAPL",
                        start_date = "1991-01-01",
                        end_date = "2025-02-02")

# shows prices column
head(prices)

# plots prices against date. uses adjusted close as that's after dividends and stock splits. shows true prices for return calculation.
prices %>%
  ggplot(aes(x = date, y = adjusted_close)) + 
  theme_bw() + 
  geom_line() + 
  labs(x = NULL,
       y = NULL,
       title = "Apple stock prices between the beginning of 1991 and end of 2024")

# calculates return by arranging date, creating a log returns column adn creating a simple returns column. keeps tickr, date, adjusted close and both returns; drops all else.
return <- prices %>%
  arrange(date) %>%
  mutate(logret = log(adjusted_close / lag(adjusted_close))) %>%
  mutate(ret = adjusted_close/lag(adjusted_close) - 1) %>%
  select(symbol, date, adjusted_close, logret, ret)

# drops na returns values
return <- return %>%
  drop_na(ret)

# shows return column
head(return)

# plotting logreturns over time. sets b and w theme and draws a line chart. sets labels
return %>%
  ggplot(aes(x = date, y = logret)) +
  theme_bw() + 
  geom_line() +
  labs(x = "Date",
       y = "Log Returns",
       title = "Apple stock log returns from beginning of 1991 to end of 2024")

# plots distribution of returns
quantile_05 <- quantile(return$logret, prob = 0.05)

return %>%
  ggplot(aes(x = logret)) + 
  geom_histogram(bins = 100) + 
  geom_vline(aes(xintercept = quantile_05, linetype = "dashed")) + 
  labs(x = NULL,
       y = NULL,
       title = "Distribution of daily Apple stock returns") + 
  scale_x_continuous(labels = percent) + 
  theme_bw()

# summarising mean, standard deviation, median, max and min of log returns
return %>%
  summarise(across(logret,
                   list(mean = mean,
                        strd = sd,
                        median = median,
                        max = max,
                        min = min),
                   .names = "{.fn}"))

# summarising statistics by year
return %>%
  group_by(year = year(date)) %>%
  summarise(across(logret,
                   list(mean = mean,
                        strd = strd,
                        median = median,
                        max = max,
                        min = min),
                   .names = "{.fn}")) %>%
  print(n = Inf)