library(tidyverse)
library(haven)

df <- read_dta("Dropbox/Projects/Active_Projects/Mandate_Contribute/Make_Data/Shortfalls/Personnel_shortfall_data.dta")

df_1999 <- subset(df, year <= 2000)
df_2000 <- subset(df, year >= 2000)

df_1999 <- df_1999 %>%
  group_by(yearmon) %>%
  summarise(mean_prop_short = mean(propshortfalltroops, na.rm = TRUE)) %>%
  ungroup()

df_2000 <- df_2000 %>%
  group_by(yearmon) %>%
  summarise(mean_prop_short = mean(propshortfalltroops, na.rm = TRUE)) %>%
  ungroup()



ggplot(data = df_1999) + geom_smooth(aes(x = yearmon, y = mean_prop_short), method = "loess", na.rm = TRUE, color = "black") +
  geom_smooth(data = df_2000, aes(x = yearmon, y = mean_prop_short), method = "loess", na.rm = TRUE, color = "black") + 
  xlab("Year-Month") + 
  ylab("Average Shortfall Proportion") + 
  geom_vline(xintercept = c(2000), linetype = "dashed") + 
  geom_text(aes(x = 2003.09, y = 0.33, label = "Brahimi Report"), size = 3.5) 
  
  
  
  annotate("text", label = "Brahimi Report", x = 2001, y = 0.33)
  










