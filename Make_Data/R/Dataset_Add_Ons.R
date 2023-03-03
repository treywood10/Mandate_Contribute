### Data for Mandate_Contribution ###

# Packages #
library(tidyverse)
library(peacesciencer)
library(haven)


# Working directory #
setwd("~/Desktop/Mandate_Contribute/R")


# All states in system every month #
df <- create_stateyears(system = "cow", subset_years = 1990:2014) %>%
  mutate(month = 12) %>%
  uncount(month) %>%
  arrange(ccode, year) %>%
  mutate(month = rep(1:12, times = 4732))

write_dta(df, "COW_months.dta")


