# ============================================================
# State-level ACS data pull via tidycensus
# Variables: insurance coverage, educational attainment, median income, 
# poverty rate
# ============================================================

library(tidycensus)
library(dplyr)
library(readxl)
library(janitor)

# ---- One-time setup ----
# You don't need to run this full script, because the output of this script is 
# the clean data, which can be found in clean_state_data.csv, so all you need to 
# do is load that csv using: read.csv("data/clean_state_data.csv")

# If you do want to run this full script, you need a free Census API key, 
# which you can get here: https://api.census.gov/data/key_signup.html
# Once you have the key, uncomment the following line and paste your key where 
# it says <YOUR KEY HERE>:
# census_api_key(<YOUR KEY HERE>, install = TRUE)
# Make sure not to commit your key to github!

# To browse all available variables (useful for swapping in alternates):
# vars_subject <- load_variables(2024, "acs1/subject", cache = TRUE)
# vars_detail  <- load_variables(2024, "acs1",         cache = TRUE)
# View(vars_subject)

# ---- Config ----
# Using 2024 1-year ACS (released Sep 2025). Covers 2024 only, most recent year 
# available
acs_year <- 2024

# Subject tables (S-prefix) give pre-computed percentages.
# Detail tables (B-prefix) give counts/dollar values directly.
vars <- c(
  pct_insured        = "S2701_C03_001",  # % with any health insurance coverage
  pct_bachelors_plus = "S1501_C02_015",  # % age 25+ with bachelor's degree or higher
  median_hh_income   = "B19013_001",     # median household income (inflation-adjusted $)
  pct_poverty        = "S1701_C03_001"   # % of people below poverty line
)

# ---- Pull ----
# <var>E gives the estimate 
# <var>M gives the margin of error (MOE), which for ACS is half the width of the 
# 90% confidence interval around the estimate
# Note we likely will not need the MOEs but including them in case we do
state_acs <- get_acs(
  geography = "state",
  variables = vars,
  year      = acs_year,
  survey    = "acs1",
  output    = "wide"
) |>
  rename(state = NAME) |>
  select(-GEOID)

# ============================================================
# Rural/urban from 2020 Decennial Census (not in ACS, 2020 most 
# recent estimate)
# ============================================================
# Note I could not find this via the API so I downloaded the csv directly from:
# https://www.census.gov/programs-surveys/geography/guidance/geo-areas/urban-rural.html

ur_raw <- read_excel("data/State_Urban_Rural_Pop_2020_2010.xlsx") |>
  clean_names() |>
  rename(
    pct_urban  = x2020_pct_urban_pop,   
    pct_rural  = x2020_pct_rural_pop    
  ) |>
  select(state_name, pct_urban, pct_rural)

# ============================================================
# State public health funding per capita
# ============================================================
# Note I also could not find this via API so downloaded from:
# https://statehealthcompare.shadac.org/landing/117/per-person-state-public-health-funding

state_phf <- read.csv("data/state_phf_raw.csv", na = c("", "NA", "N/A")) |>
  rename(state = Location,
         year = TimeFrame,
         phf_per_capita = Data) |>
  filter(year == 2025) |>
  select(state, phf_per_capita)

# ============================================================
# Measles data
# ============================================================
# Downloaded from:
# https://docs.google.com/spreadsheets/d/17e3JSDhVec4wIkuQIFdtdGCupySj9KsbdqbDwJ-hkQM/edit?gid=175064361#gid=175064361

measles <- read.csv("data/measles_data.csv") |>
  clean_names() |>
  select(state, measles_cases, population) |>
  mutate(population = as.numeric(gsub(",", "", population)),
         cases_per_100k = measles_cases/population*100000)

# ============================================================
# Exposure (policy) data
# ============================================================

exposure<-read.csv("data/exposure_vaccine_policy.csv") |>
  clean_names() |>
  select(state, policy, exposure_binary)
  
# ============================================================
# Merge ACS, urban/rural, state PHF per capita, and exposure
# ============================================================

clean_state_data <- measles |>
  left_join(state_acs, by = c("state" = "state")) |>
  left_join(ur_raw, by = c("state" = "state_name")) |>
  left_join(state_phf, by = c("state" = "state")) |>
  left_join(exposure, by = c("state" = "state"))

# ---- Write out ----
write.csv(clean_state_data, "data/clean_state_data.csv", row.names = FALSE)
