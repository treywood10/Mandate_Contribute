### Make Graphs ----

# Packages ----
require(tidyverse)
require(haven)
require(ggplot2)
require(ggpubr)
library(lattice)  
library(MASS)     
library(VGAM)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#### Set Working Directory ####
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

setwd("~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Data_Analysis/R")


#~~~~~~~~~~~~~~~~#
#### Figure 1 ####
#~~~~~~~~~~~~~~~~#

# Data for histogram #
PKO <- read_dta("data/hist.dta")

hist1 <- ggplot(PKO, aes(x = troops)) +
  geom_histogram(binwidth = 200, color = "black") +
  ylim(c(0, 60000)) + 
  xlab("Number of Troops Contributed") +
  ylab("Frequency of Contribution Count") +
  ggtitle("Histogram of Military Troops") +
  theme(plot.title = element_text(hjust = 0.5, size = 40),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_Hist_DV_cont.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper",  width = 14, height = 12, dpi = 400)

PKO2 <- subset(PKO, troops > 0)

hist2 <- ggplot(PKO2, aes(x = troops)) +
  geom_histogram(binwidth = 200, color = "black") +
  ylim(0, 20000) +
  xlab("Number of Troops Contributed") +
  ylab("Frequency of Contribution Count") +
  ggtitle("Histogram of Military Troops, No 0's") +
theme(plot.title = element_text(hjust = 0.5, size = 40),
      legend.title = element_text(size = 20),
      legend.text = element_text(size = 20),
      legend.key.size = unit(1.5, "cm"),
      axis.text.x = element_text(size = 30),
      axis.text.y = element_text(size = 30),
      axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
      axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
      axis.ticks.length = unit(10, "pt"),
      text = element_text(family = "Times New Roman"))
ggsave("gg_Hist_DV_No_0_cont.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 400)

remove(hist1, hist2, PKO, PKO2)


#~~~~~~~~~~~~~~~~~~~~#
#### Figure 2: RR ####
#~~~~~~~~~~~~~~~~~~~~#

### Model 2 ###

# Import dataset #
dat <- read_dta("data/data_m2.dta")


# Betas #
betas <- as.matrix(read.table("betas/betas_m2.txt", header = T))


# var-cov #
vcov <- as.matrix(read.table("vcovs/vcovs_m2.txt", header = T))


# Simulate coefficients #
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


# Set values of X (lag_risk_ratio) #
x.of.i <- seq(from = 0.4, to = 1, by = .01)


# Representative observations #
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

rep_lag_best_2 <- mean(dat$lag_best_2, na.rm = TRUE)
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_same_continent <- getmode(dat$lag_same_continent)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)


# Create matrix of representative values and the incremental change in X #
set.x <- cbind(x.of.i, rep_lag_best_2, rep_lag_contributors, rep_lag_re_hat, rep_lag_un_change, rep_lag_GDP_cont, rep_lag_dem_cont,
               rep_lag_all_troops, rep_lag_cont_troop_prop, rep_lag_same_continent, rep_lag_bi_trade, rep_lag_joint_ios, rep_l_troops, 1)


# Multiply representative matrix and simulated coefficients for xB #
xB <- set.x %*% t(simb[,1:14])


# Exponentiation of xB for predicted values #
for(i in 1:length(x.of.i)) {
  xB[i, ] <- exp(xB[i,]) 
}


# Get median mfx's and middle 95% of simulated mfx's #
mfx_95 <- apply(X = xB, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


# Data frame of simulated mfx #
plot_m2 <- data.frame(X = x.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])


# Plot mfx of X #
plot <- ggplot(data = plot_m2) +
  geom_ribbon(alpha = .5, aes(x = X, ymin = Lower, ymax = Upper), fill = "gray50") +
  geom_line(data = plot_m2, aes(x = X, y = Median), linewidth = 1.5, lty = 1) +
  scale_x_continuous(limits = c(0.4, 1)) + 
  geom_rug(data = dat, aes(x = lag_risk_ratio, y = 2), sides = "b", position = position_jitter(w = 0.009, h = 0), alpha = 0.0099) +
  xlab(expression("Risk Ratio"[italic("t-1")])) +
  ylab("Predicted Monthly Troop Contributions") +
  ggtitle("Effect of Risk Ratio on Troop Contributions") +
  scale_y_continuous(limits = c(0, 70), breaks = c(0, 20, 40, 60)) + 
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_M2_sim.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 800)


### Model 4 ###

# Import dataset #
dat <- read_dta("data/data_m4.dta")


# Betas #
betas <- as.matrix(read.table("betas/betas_m4.txt", header = T))


# var-cov #
vcov <- as.matrix(read.table("vcovs/vcovs_m4.txt", header = T))


# Simulate coefficients #
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


# Set values of X (lag_risk_ratio) #
x.of.i <- seq(from = 0.4, to = 1, by = .01)


# Representative observations #
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

rep_lag_best_2 <- mean(dat$lag_best_2, na.rm = TRUE)
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_troops_short <- mean(dat$lag_troops_short, na.rm = TRUE)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_same_continent <- getmode(dat$lag_same_continent)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)


# Create matrix of representative values and the incremental change in X #
set.x <- cbind(x.of.i, rep_lag_best_2, rep_lag_contributors, rep_lag_re_hat, rep_lag_un_change, rep_lag_troops_short, rep_lag_GDP_cont,
               rep_lag_dem_cont, rep_lag_all_troops, rep_lag_cont_troop_prop, rep_lag_same_continent, rep_lag_bi_trade, rep_lag_joint_ios,
               rep_l_troops, 1)


# Multiply representative matrix and simulated coefficients for xB #
xB <- set.x %*% t(simb[,1:15])


# Exponentiation of xB for predicted values #
for(i in 1:length(x.of.i)) {
  xB[i, ] <- exp(xB[i,]) 
}


# Get median mfx's and middle 95% of simulated mfx's #
mfx_95 <- apply(X = xB, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


# Data frame of simulated mfx #
plot_m4 <- data.frame(X = x.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])


# Plot mfx of X #
plot <- ggplot(data = plot_m4) +
  geom_ribbon(alpha = .5, aes(x = X, ymin = Lower, ymax = Upper), fill = "gray50") +
  geom_line(data = plot_m4, aes(x = X, y = Median), linewidth = 1.5, lty = 1) +
  scale_x_continuous(limits = c(0.4, 1)) + 
  geom_rug(data = dat, aes(x = lag_risk_ratio, y = 2), sides = "b", position = position_jitter(w = 0.009, h = 0), alpha = 0.0099) +
  xlab(expression("Risk Ratio"[italic("t-1")])) +
  ylab("Predicted Monthly Troop Contributions") +
  ggtitle("Effect of Risk Ratio on Troop Contributions") +
  scale_y_continuous(limits = c(0, 70), breaks = c(0, 20, 40, 60)) + 
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_M4_sim.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 800)


#~~~~~~~~~~~~~~~~~~~~~~~~~#
#### Figure 3: RR X BD ####
#~~~~~~~~~~~~~~~~~~~~~~~~~#

# Model 3 #

# Import dataset #
rm(list = ls())
dat <- read_dta("data/data_m3.dta")


# Betas #
betas <- as.matrix(read.table("betas/betas_m3.txt", header = T))


# var-cov #
vcov <- as.matrix(read.table("vcovs/vcovs_m3.txt", header = T))


# Simulate coefficients #
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


# Set values of Z (lag_best) #
z.of.i <- seq(from = 0, to = 200, by = 1)


## Representative observations ##
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

rep_lag_risk_ratio <- mean(dat$lag_risk_ratio, na.rm = TRUE)
rep_inter <- mean(dat$lag_risk_ratio, na.rm = TRUE) * z.of.i # Value of interaction based on Z
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_same_continent <- getmode(dat$lag_same_continent)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)


### Create matrix of representative values and the incremental change in Z ###
set.x <- cbind(rep_lag_risk_ratio, z.of.i, rep_inter, rep_lag_contributors, rep_lag_re_hat,
               rep_lag_un_change, rep_lag_GDP_cont, rep_lag_dem_cont, rep_lag_all_troops,
               rep_lag_cont_troop_prop, rep_lag_same_continent, rep_lag_bi_trade, rep_lag_joint_ios,
               rep_l_troops, 1)


# Multiply representative matrix and simulated coefficients for xB #
xB <- set.x %*% t(simb[,1:15])


# Exponentiation of xB for predicted values #
for(i in 1:length(z.of.i)) {
  xB[i, ] <- exp(xB[i,]) 
}


# Gather X coefficients for partial derivative #
coefs_rr <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_rr[i,] <- t(simb[,1])
}


# Gather X*Z coefficients for partial derivative #
coefs_inter <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_inter[i,] <- t(simb[,3])
}


# Multiply X*Z coefficients by set values of Z #
mult <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:ncol(mult)) {
  mult[,i] <- coefs_inter[,i] * t(z.of.i)
}


# Add X coefficients and multiplications for analytical solution of partial derivative #
right <- coefs_rr + mult


# Multiply partial derivative and exp(xB) #
mfx <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:nsims) {
  mfx[,i] <- right[,i] * xB[,i]
}


# Get median mfx's and middle 95% of simulated mfx's #
mfx_95 <- apply(X = mfx, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


# Data frame of simulated mfx #
plot_m3 <- data.frame(X = z.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])


### Plot mfx of X ###
plot <- ggplot(data = plot_m3) +
  geom_ribbon(alpha = .5, aes(x = X, ymin = Lower, ymax = Upper), fill = "gray50") +
  geom_line(data = plot_m3, aes(x = X, y = Median), size = 1.5, lty = 1) +
  scale_x_continuous(limits = c(0, 200)) + 
  scale_y_continuous(limits = c(-280, 10), breaks = c(0, -50, -100, -150, -200, -250)) +
  geom_rug(data = dat, aes(x = lag_best, y = 10), sides = "b", position = position_jitter(w = 0.009, h = 0), alpha = 0.0099) +
  xlab(expression("Battle Deaths"[italic("t-1")])) +
  ylab("Marginal Effect of Risk Ratio on Contributions") +
  ggtitle("Effect of Risk Ratio and Battle Deaths on Troop Contributions") +
  geom_hline(yintercept = 0) +
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_M3_sim.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 800)


# Model 5 #

# Import dataset #
rm(list = ls())
dat <- read_dta("data/data_m5.dta")


# Betas #
betas <- as.matrix(read.table("betas/betas_m5.txt", header = T))


# var-cov #
vcov <- as.matrix(read.table("vcovs/vcovs_m5.txt", header = T))


# Simulate coefficients #
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


# Set values of Z (lag_best) #
z.of.i <- seq(from = 0, to = 200, by = 1)


## Representative observations ##
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

rep_lag_risk_ratio <- mean(dat$lag_risk_ratio, na.rm = TRUE)
rep_inter <- mean(dat$lag_risk_ratio, na.rm = TRUE) * z.of.i # Value of interaction based on Z
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_troops_short <- mean(dat$lag_troops_short, na.rm = TRUE)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_same_continent <- getmode(dat$lag_same_continent)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)


### Create matrix of representative values and the incremental change in Z ###
set.x <- cbind(rep_lag_risk_ratio, z.of.i, rep_inter, rep_lag_contributors, rep_lag_re_hat,
               rep_lag_un_change, rep_lag_troops_short, rep_lag_GDP_cont, rep_lag_dem_cont, rep_lag_all_troops,
               rep_lag_cont_troop_prop, rep_lag_same_continent, rep_lag_bi_trade, rep_lag_joint_ios,
               rep_l_troops, 1)


# Multiply representative matrix and simulated coefficients for xB #
xB <- set.x %*% t(simb[,1:16])


# Exponentiation of xB for predicted values #
for(i in 1:length(z.of.i)) {
  xB[i, ] <- exp(xB[i,]) 
}


# Gather X coefficients for partial derivative #
coefs_rr <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_rr[i,] <- t(simb[,1])
}


# Gather X*Z coefficients for partial derivative #
coefs_inter <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_inter[i,] <- t(simb[,3])
}


# Multiply X*Z coefficients by set values of Z #
mult <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:ncol(mult)) {
  mult[,i] <- coefs_inter[,i] * t(z.of.i)
}


# Add X coefficients and multiplications for analytical solution of partial derivative #
right <- coefs_rr + mult


# Multiply partial derivative and exp(xB) #
mfx <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:nsims) {
  mfx[,i] <- right[,i] * xB[,i]
}


# Get median mfx's and middle 95% of simulated mfx's #
mfx_95 <- apply(X = mfx, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


# Data frame of simulated mfx #
plot_m5 <- data.frame(X = z.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])


### Plot mfx of X ###
plot <- ggplot(data = plot_m5) +
  geom_ribbon(alpha = .5, aes(x = X, ymin = Lower, ymax = Upper), fill = "gray50") +
  geom_line(data = plot_m5, aes(x = X, y = Median), size = 1.5, lty = 1) +
  scale_x_continuous(limits = c(0, 200)) + 
  scale_y_continuous(limits = c(-280, 10), breaks = c(0, -50, -100, -150, -200, -250)) +
  geom_rug(data = dat, aes(x = lag_best, y = 10), sides = "b", position = position_jitter(w = 0.009, h = 0), alpha = 0.0099) +
  xlab(expression("Battle Deaths"[italic("t-1")])) +
  ylab("Marginal Effect of Risk Ratio on Contributions") +
  ggtitle("Effect of Risk Ratio and Battle Deaths on Troop Contributions") +
  geom_hline(yintercept = 0) +
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_M5_sim.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 800)


#~~~~~~~~~~~~~~~~#
#### Figure 4 ####
#~~~~~~~~~~~~~~~~#

# Set WD #
rm(list = ls())
setwd("~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Data_Analysis/R/Tasks")


# Create big dataframe #
all_mfx <- as.data.frame(matrix(ncol = 5, nrow = 0))
colnames(all_mfx) <- c("X", "Lower", "Median", "Upper", "Task")
all_mfx <- all_mfx %>%
  mutate(X = as.numeric("X"),
         Lower = as.numeric("Lower"),
         Median = as.numeric("Median"),
         Upper = as.numeric("Upper"),
         Task = as.factor("Task"))


### Vector for loop ###
tasks <- c("l_pe_ce_mon", "l_buf_mon", "l_lia_war", "l_pe_ce_as", 
           "l_ch7", "l_hr_mon", "l_ref_mon", "l_hr_pro", "l_chi_pro", "l_wo_pro", 
           "l_prociv", "l_un_pro", "l_demi_as", "l_ref_as", "l_ha_as", "l_hper_pro", 
           "l_bor_mon", "l_sec_ref_as", "l_pol_ref_as", "l_pol_mon", "l_pol_join", 
           "l_ddr_mon", "l_ddr_as" )

for(i in tasks){

### Clear Environment ###
dat <- read_dta("Task_data.dta")


# Betas #
betas <- as.matrix(read.table(paste0("betas_", i, ".txt"), header = T))




# var-cov ###
vcov <- as.matrix(read.table(paste0("vcovs_", i, ".txt"), header = T))



### Simulate coefficients
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


### Set Z ###
# lag_best #
z.of.i <- c(0, 15, 50)


## Representative observations ##
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}


rep_lag_task <- 1
rep_inter <- 1 * z.of.i # Value of interaction based on Z
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_same_continent <- getmode(dat$lag_same_continent)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)


### Create matrix of representative values and the incremental change in Z ###
set.x <- cbind(rep_lag_task, z.of.i, rep_inter, rep_lag_contributors, rep_lag_re_hat, rep_lag_un_change,
               rep_lag_GDP_cont, rep_lag_dem_cont, rep_lag_all_troops, rep_lag_cont_troop_prop,
               rep_lag_same_continent, rep_lag_bi_trade, rep_lag_joint_ios, rep_l_troops, 1)


### Multiply representative matrix and simulated coefficients for xB ###
xB <- set.x %*% t(simb[,1:15])


### Exponentiation of xB for predicted values ### 
for(j in 1:length(z.of.i)) {
  xB[j, ] <- exp(xB[j,]) 
}


### Gather X coefficients for partial derivative ###
coefs_rr <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(j in 1:length(z.of.i)) {
  coefs_rr[j,] <- t(simb[,1])
}


### Gather X*Z coefficients for partial derivative ###
coefs_inter <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(j in 1:length(z.of.i)) {
  coefs_inter[j,] <- t(simb[,3])
}


### Multiply X*Z coefficients by set values of Z ###
mult <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(j in 1:ncol(mult)) {
  mult[,j] <- coefs_inter[,j] * t(z.of.i)
}


### Add X coefficients and multiplications for analytical solution of partial derivative ###
right <- coefs_rr + mult


### Multiply partial derivative and exp(xB) ###
mfx <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(j in 1:nsims) {
  mfx[,j] <- right[,j] * xB[,j]
}


### Get median mfx's and middle 95% of simulated mfx's ###
mfx_95 <- apply(X = mfx, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


### Data frame of simulated mfx ###
plot_1 <- data.frame(X = z.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])
plot_1$Task <- paste0(i)


### Combine to big dataframe ###
all_mfx <- bind_rows(all_mfx, plot_1)
}


### Number tasks ###


### Prep for Graph ###
all_mfx$X <- factor(all_mfx$X, 
                          levels = c("0", "15", "50"))

all_mfx$Task <- factor(all_mfx$Task,
                          levels = c("l_pe_ce_mon", "l_buf_mon", "l_lia_war", "l_pe_ce_as", 
                                     "l_ch7", "l_hr_mon", "l_ref_mon", "l_hr_pro", "l_chi_pro", "l_wo_pro", 
                                     "l_prociv", "l_un_pro", "l_demi_as", "l_ref_as", "l_ha_as", "l_hper_pro", 
                                     "l_bor_mon", "l_sec_ref_as", "l_pol_ref_as", "l_pol_mon", "l_pol_join", 
                                     "l_ddr_mon", "l_ddr_as"))



### Plot mfx of task ###
plot <- ggplot(data = all_mfx[1:36,], aes(shape = reorder(X, desc(X)))) +
  geom_pointrange(data = all_mfx[1:36,], aes(x = reorder(Task, desc(Task)), y = Median, ymin = Lower, ymax = Upper),
                  position = position_dodge(width = 0.5),
                  fill = "WHITE", size = 10, fatten = .8, linewidth = 1.6) +
  coord_flip() +
  geom_hline(yintercept = 0) + 
  scale_y_continuous(limits = c(-20, 50), breaks = c(-30, -20, -10, 0, 10, 20, 30, 40, 50, 60)) + 
  ylab("") +
  guides(shape = guide_legend(reverse = TRUE, title = "Battle Deaths", override.aes = list(size = 1.5))) +
  scale_x_discrete(labels = c("l_pe_ce_mon" = "Monitor Agreement", "l_buf_mon" = "Monitor Buffer Zone",
                              "l_lia_war" = "Liaise War Parties", "l_pe_ce_as" = "Implement Agreement", 
                              "l_ch7" = "Chapter VII", "l_hr_mon" = "Monitor Human Rights", 
                              "l_ref_mon" = "Monitor Refugees", "l_hr_pro" = "Protect Human Rights", 
                              "l_chi_pro" = "Protect Children", "l_wo_pro" = "Protect Women", 
                              "l_prociv" = "Protect Civilians", "l_un_pro" = "Protect UN Personnel")) +
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        plot.subtitle = element_text(hjust = 0.5, size = 30),
        axis.title = element_text(size = 50),
        axis.title.y = element_blank(),
        axis.title.x = element_text(size = 50, margin = margin(20, 0, 0, 0)),
        legend.title = element_text(size = 50),
        legend.text = element_text(size = 50),
        legend.key.size = unit(2, "cm"),
        axis.text.x = element_text(size = 40),
        axis.text.y = element_text(size = 40),
        text = element_text(family = "Times New Roman"),
        plot.margin = margin(1, 1, 1, 1, "cm"),
        axis.ticks.length = unit(.25, "cm"),
        legend.position = "none")
ggsave("gg_Tasks_sim_1.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 18, height = 20, dpi = 800)


plot <- ggplot(data = all_mfx[37:69,], aes(shape = reorder(X, desc(X)))) +
  geom_pointrange(data = all_mfx[37:69,], aes(x = reorder(Task, desc(Task)), y = Median, ymin = Lower, ymax = Upper),
                  position = position_dodge(width = 0.5),
                  fill = "WHITE", size = 10, fatten = .8, linewidth = 1.6) +
  coord_flip() +
  geom_hline(yintercept = 0) + 
  scale_y_continuous(limits = c(-10, 60), breaks = c(-20, -10, 0, 10, 20, 30, 40, 50, 60)) + 
  ylab("") +
  guides(shape = guide_legend(reverse = TRUE, title = "Battle Deaths", override.aes = list(size = 1.5))) +
  scale_x_discrete(labels = c( "l_demi_as" = "Assist Demining", "l_ref_as" = "Assist Refugees", 
                              "l_ha_as" = "Assist Humanitarian", "l_hper_pro"= "Protect Humanitarian", 
                              "l_bor_mon" = "Monitor Borders", "l_sec_ref_as" = "Security Sector Reform", 
                              "l_pol_ref_as" = "Police Reform Assist", "l_pol_mon" = "Monitor the Police", 
                              "l_pol_join" = "Joint Patrols with Police", "l_ddr_mon" = "Monitor DDR", 
                              "l_ddr_as" = "Assist DDR")) +
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        plot.subtitle = element_text(hjust = 0.5, size = 30),
        axis.title = element_text(size = 50),
        axis.title.y = element_blank(),
        axis.title.x = element_text(size = 50, margin = margin(20, 0, 0, 0)),
        legend.title = element_text(size = 50),
        legend.text = element_text(size = 50),
        legend.key.size = unit(2, "cm"),
        axis.text.x = element_text(size = 40),
        axis.text.y = element_text(size = 40),
        text = element_text(family = "Times New Roman"),
        plot.margin = margin(1, 1, 1, 1, "cm"),
        axis.ticks.length = unit(.25, "cm"))
ggsave("gg_Tasks_sim_2.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 18, height = 20, dpi = 800)




#~~~~~~~~~~~~~~~~~~~~~~~#
### Appendix Figure 1 ###
#~~~~~~~~~~~~~~~~~~~~~~~#

### Import dataset ###
rm(list = ls())
setwd("~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Data_Analysis/R")
dat <- read_dta("data/data_m13.dta")


# Betas #
betas <- as.matrix(read.table("betas/betas_m13.txt", header = T))


# var-cov ###
vcov <- as.matrix(read.table("vcovs/vcovs_m13.txt", header = T))


### Simulate coefficients
nsims <- 20000
set.seed(1234)
simb <- mvrnorm(n = nsims, mu = betas, Sigma = vcov)


### Set Z ###
# lag_best #
z.of.i <- seq(from = 0, to = 200, by = 1)


## Representative observations ##
getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

rep_lag_risk_ratio <- mean(dat$lag_risk_ratio, na.rm = TRUE)
rep_inter <- mean(dat$lag_risk_ratio, na.rm = TRUE) * z.of.i # Value of interaction changes based on Z
rep_lag_contributors <- mean(dat$lag_contributors, na.rm = TRUE)
rep_lag_re_hat <- getmode(dat$lag_re_hat)
rep_lag_un_change <- getmode(dat$lag_un_change)
rep_lag_GDP_cont <- mean(dat$lag_GDP_cont, na.rm = TRUE)
rep_lag_dem_cont <- mean(dat$lag_dem_cont, na.rm = TRUE)
rep_lag_all_troops <- mean(dat$lag_all_troops, na.rm = TRUE)
rep_lag_cont_troop_prop <- mean(dat$lag_cont_troop_prop, na.rm = TRUE)
rep_lag_bi_trade <- mean(dat$lag_bi_trade, na.rm = TRUE)
rep_lag_joint_ios <- mean(dat$lag_joint_ios, na.rm = TRUE)
rep_l_troops <- mean(dat$l_troops, na.rm = TRUE)

### Create matrix of representative values and the incremental change in Z ###
set.x <- cbind(rep_lag_risk_ratio, z.of.i, rep_inter, rep_lag_contributors, rep_lag_re_hat, rep_lag_un_change,
               rep_lag_GDP_cont, rep_lag_dem_cont, rep_lag_all_troops, rep_lag_cont_troop_prop, rep_lag_bi_trade,
               rep_lag_joint_ios, rep_l_troops, 1)


### Multiply representative matrix and simulated coefficients for xB ###
xB <- set.x %*% t(simb[,1:14])


### Exponentiation of xB for predicted values ### 
for(i in 1:length(z.of.i)) {
  xB[i, ] <- exp(xB[i,]) 
}


### Gather X coefficients for partial derivative ###
coefs_rr <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_rr[i,] <- t(simb[,1])
}


### Gather X*Z coefficients for partial derivative ###
coefs_inter <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:length(z.of.i)) {
  coefs_inter[i,] <- t(simb[,3])
}


### Multiply X*Z coefficients by set values of Z ###
mult <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:ncol(mult)) {
  mult[,i] <- coefs_inter[,i] * t(z.of.i)
}


### Add X coefficients and multiplications for analytical solution of partial derivative ###
right <- coefs_rr + mult


### Multiply partial derivative and exp(xB) ###
mfx <- matrix(NA, nrow = length(z.of.i), ncol = nsims)

for(i in 1:nsims) {
  mfx[,i] <- right[,i] * xB[,i]
}


### Get median mfx's and middle 95% of simulated mfx's ###
mfx_95 <- apply(X = mfx, MARGIN = 1, FUN = quantile, probs = c(0.025, 0.5, 0.975))


### Data frame of simulated mfx ###
plot_m13 <- data.frame(X = z.of.i, Lower = mfx_95[1,], Median = mfx_95[2,],
                     Upper = mfx_95[3,])


### Plot mfx of X ###
plot <- ggplot(data = plot_m13) +
  geom_ribbon(alpha = .5, aes(x = X, ymin = Lower, ymax = Upper), fill = "gray50") +
  geom_line(data = plot_m13, aes(x = X, y = Median), size = 1.5, lty = 1) +
  scale_x_continuous(limits = c(0, 200)) + 
  scale_y_continuous(limits = c(-60, 10)) +
  geom_rug(data = dat, aes(x = lag_best, y = 10), sides = "b", position = position_jitter(w = 0.009, h = 0), alpha = 0.0099) +
  xlab(expression("Battle Deaths"[italic("t-1")])) +
  ylab("Marginal Effect of Risk Ratio on Contributions") +
  ggtitle("Effect of Risk Ratio and Battle Deaths on Troop Contributions", subtitle = "Same Continent, Major Power Sample") + 
  geom_hline(yintercept = 0) +
  theme(plot.title = element_text(hjust = 0.5, size = 35),
        plot.subtitle = element_text(hjust = 0.5, size = 25),
        legend.title = element_text(size = 20),
        legend.text = element_text(size = 20),
        legend.key.size = unit(1.5, "cm"),
        axis.text.x = element_text(size = 30),
        axis.text.y = element_text(size = 30),
        axis.title.y = element_text(size = 35, margin = margin(0, 15, 0, 0)),
        axis.title.x = element_text(size = 35, margin = margin(15, 0, 10, 0)),
        axis.ticks.length = unit(10, "pt"),
        text = element_text(family = "Times New Roman"))
ggsave("gg_M13_sim.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper", width = 14, height = 12, dpi = 800)





