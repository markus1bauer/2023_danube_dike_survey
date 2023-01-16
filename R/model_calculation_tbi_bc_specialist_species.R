# Beta diversity on dike grasslands
# Ratio of gains and losses of TBI - Target species ####
# Markus Bauer
# 2022-09-01



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# A Preparation ###############################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



### Packages ###
library(here)
library(tidyverse)
library(ggbeeswarm)
library(blme)
library(DHARMa)
library(sjPlot)
library(emmeans)

### Start ###
rm(list = ls())
setwd(here("data", "processed"))

### Load data ###
sites <- read_csv("data_processed_sites_temporal.csv",
                  col_names = TRUE, na = c("", "na", "NA"),
                  col_types =
                    cols(
                      .default = "?",
                      plot = "f",
                      block = "f",
                      comparison = "f",
                      location = "f",
                      location_construction_year = "f",
                      exposition = col_factor(levels = c("south", "north")),
                      orientation = col_factor(levels = c("land", "water"))
                    )) %>%
  filter(
    (comparison == "1718" | comparison == "1819" | comparison == "1921") &
      pool == "target" & presabu == "presence") %>%
  mutate(y = c - b,
         comparison = factor(comparison))

data_collinearity <- sites %>%
  select(where(is.numeric), -b, -c, -d, -y)

sites <- sites %>%
  mutate(across(c("river_km", "river_distance"), scale))



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# B Statistics ################################################################
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



## 1 Data exploration #########################################################


### a Graphs ------------------------------------------------------------------

mean(sites$y)
median(sites$y)
sd(sites$y)
Rmisc::CI(sites$y, ci = .95)
quantile(sites$y, probs = c(0.05, 0.95), na.rm = TRUE)
ggplot(sites, aes(x = comparison, y = y)) +
  geom_boxplot() +
  geom_quasirandom()
ggplot(sites, aes(x = exposition, y = y)) +
  geom_boxplot() +
  geom_quasirandom()
ggplot(sites, aes(x = orientation, y = y)) +
  geom_boxplot() +
  geom_quasirandom()
ggplot(sites, aes(x = river_km, y = (y))) +
  geom_point() +
  geom_smooth(method = "loess")
ggplot(sites, aes(x = location, y = y)) +
  geom_boxplot() +
  geom_quasirandom()
ggplot(sites, aes(x = (river_distance), y = (y))) +
  geom_point() +
  geom_smooth(method = "loess")
ggplot(sites, aes(x = pc1_soil, y = (y))) +
  geom_point() +
  geom_smooth(method = "lm")
ggplot(sites, aes(x = (pc2_soil), y = y)) +
  geom_point() +
  geom_smooth(method = "lm")
ggplot(sites, aes(x = exposition, y = y, color = comparison)) +
  geom_boxplot() +
  geom_quasirandom(dodge.width = .8)
ggplot(sites, aes(x = pc1_soil, y = y, color = comparison)) +
  geom_point() +
  geom_smooth(method = "lm")
ggplot(sites, aes(x = pc2_soil, y = y, color = comparison)) +
  geom_point() +
  geom_smooth(method = "lm")
ggplot(sites, aes(x = pc1_soil, y = y, color = exposition)) +
  geom_point() +
  geom_smooth(method = "lm")
ggplot(sites, aes(x = (pc2_soil), y = y, color = exposition)) +
  geom_point() +
  geom_smooth(method = "lm")


### b Outliers, zero-inflation, transformations? ------------------------------

dotchart((sites$y),
         groups = factor(sites$exposition),
         main = "Cleveland dotplot")
sites %>% count(location_construction_year)
sites %>%
  count(plot) %>%
  count(n)
boxplot(sites$y)
plot(table((sites$y)),
     type = "h", xlab = "Observed values", ylab = "Frequency")
ggplot(sites, aes(y)) +
  geom_density()
ggplot(sites, aes(log(y))) +
  geom_density()


### c check collinearity ------------------------------------------------------

GGally::ggpairs(data_collinearity, lower = list(continuous = "smooth_loess"))
# --> exclude r > 0.7
# Dormann et al. 2013 Ecography
# https://doi.org/10.1111/j.1600-0587.2012.07348.x
rm(data_collinearity)


## 2 Model building ###########################################################


### a models ------------------------------------------------------------------

### * Random structure ####
m1a <- blmer(y ~ 1 + (1 | location_construction_year),
             data = sites, REML = TRUE)
m1b <- blmer(y ~ 1 + (1 | location_construction_year / plot),
             data = sites, REML = TRUE)
m1c <- blmer(y ~ 1 + (1 | plot), data = sites, REML = TRUE)
MuMIn::AICc(m1a, m1b, m1c) %>%
  arrange(AICc)

### * Fixed effects ####
m1 <- blmer(
  y ~ (comparison + exposition + pc1_soil)^2 + pc2_soil + pc3_soil +
    orientation + river_distance + location_construction_year +
    (1 | plot),
  REML = FALSE,
  control = lmerControl(optimizer = "Nelder_Mead"),
  cov.prior = wishart,
  data = sites
)
simulateResiduals(m1, plot = TRUE)
m2 <- blmer(
  y ~ comparison + exposition * pc1_soil + pc2_soil + pc3_soil +
    orientation + river_distance + location_construction_year +
    (1 | plot),
  REML = FALSE,
  control = lmerControl(optimizer = "Nelder_Mead"),
  cov.prior = wishart,
  data = sites
  )
simulateResiduals(m2, plot = TRUE)
m3 <- blmer(
  y ~ comparison * exposition + pc1_soil + pc2_soil + pc3_soil + orientation +
    river_distance + location_construction_year +
    (1 | plot),
  REML = FALSE,
  control = lmerControl(optimizer = "Nelder_Mead"),
  cov.prior = wishart,
  data = sites
  )
simulateResiduals(m3, plot = TRUE)
m4 <- blmer(
  y ~ comparison * pc1_soil + exposition + pc2_soil + pc3_soil + orientation +
    river_distance + location_construction_year +
    (1 | plot),
  REML = FALSE,
  control = lmerControl(optimizer = "Nelder_Mead"),
  cov.prior = wishart,
  data = sites
  )
simulateResiduals(m4, plot = TRUE)
m5 <- blmer(
  y ~ comparison + exposition + pc1_soil + pc2_soil + pc3_soil + orientation +
    river_distance + location_construction_year +
    (1 | plot),
  REML = FALSE,
  control = lmerControl(optimizer = "Nelder_Mead"),
  cov.prior = wishart,
  data = sites
  )
simulateResiduals(m5, plot = TRUE)


### b comparison --------------------------------------------------------------

MuMIn::AICc(m1, m2, m3, m4, m5) %>%
  arrange(AICc)
# Use AICc and not AIC since ratio n/K < 40
# Burnahm & Anderson 2002 p. 66
# ISBN: 978-0-387-95364-9
dotwhisker::dwplot(list(m3, m5),
                   show_intercept = FALSE,
                   vline = geom_vline(
                     xintercept = 0,
                     colour = "grey60",
                     linetype = 2
                   )) +
  theme_classic()
m <- update(m3, REML = TRUE)
rm(list = setdiff(ls(), c("sites", "m")))


### c model check -------------------------------------------------------------

simulation_output <- simulateResiduals(m, plot = TRUE)
plotResiduals(simulation_output$scaledResiduals,
              sites$location_construction_year)
plotResiduals(simulation_output$scaledResiduals, sites$plot)
plotResiduals(simulation_output$scaledResiduals, sites$location)
plotResiduals(simulation_output$scaledResiduals, sites$comparison)
plotResiduals(simulation_output$scaledResiduals, sites$exposition)
plotResiduals(simulation_output$scaledResiduals, sites$orientation)
plotResiduals(simulation_output$scaledResiduals, sites$pc1_soil)
plotResiduals(simulation_output$scaledResiduals, sites$pc2_soil)
plotResiduals(simulation_output$scaledResiduals, sites$pc3_soil)
plotResiduals(simulation_output$scaledResiduals, sites$river_distance)
plotResiduals(simulation_output$scaledResiduals, sites$river_km)
car::vif(m)
# --> remove river_km > 3 or 10
# Zuur et al. 2010 Methods Ecol Evol
# https://doi.org/10.1111/j.2041-210X.2009.00001.x



## 3 Chosen model output ######################################################


### * Model output ####
MuMIn::r.squaredGLMM(m) # R2m = 0.294, R2c = 0.326
VarCorr(m)
sjPlot::plot_model(m, type = "re", show.values = TRUE)
dotwhisker::dwplot(m,
                   show_intercept = FALSE,
                   vline = geom_vline(
                     xintercept = 0,
                     colour = "grey60",
                     linetype = 2
                   )) +
  theme_classic()

### * Effect sizes ####
(emm <- emmeans(m, revpairwise ~ comparison | exposition, type = "response"))
plot(emm, comparison = TRUE)
sjPlot::plot_model(m, type = "emm", terms = c("comparison", "exposition"),
                   show.data = FALSE)