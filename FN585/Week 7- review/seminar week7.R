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

##### 
#unit root test for inflation

library(urca)
ur.infl.none<-ur.df(na.omit(Infl.trained), type="none", selectlags = "BIC" )

summary(ur.infl.none) # none stationary

ur.infl.drift<-ur.df(na.omit(Infl.trained), type="drift", selectlags = "BIC")

summary(ur.infl.drift) # null hypothesis is not rejected: non-stationary
# model with drift is the best model

ur.infl.trend<-ur.df(na.omit(Infl.trained), type = "trend", selectlags = "BIC")

summary(ur.infl.trend) # not stationary

# fixing none-stationarity
# take difference
delta.infl<-xts(Infl.trained-lag(Infl.trained))


# unit root test for the first diff of inflation

ur.deltainfl.none<-ur.df(na.omit(delta.infl), type="none",
                         selectlags = "BIC")
summary(ur.deltainfl.none)# reject null hypothesis of unit root so it is stationary
# no constat (drift) and no trend is the best model
ur.deltainfl.drift<-ur.df(na.omit(delta.infl), type="drift",
                          selectlags = "BIC")
summary(ur.deltainfl.drift) # it is stationary

ur.deltainfl.trend<-ur.df(na.omit(delta.infl), type="trend",
                          selectlags = "BIC")
summary(ur.deltainfl.trend) # it is stationary


# unitroot test for unemployment rate
# no drift- no trend
ur.unr.none<-ur.df(UNR.trained, type="none",
                   selectlags = "BIC")
summary(ur.unr.none) # it is not stationary


# just drift
ur.unr.drift<-ur.df(UNR.trained, type="drift",
                    selectlags = "BIC")
summary(ur.unr.drift) # it is stationary
# the most credible model


#model with drift and trend

ur.unr.trend<-ur.df(UNR.trained, type="trend",
                    selectlags = "BIC")
summary(ur.unr.trend) # not stationary

#############################################

#AR(p) models

bic<-c()
for( i in 1:5){
model<-dynlm(ts(delta.infl)~L(ts(delta.infl),1:i))
x<-BIC(model)
bic<-c(bic,x)
}

bic

fit<-dynlm(ts(delta.infl)~L(ts(delta.infl),1:5))
stargazer(fit, type="text")

#ADL

bic<-matrix(nrow=4, ncol=4)
for(i in 1:4){
  for(j in 1:4){
    model<-dynlm(ts(delta.infl)~L(ts(delta.infl),1:i)+L(ts(UNR.trained),1:j))
    bic[i,j]=BIC(model)
  }
}

bic
# ADL(2,2)

# calculating longterm effect

model<-dynlm(ts(delta.infl)~L(ts(delta.infl),1:2)+L(ts(UNR.trained),1:2))

model$coefficients

long.term.effect<-(model$coefficients[4]+model$coefficients[5])/(1-model$coefficients[2]-model$coefficients[3])
long.term.effect
