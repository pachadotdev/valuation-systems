# valuation ----

# not all countries report under the standard convention, this is to use
# FOB for exports and CIF for imports, the next script scrapes a year-country
# table that shows all reporters where we can see that some countries
# report imports as FOB

library(arrow)
library(dplyr)
library(tidyr)
library(purrr)
library(cepiigeodist)
library(broom)
library(forcats)

library(RSelenium)
library(rvest)
library(janitor)
library(stringr)
library(readr)

library(uncomtrademisc)

rmDr <- rsDriver(port = 4444L, browser = "firefox")

client <- rmDr$client

Y <- 1962:2020

url <- glue::glue("https://comtrade.un.org/db/mr/daExpNoteDetail.aspx?")
client$navigate(url)

html <- client$getPageSource()[[1]]

countries <- read_html(html) %>%
  html_element(css = "select#cR_ddlR.InputText") %>%
  html_nodes("option") %>%
  html_text()

ids <- read_html(html) %>%
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

try(dir.create("temp"))

for (y in Y) {
  message(y)
  fout <- glue::glue("temp/{y}.csv")

  if (!file.exists(fout)) {
    final_table <- data.frame()

    for (r in R) {
      # explore https://comtrade.un.org/db/mr/daExpNoteDetail.aspx in Firefox
      # javascript:__doPostBack('dgXPNotes$ctl24$ctl01','')

      url <- glue::glue("https://comtrade.un.org/db/mr/daExpNoteDetail.aspx?y={y}&r={r}")
      client$navigate(url)

      # i <- stringr::str_pad(i, 2, "left", "0")
      # client$executeScript(glue::glue("__doPostBack('dgXPNotes$ctl24$ctl{i}','')"))

      html <- client$getPageSource()[[1]]

      table <- read_html(html) %>%
        html_element(css = "table#dgXPNotes") %>%
        html_table(header = T) %>%
        clean_names() %>%
        filter(reporter != "1")

      table$r <- r
      table$y <- y

      final_table <- rbind(final_table, table)
    }

    readr::write_csv(final_table, fout)
    rm(final_table); gc()
  }
}

valuation <- purrr::map_df(
  list.files("temp", full.names = T),
  function(x) {
    readr::read_csv(x)
  }
)

valuation <- valuation %>%
  mutate(reporter = gsub("\\(.*", "", reporter)) %>%
  rename(
    uncomtrade_id = r,
    year = y
  ) %>%
  select(year, reporter, everything())

# This is what BACI mentions, but there are more cases not
# reporting imports as CIF
# not_cif <- c(
#   "dza", "geo",
#   # sacu
#   "zaf", "bwa", "lso", "nam", "swz"
# )

load("~/github/un_escap/comtrade-codes/01-2-tidy-country-data/country-codes.RData")

valuation <- valuation %>%
  # filter(trade_flow == "Import", valuation != "CIF") %>%
  left_join(country_codes %>%
              select(reporter = country_name_english, iso3_digit_alpha),
            by = "reporter")

valuation <- valuation %>%
  mutate(
    reporter = str_trim(reporter),
    iso3_digit_alpha = tolower(iso3_digit_alpha),
    iso3_digit_alpha = fix_iso_codes(iso3_digit_alpha)
  ) %>%
  select(year, reporter, iso3_digit_alpha, everything())

valuation %>%
  select(reporter, iso3_digit_alpha) %>%
  distinct() %>%
  filter(is.na(iso3_digit_alpha))

# raw_dataset_1989_2004 <- readRDS("~/UN ESCAP/baci-replication-try/raw_dataset_1989_2004.rds")
#
# r1 <- raw_dataset_1989_2004 %>%
#   select(exporter_iso) %>%
#   distinct() %>%
#   pull()
#
# r2 <- raw_dataset_1989_2004 %>%
#   select(importer_iso) %>%
#   distinct() %>%
#   pull()
#
# rm(raw_dataset_1989_2004); gc()

# countries_in_data <- tibble(
#   iso3_digit_alpha = as.character(sort(unique(r1, r2)))
# ) %>%
#   left_join(
#     country_codes %>%
#       select(reporter = country_name_english, iso3_digit_alpha) %>%
#       mutate(
#         iso3_digit_alpha = tolower(iso3_digit_alpha),
#         iso3_digit_alpha = fix_iso_codes(iso3_digit_alpha)
#       )
#   )

# these matches are inexact, but can be obtained by looking at full country
# names in the the official UN country names (i.e. So. African Customs Union vs
# South Africa (Southern African Customs Union until 2000)

# matches not found in the official table were looked upon Wikipedia

valuation <- valuation %>%
  mutate(
    iso3_digit_alpha = case_when(
      reporter == "Belgium-Luxembourg" ~ "bel",
      reporter == "Bolivia" ~ "bol",
      reporter == "Cabo Verde" ~ "cpv",
      reporter == "Czechia" ~ "cze",
      reporter == "East and West Pakistan" ~ "pak",
      reporter == "Eswatini" ~ "swz",
      reporter == "Fmr Arab Rep. of Yemen" ~ "yem",
      reporter == "Fmr Ethiopia" ~ "eth",
      reporter == "Fmr Fed. Rep. of Germany" ~ "deu",
      reporter == "Fmr Panama, excl.Canal Zone" ~ "pan",
      reporter == "Fmr Rep. of Vietnam" ~ "vnm",
      reporter == "Fmr Sudan" ~ "sdn",
      reporter == "India, excl. Sikkim" ~ "ind",
      reporter == "Neth. Antilles and Aruba" ~ "nld",
      reporter == "North Macedonia" ~ "mkd",
      reporter == "Saint Kitts, Nevis and Anguilla" ~ "kna",
      reporter == "So. African Customs Union" ~ "zaf",
      reporter == "USA" ~ "usa",
      TRUE ~ iso3_digit_alpha
    )
  )

valuation <- valuation %>%
  arrange(year, reporter)

valuation <- valuation %>%
  distinct() # some countries appear twice !!

saveRDS(valuation, "trade_valuation_system_per_country.rds")
