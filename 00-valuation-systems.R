# valuation ----

# not all countries report under the standard convention, this is to use
# FOB for exports and CIF for imports, the next script scrapes a year-country
# table that shows all reporters where we can see that some countries
# report imports as FOB

# see this post

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
library(forcats)

library(RSelenium)
library(rvest)
library(purrr)
library(janitor)
library(stringr)
library(readr)

library(uncomtrademisc)

rmDr <- remoteDriver(port = 4444L, browserName = "chrome")
rmDr$open(silent = TRUE)

Y <- c(2001, 1999:1962)

fout <- "trade_valuation_system_per_country.rds"

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
    rm(new_table); gc()
  # }
}

valuation <- purrr::map_df(
  list.files("csv", full.names = T),
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

valuation <- valuation %>%
  # filter(trade_flow == "Import", valuation != "CIF") %>%
  left_join(
    country_codes %>%
      select(reporter = country_name_english, iso3_digit_alpha),
      by = "reporter"
  )

valuation <- valuation %>%
  mutate(
    reporter = str_trim(reporter),
    iso3_digit_alpha = tolower(iso3_digit_alpha),
    iso3_digit_alpha = case_when(
      iso3_digit_alpha == "rom" ~ "rou", # Romania
      iso3_digit_alpha == "yug" ~ "scg", # Just for joins purposes, Yugoslavia splitted for the analyzed period
      iso3_digit_alpha == "tmp" ~ "tls", # East Timor
      iso3_digit_alpha == "zar" ~ "cod", # Congo (Democratic Republic of the)
      TRUE ~ iso3_digit_alpha
    )
  ) %>%
  select(year, reporter, iso3_digit_alpha, everything())

valuation %>%
  select(reporter, iso3_digit_alpha) %>%
  distinct() %>%
  filter(is.na(iso3_digit_alpha))

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

valuation %>%
  select(reporter, iso3_digit_alpha) %>%
  distinct() %>%
  filter(is.na(iso3_digit_alpha))

valuation <- valuation %>%
  arrange(year, reporter)

valuation <- valuation %>%
  distinct() # some countries appear twice !!

saveRDS(valuation, "trade_valuation_system_per_country.rds")
