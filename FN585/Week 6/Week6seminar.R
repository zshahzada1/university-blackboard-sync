library(AER)
library(tseries)
library(tidyverse)
library(dynlm)
library(stargazer)
library(sandwich)
library(xts)
library(readxl)


us.macro<-read_excel("us_macro_quarterly.xlsx")

us.macro<-us.macro%>%
  rename(Date=...1)%>%
  mutate(Date=as.yearqtr(Date, format="%Y:0%q"))

PCECTPI<-xts(us.macro$PCECTPI, us.macro$Date)["1960::2013"]

Infl<-xts(log(PCECTPI/lag(PCECTPI))*400)

Infl.trained<-xts(Infl)["1960::2002"]

UNR<-xts(us.macro$UNRATE, us.macro$Date)["1960::2013"]

UNR.trained<-xts(UNR)["1960::2002"]

#plot judgment
plot(as.zoo(Infl.trained),
     xlab="Date",
     ylab="Inflation of the US",
     main="Annual Inflation of the US",
     lwd=2, col="darkblue")

#ACF

acf.Inf.trained<-acf(na.omit(Infl.trained), lag.max = 24, plot=F)
plot(acf.Inf.trained, main="Auto-correlation function for the Inflation")


#unit root test

library(urca)

ur.inf.none<-ur.df(na.omit(Infl.trained),type="none", selectlags = "BIC")
summary(ur.inf.none)


ur.inf.drift<-ur.df(na.omit(Infl.trained),type="drift", selectlags = "BIC")
summary(ur.inf.drift) ##most important


ur.inf.trend<-ur.df(na.omit(Infl.trained),type="trend", selectlags = "BIC")
summary(ur.inf.trend)


# dealing with stationarity

diff.Infl<-xts(Infl.trained-lag(Infl.trained))


#plot judgment
plot(as.zoo(diff.Infl),
     xlab="Date",
     ylab="Change of inflation",
     main="Delta Inflation of the US",
     lwd=2, col="darkblue")

#ACF

acf.diffInf.trained<-acf(na.omit(diff.Infl), lag.max = 24, plot=F)
plot(acf.diffInf.trained, main="Auto-correlation function for the Delta Inflation")

#unitroot test
ur.DeltaInf.none<-ur.df(na.omit(diff.Infl), type = "none", selectlags = "BIC")

summary(ur.DeltaInf.none) # the most important case


ur.DeltaInf.drift<-ur.df(na.omit(diff.Infl), type = "drift", selectlags = "BIC")
summary(ur.DeltaInf.drift)


ur.DeltaInf.trend<-ur.df(na.omit(diff.Infl), type = "trend", selectlags = "BIC")
summary(ur.DeltaInf.trend)


#plot judgment
plot(as.zoo(UNR.trained),
     xlab="Date",
     ylab="(%)",
     main="Unemployment rate of the US",
     lwd=2, col="darkblue")


#ACF

acf.UNR.trained<-acf(na.omit(UNR.trained), lag.max = 24, plot=F)
plot(acf.UNR.trained, main="Auto-correlation function for the UNR")


ur.UNR.drift<-ur.df(na.omit(UNR.trained), type = "drift", selectlags = "BIC")
summary(ur.UNR.drift)# most important case



df<-data.frame(lag.UNR=lag(UNR.trained), diff.Infl)

fit<-dynlm(ts(diff.Infl)~L(ts(UNR.trained)))

plot(df$x, df$x.1,
     xlab="Lag of unemployment rate",
     ylab="Change of the Inflation",
     main="Association between unemployment rate (Lag) and inflation",
     lwd=2)
abline(fit$coefficients, col="darkred", lwd=2)

fit

#fitting ADL(2,2)

model<-dynlm(ts(diff.Infl)~L(ts(diff.Infl))+L(ts(diff.Infl),2)+
               L(ts(UNR.trained))+L(ts(UNR.trained),2))

model.HAC<-coeftest(model, vcov. = vcovHAC)

stargazer(model,model.HAC, type="text")


longtermeffect<-(1-model$coefficients[2]-model$coefficients[3])/(model$coefficients[3]+model$coefficients[4])
longtermeffect

#Forcast of diff inflation
K<-length(diff.Infl)

frcst.Diff.Infl<-model$coefficients %*% c(1,diff.Infl[K],diff.Infl[K-1],
                                          UNR.trained[K],UNR.trained[K-1])

frcst.Infl<-Infl.trained[K]+frcst.Diff.Infl

frcst.error<-Infl[K+1]-as.numeric(frcst.Infl)
Infl[K+1]
frcst.error
