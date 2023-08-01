# valuation ----

# not all countries report under the standard convention, this is to use
# FOB for exports and CIF for imports, the next script scrapes a year-country
# table that shows all reporters where we can see that some countries
# report imports as FOB

url_jar <- "https://github.com/SeleniumHQ/selenium/releases/download/selenium-3.9.1/selenium-server-standalone-3.9.1.jar"
sel_jar <- "selenium-server-standalone-3.9.1.jar"

if (!file.exists(sel_jar)) {
  download.file(url_jar, sel_jar)
}

# now we need to run selenium from a terminal
# i.e.
# open a bash terminal in vs code alongside the R interactive tab, then run
# apt-get install chromium-brower
# # then java -jar selenium-server-standalone-3.9.1.jar

library(dplyr)
library(tidyr)

library(RSelenium)
library(rvest)
library(purrr)
library(janitor)
library(stringr)
library(readr)

fout <- "trade_valuation_system_per_country.csv"

rmDr <- remoteDriver(port = 4444L, browserName = "chrome")
rmDr$open(silent = TRUE)

Y <- 2021:1962

# if (file.exists(fout)) {
#   valuation <- readRDS(fout)
#   Y2 <- unique(valuation$year)
#   Y <- Y[!Y %in% Y2]
# }

url <- "https://comtrade.un.org/db/mr/daExpNoteDetail.aspx?"

rmDr$navigate(url)

html <- read_html(rmDr$getPageSource()[[1]])

countries <- html %>%
  html_element(css = "select#cR_ddlR.InputText") %>%
  html_nodes("option") %>%
  html_text()

ids <- html %>%
  html_element(css = "select#cR_ddlR.InputText") %>%
  html_nodes("option") %>%
  html_attr("value")

countries <- tibble(
  country = countries,
  country_id = ids
)

R <- str_split(countries$country_id, ",")
R <- as.integer(unique(unlist(R)))
R <- R[!is.na(R)]

try(dir.create("csv"))

for (y in Y) {
  message(y)
  fout2 <- glue::glue("csv/{y}.csv")

  # if (!file.exists(fout)) {
    new_table <- map_df(
      R,
      function(r) {
        print(r)

        # explore https://comtrade.un.org/db/mr/daExpNoteDetail.aspx in Firefox
        # javascript:__doPostBack('dgXPNotes$ctl24$ctl01','')

        url <- glue::glue("https://comtrade.un.org/db/mr/daExpNoteDetail.aspx?y={y}&r={r}")
        rmDr$navigate(url)

        html2 <- read_html(rmDr$getPageSource()[[1]])

        table <- html2 %>%
          html_element(css = "table#dgXPNotes") %>%
          html_table(header = T) %>%
          clean_names() %>%
          filter(reporter != "1")

        table$r <- r
        table$y <- y

        # avoid ! Can't combine `..1$reporter` <integer> and `..2$reporter` <character>.
        table <- table %>%
          mutate_if(is.numeric, as.character)

        return(table)
      }
    )
    
    write_csv(new_table, fout2)
    rm(new_table)
  # }
}

valuation <- map_df(
  list.files("csv", full.names = T),
  function(x) {
    read_csv(x)
  }
)

valuation <- valuation %>%
  mutate(reporter = gsub("\\(.*", "", reporter)) %>%
  rename(
    uncomtrade_id = r,
    year = y
  ) %>%
  select(year, reporter, everything())

valuation %>%
  filter(reporter == "Japan" & year == 1975)

glimpse(valuation)

valuation <- valuation %>%
  mutate(
    year = as.integer(year),
    uncomtrade_id = as.integer(uncomtrade_id)
  )

# This is what BACI mentions, but there are more cases not
# reporting imports as CIF
# not_cif <- c(
#   "dza", "geo",
#   # sacu
#   "zaf", "bwa", "lso", "nam", "swz"
# )

load("~/github/un_escap/comtrade-codes/01-2-tidy-country-data/country-codes.RData")

valuation <- map_df(
  sort(unique(valuation$year)),
  function(y) {
    # y = 1975
    d <- valuation %>%
      filter(year == y) %>%
      left_join(
        country_codes %>%
          as_tibble() %>%
          mutate(
            start_valid_year = as.integer(start_valid_year),
            end_valid_year = as.integer(end_valid_year)
          ) %>%
          filter(
            start_valid_year <= y,
            end_valid_year >= y
          ) %>%
          select(reporter = country_name_english, country_iso = iso3_digit_alpha, country_code),
          by = "reporter"
      )

    # d %>%
    #   filter(reporter == "Japan")

    return(d)
  }
)

valuation <- valuation %>%
  mutate(
    reporter = str_trim(reporter),
    country_iso = tolower(country_iso),
    country_iso = case_when(
      country_iso == "rom" ~ "rou", # Romania
      country_iso == "tmp" ~ "tls", # East Timor
      country_iso == "zar" ~ "cod", # Congo (Democratic Republic of the)
      TRUE ~ country_iso
    )
  ) %>%
  select(year, reporter, country_iso, country_code, everything())

valuation %>%
  filter(country_iso %in% c("rou", "tls", "cod")) %>%
  group_by(reporter) %>%
  filter(year == min(year))

valuation %>%
  filter(is.na(country_iso)) %>%
  distinct(reporter)

# these matches are inexact, but can be obtained by looking at full country
# names in the the official UN country names (i.e. So. African Customs Union vs
# South Africa (Southern African Customs Union until 2000)

# matches not found in the official table were looked upon Wikipedia

valuation <- valuation %>%
  mutate(
    country_iso = case_when(
      reporter == "Belgium-Luxembourg" ~ "bel",
      reporter == "Bolivia" ~ "bol",
      reporter == "Cabo Verde" ~ "cpv",
      reporter == "Czechia" ~ "cze",
      reporter == "East and West Pakistan" ~ "pak",
      reporter == "Eswatini" ~ "swz",
      reporter == "Fmr Arab Rep. of Yemen" ~ "yem",
      reporter == "Fmr Ethiopia" ~ "eth",
      reporter == "Fmr Fed. Rep. of Germany" ~ "ddr",
      reporter == "Fmr Panama, excl.Canal Zone" ~ "pan",
      reporter == "Fmr Rep. of Vietnam" ~ "vnm",
      reporter == "Fmr Sudan" ~ "sdn",
      reporter == "India [...1974]" ~ "ind", # India, excl. Sikkim
      reporter == "Neth. Antilles and Aruba" ~ "nld", # ant applies from 1988
      reporter == "North Macedonia" ~ "mkd",
      reporter == "Saint Kitts, Nevis and Anguilla" ~ "kna",
      reporter == "So. African Customs Union" ~ "zaf",
      reporter == "USA" ~ "usa",
      TRUE ~ country_iso
    ),
    country_code = case_when(
      reporter == "Belgium-Luxembourg" ~ 58, # 56 applies from 1999 
      reporter == "Bolivia" ~ 68,
      reporter == "Cabo Verde" ~ 132,
      reporter == "Czechia" ~ 203,
      reporter == "East and West Pakistan" ~ 586,
      reporter == "Eswatini" ~ 748,
      reporter == "Fmr Arab Rep. of Yemen" ~ 886,
      reporter == "Fmr Ethiopia" ~ 230,
      reporter == "Fmr Fed. Rep. of Germany" ~ 278,
      reporter == "Fmr Panama, excl.Canal Zone" ~ 590,
      reporter == "Fmr Rep. of Vietnam" ~ 704,
      reporter == "Fmr Sudan" ~ 736,
      reporter == "India [...1974]" ~ 699, # India, excl. Sikkim
      reporter == "Neth. Antilles and Aruba" ~ 532,
      reporter == "North Macedonia" ~ 807,
      reporter == "Saint Kitts, Nevis and Anguilla" ~ 658,
      reporter == "So. African Customs Union" ~ 711,
      reporter == "USA" & year < 1981 ~ 841,
      reporter == "USA" & year >= 1981 ~ 842,
      TRUE ~ country_code
    )
  )

valuation %>%
  select(reporter, country_iso) %>%
  distinct() %>%
  filter(is.na(country_iso))

valuation <- valuation %>%
  mutate(
    country_iso = case_when(
      reporter == "Other Asia, nes" ~ "0-unspecified",
      reporter == "State of Palestine" ~ "pse",
      TRUE ~ country_iso
    ),
    country_code = case_when(
      reporter == "Other Asia, nes" ~ 490,
      reporter == "State of Palestine" ~ 275,
      TRUE ~ country_code
    )
  )

valuation %>%
  select(reporter, country_iso, country_code) %>%
  distinct() %>%
  filter(is.na(country_iso))
  
valuation <- valuation %>%
  filter(!reporter %in% c("EU", "EU-28")) %>%
  arrange(year, reporter)

glimpse(valuation)

unique(valuation$trade_flow)

valuation <- valuation %>%
  distinct() %>% # there are duplicates !!!
  select(-uncomtrade_id) %>%
  mutate(
    trade_flow = tolower(trade_flow),
    trade_flow = paste0(trade_flow, "s")
  ) %>%
  pivot_wider(
    names_from = trade_flow,
    values_from = c(reported_classification, reported_currency, currency_conversion_factor,
      trade_system, valuation, partner)
  )

valuation <- valuation %>%
  select(-reporter)

valuation <- valuation %>%
  mutate_if(is.character, function(x) { str_squish(str_to_lower(x))})

valuation %>%
  group_by(year, country_iso, country_code) %>%
  count() %>%
  filter(n > 1)

valuation %>%
  filter(country_iso == "ddr", year == 1985) %>%
  glimpse()

# fix duplicates

valuation <- valuation %>%
  distinct()

colnames(valuation)

# fix valuation
valuation %>%
  ungroup() %>%
  distinct(valuation_imports)

valuation %>%
  ungroup() %>%
  distinct(valuation_exports)

valuation <- valuation %>%
  ungroup() %>%
  mutate(
    valuation_imports = ifelse(valuation_imports == "null", NA, valuation_imports),
    valuation_exports = ifelse(valuation_exports == "null", NA, valuation_exports)
  )

valuation %>%
  distinct(partner_imports)

valuation %>%
  distinct(partner_exports)

valuation <- valuation %>%
  mutate(
    partner_imports = case_when(
      partner_imports == "origin/consignment for intra eu" ~ "origin/consignment for intra-eu",
      partner_imports == "n/a" ~ NA_character_,
      TRUE ~ partner_imports
    ),
    partner_exports = ifelse(partner_exports == "n/a", NA, partner_exports)
  )

# replace all infinite values with NA
valuation <- valuation %>%
  mutate_if(is.numeric, function(x) { ifelse(is.infinite(x), NA, x) })

valuation %>%
  filter(country_iso == "jpn", year == 1975) %>%
  select(starts_with("valuation"))

write_csv(valuation, fout)
