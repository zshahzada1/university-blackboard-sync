# R-script for FN585 WEEK 8


library(AER) # load Applied Econometrics with R library
library(parameters) # Load parameters library for robust SE computation
library(quantmod) # Load quantmod library for time series analysis
library(readxl) # Load readxl to load spreadsheet data
library(stats) # Load stats to compute acf functions
library(scales) # Load scales to be used in plots

# load US macroeconomic data
usmac_qt <- read_xlsx("us_macro_quarterly.xlsx", sheet = 1, col_types = c("text", rep("numeric", 9)))
# Fix format of date
usmac_qt$...1 <- as.yearqtr(usmac_qt$...1, format = "%Y:0%q")
# Relabel column names in dataframe
colnames(usmac_qt) <- c("Date", "GDPC96", "JAPAN_IP", "PCECTPI", 
                        "GS10", "GS1", "TB3MS", "UNRATE", "EXUSUK", "CPIAUCSL")
# GDP series as xts object
GDP <- xts(usmac_qt$GDPC96, usmac_qt$Date)["1960::2013"]
# GDP growth series as xts object
GDPGrowth <- xts(400 * log(GDP/lag(GDP)))
ishort <- xts(usmac_qt$TB3MS, usmac_qt$Date)["1960::2013"] 
ilong <- xts(usmac_qt$GS10, usmac_qt$Date)["1960::2013"] 
term.spread <- ilong - ishort
# Training data
GDPGrowth.train <- na.omit(GDPGrowth["1960::2002"]) 
ishort.train <- na.omit(ishort["1960::2002"]) 
ilong.train <- na.omit(ilong["1960::2002"])
term.spread.train <- na.omit(term.spread["1960::2002"])

# Plot US quarterly GDP time series w/ training data
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Growth Rates",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates")
abline(v = 2002.75, lty = "dashed")
abline(h = 0, lwd = 1)
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")

# Plot US short and long term interest rates
plot(as.zoo(ishort),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Percent per annum",
     xlab = "Date",
     main = "U.S. short and long interes rates")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(ilong), lwd = 1, col = "red",lty = "dashed")
lines(as.zoo(ishort.train), lwd = 2, col = "blue")
lines(as.zoo(ilong.train), lwd = 2, col = "red")
legend("topright", inset = 0.02, c("3-mth interest rate", "3-mth interest rate (training)", "10-year interest rate", "10-year interest rate (training)"),col=c("blue","blue","red","red"),lty=c(2,1,2,1),lwd = c(1,2,1,2))

# Plot US term spread
plot(as.zoo(term.spread),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Percent per annum",
     xlab = "Date",
     main = "U.S. term spread")
abline(v = 2002.75, lty = "dashed")
abline(h = 0, lwd = 1)
lines(as.zoo(term.spread.train), lwd = 2, col = "blue")

# Plot US GDP growth and term spread
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Percent per annum",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates and the Term Spread")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")
lines(as.zoo(term.spread), col = "red", lwd = 1, lty = "dashed")
lines(as.zoo(term.spread.train), lwd = 2, col = "red")
abline(h = 0, lwd = 1)
# define function that transform years to class 'yearqtr'
YToYQTR <- function(years) {
        return(
                sort(as.yearqtr(sapply(years, paste, c("Q1", "Q2", "Q3", "Q4"))))
        )
}
# recessions
recessions <- YToYQTR(c(1961:1962, 1970, 1974:1975, 1980:1982, 1990:1991, 2001, 2007:2008))
# add color shading for recessions
xblocks(time(as.zoo(ishort)), 
        c(time(ishort) %in% recessions), 
        col = alpha("gray", alpha = 0.3))
legend("topright", inset = 0.02, c("GDP growth", "GDP growth (training)", "Term spread", "Term spread (training)"),col=c("blue","blue","red","red"),lty=c(2,1,2,1),lwd = c(1,2,1,2))


# Estimating ADL(4,4)-model for US GDP growth
library(dynlm) # Load dynlm to estimate higher-order autoregressions
library(sandwich)
library(stargazer)
ADL44.dynlm <- dynlm(ts(GDPGrowth.train) ~ L(ts(GDPGrowth.train)) + L(ts(GDPGrowth.train), 2) + 
                             L(ts(GDPGrowth.train), 3) + L(ts(GDPGrowth.train), 4) + 
                             L(ts(term.spread.train)) + L(ts(term.spread.train), 2) +
                             L(ts(term.spread.train), 3) + L(ts(term.spread.train), 4)) 


# Output w/ robust standard errors
ADL44.Robdynlm<-coeftest(ADL44.dynlm, vcov. = vcovHAC)

stargazer(ADL44.dynlm,ADL44.Robdynlm, type="text")
stargazer(ADL44.dynlm,ADL44.Robdynlm)


# Produce one-step ahead forecast of GDP growth for 2001:Q1
K<-length(GDPGrowth.train) # Length of observed series
fcast.ADL44 <- ADL44.dynlm$coefficients %*% c(1, GDPGrowth.train[K], GDPGrowth.train[(K-1)], GDPGrowth.train[(K-2)], GDPGrowth.train[(K-3)],
                                              term.spread.train[K], term.spread.train[(K-1)], term.spread.train[(K-2)], term.spread.train[(K-3)])
fcast.ADL44 # Print to console
# Forecast error
fcast.ADL44.error <- as.numeric(GDPGrowth["2003"][1]) - fcast.ADL44
fcast.ADL44.error # Print to console

# Plot US GDP growth and term spread w/ forecasts
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Percent per annum",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates and the Term Spread")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")
lines(as.zoo(term.spread), col = "red", lwd = 1, lty = "dashed")
lines(as.zoo(term.spread.train), lwd = 2, col = "red")
abline(h = 0, lwd = 1)
# define function that transform years to class 'yearqtr'
YToYQTR <- function(years) {
        return(
                sort(as.yearqtr(sapply(years, paste, c("Q1", "Q2", "Q3", "Q4"))))
        )
}
# recessions
recessions <- YToYQTR(c(1961:1962, 1970, 1974:1975, 1980:1982, 1990:1991, 2001, 2007:2008))
# add color shading for recessions
xblocks(time(as.zoo(ishort)), 
        c(time(ishort) %in% recessions), 
        col = alpha("gray", alpha = 0.3))
points(2003,fcast.ADL44, cex = 1, col ="green")
points(2003,GDPGrowth["2003"][1], cex = 1, col ="blue")
legend("topright", inset = 0.02, c("GDP growth", "GDP growth (training)", "Term spread", "Term spread (training)","Realized growth (2003:Q1)","ADL(4,4) forecasted growth (2003:Q1)"),col=c("blue","blue","red","red","blue","green"),lty=c(2,1,2,1,NA,NA),lwd = c(1,2,1,2,NA,NA),pch=c(NA,NA,NA,NA,1,1))


# Estimating ADL(2,1)-model for US GDP growth
ADL22.dynlm <- dynlm(ts(GDPGrowth.train) ~ L(ts(GDPGrowth.train))  +L(ts(GDPGrowth.train),2)+ L(ts(term.spread.train))+L(ts(term.spread.train),2)) 
ADL22.Robdynlm<-coeftest(ADL22.dynlm, vcov. = vcovHAC)

stargazer(ADL22.dynlm, ADL22.Robdynlm, type="text")

# Produce one-step ahead forecast of GDP growth for 2001:Q1
fcast.ADL22 <- ADL22.dynlm$coefficients %*% c(1, GDPGrowth.train[K], GDPGrowth.train[K-1],term.spread.train[K], term.spread.train[K-1])
fcast.ADL22 # Print to console
# Forecast error
fcast.ADL22.error <- as.numeric(GDPGrowth["2003"][1]) - fcast.ADL22
fcast.ADL22.error # Print to console

# Plot US GDP growth and term spread
plot(as.zoo(GDPGrowth),
     col = "blue",
     lwd = 1,
     lty = "dashed",
     ylab = "Percent per annum",
     xlab = "Date",
     main = "U.S. Real GDP Growth Rates and the Term Spread")
abline(v = 2002.75, lty = "dashed")
lines(as.zoo(GDPGrowth.train), lwd = 2, col = "blue")
lines(as.zoo(term.spread), col = "red", lwd = 1, lty = "dashed")
lines(as.zoo(term.spread.train), lwd = 2, col = "red")
abline(h = 0, lwd = 1)
# define function that transform years to class 'yearqtr'
YToYQTR <- function(years) {
        return(
                sort(as.yearqtr(sapply(years, paste, c("Q1", "Q2", "Q3", "Q4"))))
        )
}
# recessions
recessions <- YToYQTR(c(1961:1962, 1970, 1974:1975, 1980:1982, 1990:1991, 2001, 2007:2008))
# add color shading for recessions
xblocks(time(as.zoo(ishort)),
        c(time(ishort) %in% recessions),
        col = alpha("gray", alpha = 0.3))
points(2003,fcast.ADL44, cex = 1, col ="green")
points(2003,fcast.ADL22, cex = 1, col ="orange")
points(2003,GDPGrowth["2003"][1], cex = 1, col ="blue")
legend("topright", inset = 0.02, c("GDP growth", "GDP growth (training)", "Term spread", "Term spread (training)","Realized growth (2003:Q1)","ADL(4,4) forecasted growth (2003:Q1)","ADL(2,2) forecasted growth (2003:Q1)"),col=c("blue","blue","red","red","blue","green","orange"),lty=c(2,1,2,1,NA,NA,NA),lwd = c(1,2,1,2,NA,NA,NA),pch=c(NA,NA,NA,NA,1,1,1))


