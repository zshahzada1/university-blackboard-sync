library(tidyfinance)
library(tidyverse)
library(scales)

# download the data
prices<- download_data(type="stock_prices",
                       symbols="AAPL",
                       start_date = "1991-01-01",
                       end_date = "2025-02-02")
head(prices)

# graph 
prices%>%ggplot(aes(x=date, y=adjusted_close))+
  theme_bw()+
  geom_line()+labs(x=NULL,
                   y=NULL,
                   title = "Apple stock prices between beginning of 1991 and end of 2024")

# Computing Returns

return<-prices%>%
  arrange(date)%>%
  mutate(logret=log(adjusted_close/lag(adjusted_close)))%>%
  mutate(ret= adjusted_close/lag(adjusted_close)-1)%>%
  select(symbol,date, adjusted_close, logret, ret)

head(return)


return<-return%>%
  drop_na(ret)

# return graph

return%>%
  ggplot(aes(x=date, y=ret))+geom_line()+
  theme_bw()+
  labs(x=NULL,
       y=NULL,
       title = "Apple stock return between beginning of 1991 and end of 2024")+
  




quantile_05<-quantile(return$logret, prob=0.05)

return%>%
  ggplot(aes(x=logret))+
  geom_histogram(bins = 100)+
  geom_vline(aes(xintercept =quantile_05), linetype="dashed")+
  labs(
    x = NULL,
    y = NULL,
    title = "Distribution of daily Apple stock returns"
  ) +scale_x_continuous(labels = percent)+theme_bw()


return%>%
  summarise(across(logret,
                   list(
                     mean=mean,
                     strd=sd,
                     median=median,
                     max=max,
                     min=min), 
                   .names = "{.fn}"))


return%>%
  group_by(year=year(date))%>%
  summarise(across(logret,
                   list(
                     mean=mean,
                     strd=sd,
                     median=median,
                     max=max,
                     min=min), 
                   .names = "{.fn}"))%>%
  print(n=Inf)

