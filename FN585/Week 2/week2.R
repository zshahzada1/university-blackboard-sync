library(tidyfinance)
library(tidyverse)
library(scales)



symbols<-download_data(
  typ= "constituents",
  index="Dow Jones Industrial Average"
)

symbols


prices_daily<-download_data(
  type = "stock_prices",
  symbols=symbols$symbol,
  start_date="1990-01-01",
  end_date = "2025-02-16"
)

prices_daily%>%
  ggplot(aes(x=date, y=adjusted_close, col = symbol))+
  geom_line()+
  theme_bw()+
  labs(x=NULL,
       y=NULL,
       title= "Stock prices of Dow Jones index constituents")+
  theme(legend.position = "none")


return_daily<-prices_daily%>%
  group_by(symbol)%>%
  mutate(ret=adjusted_close/lag(adjusted_close)-1)%>%
  select(date, symbol, adjusted_close, ret)%>%
  drop_na(ret)

head(return_daily)

return_daily%>%
  group_by(symbol)%>%
  summarise(across(ret,
                   list(
                     mean=mean,
                     sd=sd,
                     median=median,
                     max=max,
                     min=min
                   ), .names = "{.fn}"))%>%
  print(n=Inf)


return_monthly<-return_daily%>%
  mutate(date=floor_date(date, "month"))%>%
  group_by(symbol, date)%>%
  summarise(ret=prod(ret+1)-1, .groups = "drop")


apple_returns<-bind_rows(
  return_daily%>%
    filter(symbol=="AAPL")%>%
    mutate(frequency="Daily"), 
  return_monthly%>%
    filter(symbol=="AAPL")%>%
    mutate(frequency="Monthly")
)


apple_returns%>%
  ggplot(aes(x=ret, fill=frequency))+
  geom_histogram(position = "identity", bins=50)+
  labs(x=NULL,
       y=NULL,
       fill="Frequency",
       title="Distribution of Apple returns across different frequencies")+
  scale_x_continuous(labels = percent) +
  theme_minimal()+
  facet_wrap(~frequency, scales="free")+
  theme(legend.position = "none")