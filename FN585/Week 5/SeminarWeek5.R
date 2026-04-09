setwd("~/fn585")
library(AER)
library(tseries)
library(tidyverse)
library(dynlm)
library(stargazer)
library(sandwich)
library(readxl)
library(xts)

us.macro<-read_excel("us_macro_quarterly.xlsx")

us.macro<-us.macro%>%
  rename(Date=...1)%>%
  mutate(Date=as.yearqtr(Date, format="%Y:0%q"))


GDP<-xts(us.macro$GDPC96, us.macro$Date)

GDPgrowth<-xts(log(GDP/lag(GDP))*100)["1960::2013"]

GDPgrowth.trained<-xts(GDPgrowth)["1960::2002"]


acf(GDPgrowth.trained)

fitAR2<-dynlm(ts(GDPgrowth.trained)~L(ts(GDPgrowth.trained))+
                L(ts(GDPgrowth.trained),2))

fit.HAC<-coeftest(fitAR2, vcov. = vcovHAC)

stargazer(fitAR2,fit.HAC, type="text")

K<-length(GDPgrowth.trained)
GDPgrowth.trained[K]



frcstAR2<-fitAR2$coefficients%*%c(1, GDPgrowth.trained[K],
                        GDPgrowth.trained[K-1])

frcsterror<-frcstAR2-GDPgrowth[K+1]
frcsterror



############

set.seed(123)
y=rnorm(250, mean=0.01, sd=0.05)
date<-seq(as.Date("2000-01-01"), length.out=250, by="month")
y<-xts(y, date)


plot(as.zoo(y), 
     main="Gaussian White Noise process",
     ylab="r(t)",
     xlab="date", lwd=2, col="darkblue")
abline(h=0, lty=2)


plot(as.zoo(y), 
     main="Gaussian White Noise process",
     ylab="r(t)",
     xlab="date", lwd=2, col="darkblue", type="h")
abline(h=c(0,-0.05, 0.05), lty=c("solid","dotted","dotted"), 
       col=c("black", "darkred", "darkred"), lwd=2)

z=cumsum(rnorm(250))

plot(z,
     main="Gaussian White Noise process",
     ylab="cumulative returns r(t)",
     xlab="date", lwd=2, col="darkblue", type="l")
abline(h=0)

set.seed(123)
ma1.model=list(ma=-0.75)
mu=1
ma.sim=mu+arima.sim(model=ma1.model, 250)

ma.sim<-xts(ma.sim, date)

plot(as.zoo(ma.sim),
     main="MA(1) process with theta=0.75; mu=1",
     xlab="time",
     ylab="r(t)", col="blue", lwd=2)
abline(h=0, lty=2)



acf(y)
