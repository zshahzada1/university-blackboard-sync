# R-script for FN585 week4
setwd("~/Documents/econometric1/financil modeling/Week 3")

library(AER) # load Applied Econometrics with R library
library(parameters) # Load parameters library for robust SE computation
library(sandwich)
library(quantmod) # Load quantmod library for time series analysis
library(readxl) # Load readxl to load spreadsheet data
library(stats) # Load stats to compute acf functions
library(stargazer)


# load US macroeconomic data
usmac_qt <- read_xlsx("us_macro_quarterly.xlsx", sheet = 1, col_types = c("text", rep("numeric", 9)))
# Fix format of date
usmac_qt$...1 <- as.yearqtr(usmac_qt$...1, format = "%Y:0%q")
# Relabel column names in dataframe
colnames(usmac_qt)[1] <- "Date"


# GDP series as xts object
GDP <- xts(usmac_qt$GDPC96, usmac_qt$Date)["1960::2013"]
# GDP growth series as xts object
GDPGrowth <- xts(400 * log(GDP/lag(GDP)))

# Plot US quarterly GDP time series
plot(log(as.zoo(GDP)),
     col = "blue",
     lwd = 2,
     ylab = "Logarithm",
     xlab = "Date",
     main = "U.S. Quarterly Real GDP")

# Plot US quarterly GDP time series
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 2,
     ylab = "Growth Rates",
     xlab = "Date",
     main = "U.S. Quarterly Real GDP Growth Rates")

# ACF of US quarterly GDP
acf <- acf(na.omit(log(GDP)), lag.max = 8, plot = FALSE)
acf

# ACF of US quarterly GDP
acf <- acf(na.omit(log(GDP)), lag.max = 24, plot = FALSE)
plot(acf,main="log(GDP)")

# ACF of US quarterly GDP growth
acf <- acf(na.omit(GDPGrowth), lag.max = 24, plot = FALSE)
plot(acf, main = "GDP growth")



##########################

#part 2
#################################
GDPGrowth.train <- na.omit(GDPGrowth["1960::2002"]) 
# Plot US quarterly GDP time series w/ training data
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Growth Rates",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")


# AR(1) mode by ar.ols-function
ar1gdp.arols <- ar.ols(GDPGrowth.train, order.max = 1, 
                       demean = FALSE, intercept = TRUE)
ar1gdp.arols # Print output to console

# AR(1) model by dynlm-function

library(dynlm)
ar1gdp.lm<-dynlm(ts(GDPGrowth.train)~L(ts(GDPGrowth.train)))

stargazer(ar1gdp.lm, type="text")


ar1gdp.lmrob<-coeftest(ar1gdp.lm, vcov. = vcovHAC)
stargazer(ar1gdp.lm,ar1gdp.lmrob, type="text")
# Output w/ robust standard errors
#parameters(ar1gdp.lm, robust = TRUE, vcov_type = "HC1")


# Produce one-step ahead forecast of GDP growth for 2003:Q1
K=length(GDPGrowth.train)
fcast.ar1 <- ar1gdp.lm$coefficients %*% c(1, GDPGrowth.train[K])
fcast.ar1
# Forecast error
fcast.ar1.error <- as.numeric(GDPGrowth["2003"][1]) - fcast.ar1
fcast.ar1.error # Print to console

# Produce one-step ahead forecast of GDP growth for 2003:Q1



# Plot US quarterly GDP time series w/ forecast
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Growth Rates",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")
points(2003,fcast.ar1, cex = 1, col ="red")
points(2003,GDPGrowth["2003"][1], cex = 1, col ="blue")
legend("bottomright", inset = 0.02, c("Training series", "Realized value (2003:Q1)", "1-step-ahead forecast (2003:Q1)"),col=c("blue","blue","red"),pch=c(NA,1,1),lty=c(1,NA,NA),lwd = c(2,NA,NA))



library(dynlm) # Load dynlm to estimate higher-order autoregressions
ar4gdp.dynlm <- dynlm(ts(GDPGrowth.train) ~ L(ts(GDPGrowth.train)) + 
                        L(ts(GDPGrowth.train), 2) + 
                        L(ts(GDPGrowth.train), 3) + 
                        L(ts(GDPGrowth.train), 4)) 
ar4gdp.dynlm # Print to console


# Summary
stargazer(ar4gdp.dynlm, type="text")

# Output w/ robust standard errors
ar4gdp.dynlmrob<-coeftest(ar4gdp.dynlm, vcov. = vcovHAC)

stargazer(ar4gdp.dynlm,ar4gdp.dynlmrob,type="text")


# Produce one-step ahead forecast of GDP growth for 2003:Q1
fcast.ar4 <- ar4gdp.dynlm$coefficients %*% c(1, GDPGrowth.train[K], GDPGrowth.train[(K-1)], GDPGrowth.train[(K-2)], GDPGrowth.train[(K-3)])
fcast.ar4 # Print to console
# Forecast error
fcast.ar4.error <- as.numeric(GDPGrowth["2003"][1]) - fcast.ar4
c(fcast.ar1.error,fcast.ar4.error) # Print to console

# Plot US quarterly GDP time series w/ AR(1) and AR(4) forecasts
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Growth Rates",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")
points(2003,fcast.ar1, cex = 1, col ="red")
points(2003,fcast.ar4, cex = 1, col ="green")
points(2003,GDPGrowth["2003"][1], cex = 1, col ="blue")
legend("bottomright", inset = 0.02, c("Training series", "Realized value (2003:Q1)", "1-step-ahead forecast (2003:Q1), AR(1)","1-step-ahead forecast (2003:Q1), AR(4)"),col=c("blue","blue","red","green"),pch=c(NA,1,1,1),lty=c(1,NA,NA,NA),lwd = c(2,NA,NA,NA))




