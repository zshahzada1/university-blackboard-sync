setwd("~/fn585")
library(AER)
library(tseries)
library(xts)
library(readxl)
library(tidyverse)
us.macro<-read_excel("us_macro_quarterly.xlsx")

us.macro<-us.macro%>%
  rename(Date=...1)%>%
  mutate(Date=as.yearqtr(Date, format="%Y:0%q"))


GDP<-xts(us.macro$GDPC96, us.macro$Date)

df<-us.macro%>%
  select(Date, GDPC96)%>%
  mutate(LGDP=lag(GDPC96),
         L2GDPC=lag(GDPC96,2), L5GDPC=lag(GDPC96,3))

GDPgrowth<-xts(log(GDP/lag(GDP))*100)

us.macro<-us.macro%>%
  mutate(GDPgrowth= log(GDPC96/lag(GDPC96) )*100)


PCECTPI<-xts(us.macro$PCECTPI, us.macro$Date)

infl<-xts(400*log(PCECTPI/ lag(PCECTPI)))

unrate<-xts(us.macro$UNRATE, us.macro$Date)


infl.df<-us.macro%>%
  mutate(infl= log(PCECTPI/lag(PCECTPI) )*400)%>%
  select(Date, PCECTPI, infl, UNRATE)%>%
  drop_na(infl)


plot(as.zoo(GDP),
     xlab="Time",
     ylab="GDP (billion $)",
     main="GDP of the US between 1957 and 2013",
     col="blue")

us.macro%>%
  ggplot(aes(x=Date, y= GDPC96, colour = "darkblue" ))+geom_line()+
  theme_bw()+
  labs(x="Time",
       y="GDP (billion $)",
       title="GDP of the US between 1957 and 2013")+
  scale_color_manual(values =c("darkblue"))+
  theme(legend.position = "none")



plot(as.zoo(PCECTPI),
     xlab="Time",
     ylab="PCECTPI",
     main="Price index of the US between 1957 and 2013",
     col="blue")


plot(as.zoo(GDPgrowth),
     xlab="Time",
     ylab="GDP growth (%)",
     main="GDP growth of the US between 1957 and 2013",
     col="blue")


us.macro%>%
  ggplot(aes(x=Date, y= GDPgrowth, colour = "darkblue" ))+geom_line()+
  theme_bw()+
  labs(x="Time",
       y="GDP growth (%)",
       title="GDP growth of the US between 1957 and 2013")+
  scale_color_manual(values =c("darkblue"))+
  theme(legend.position = "none")


plot(as.zoo(infl),
     xlab="Time",
     ylab="Inflation (%)",
     main="Inflation of the US between 1957 and 2013",
     col="blue")


infl.df%>%
  ggplot(aes(x=Date, y=infl, colour="darkred"))+geom_line()+
  theme_bw()+
  labs(x="Time",
       y="Annual inflation (%)",
       title="Inflation of the US between 1957 and 2013")+
  scale_color_manual(values=c("darkred"))+
  theme(legend.position = "none")

acf.gdp<-acf(GDP, lag.max = 12, plot=FALSE)

acf.gdp
plot(acf.gdp,main="Auto-correlation funtion for GDP")

acf.gdpgrowth<-acf(na.omit(GDPgrowth), lag.max = 12, plot=FALSE)

acf.gdpgrowth

plot(acf.gdpgrowth, main="Auto-correlation funtion for GDP growth")


acf.inf<-acf(na.omit(infl), lag.max = 12, plot=FALSE )

acf.inf
plot(acf.inf, main="Auto-correlation funtion for Inflation")
