library(tidyverse)
library(haven)
library(lubridate)

df <- read_dta("Dropbox/Projects/Active_Projects/Mandate_Contribute/Make_Data/Shortfalls/Personnel_shortfall_data.dta")

df <- df %>%
  mutate(date = make_date(year = df$year, month = df$month))

df_1999 <- subset(df, year <= 1999)
df_2000 <- subset(df, year >= 2000)


df_1999 <- df_1999 %>%
  group_by(date) %>%
  summarise(mean_prop_short = mean(propshortfalltroops, na.rm = TRUE)) %>%
  ungroup()

df_2000 <- df_2000 %>%
  group_by(date) %>%
  summarise(mean_prop_short = mean(propshortfalltroops, na.rm = TRUE)) %>%
  ungroup()

dateline = as.Date("2000-01-01")
date_text = as.Date("2003-01-01")


ggplot(data = df_1999) + geom_smooth(aes(x = date, y = mean_prop_short), method = "loess", na.rm = TRUE, color = "black") +
  geom_smooth(data = df_2000, aes(x = date, y = mean_prop_short), method = "loess", na.rm = TRUE, color = "black") +
  xlab("Year") +
  ylim(c(0, 0.45)) + 
  ylab("Average Shortfall Proportion") + 
  ggtitle("Average Shortfall Proportion Over Time") +
  geom_vline(xintercept = dateline, linetype = "dashed") + 
  geom_text(aes(x = date_text, y = 0.33, label = "Brahimi Report"), size = 10) + 
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
ggsave("gg_shortfall_learning.jpg", path = "~/Dropbox/Projects/Active_Projects/Mandate_Contribute/Paper",  width = 14, height = 12, dpi = 400)
  
  
  











