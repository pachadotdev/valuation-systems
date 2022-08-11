# valuation-systems

Uses web scraping to obtain whereas a country C in the year Y uses CIF, FOB or a special system to report imports or exports.

The standard is FOB for exports and CIF for imports, but that's not always the case.

This repo uses Selenium to import thousands of tables from UN COMTRADE into R. There is no readily available Excel or similar, except the RDS file I've included here.

Data preview for the end result:

```r
# A tibble: 15,148 × 11
    year reporter       iso3_digit_alpha reported_classi… reported_curren… trade_flow currency_conver… trade_system valuation
   <dbl> <chr>          <chr>            <chr>            <chr>            <chr>                 <dbl> <chr>        <chr>    
 1  1962 Angola         ago              SITC Rev.1       PTE              Import               0.0348 Special      CIF      
 2  1962 Angola         ago              SITC Rev.1       PTE              Export               0.0348 Special      FOB      
 3  1962 Morocco        mar              SITC Rev.1       MAD              Import               0.198  Special      CIF      
 4  1962 Morocco        mar              SITC Rev.1       MAD              Export               0.198  Special      FOB      
 5  1963 Morocco        mar              SITC Rev.1       MAD              Import               0.198  Special      CIF      
 6  1963 Morocco        mar              SITC Rev.1       MAD              Export               0.198  Special      FOB      
 7  1963 Myanmar        mmr              SITC Rev.1       MMK              Import               0.21   General      CIF      
 8  1963 Myanmar        mmr              SITC Rev.1       MMK              Export               0.21   General      FOB      
 9  1964 Brunei Daruss… brn              SITC Rev.1       BND              Import               0.327  Special      CIF      
10  1964 Brunei Daruss… brn              SITC Rev.1       BND              Export               0.327  Special      FOB      
# … with 15,138 more rows, and 2 more variables: partner <chr>, uncomtrade_id <dbl>
```
