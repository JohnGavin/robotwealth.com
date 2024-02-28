# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_data <- tar_plan( # rlang::list2( ----
  tar_target(aprms, prms),
  # two data sources
  # 1/2) csv: perpetual futures contracts
  # daily price, volume, and funding data
  # traded on Binance since late 2019
  tar_files(url_csv, "https://github.com/Robot-Wealth/r-quant-recipes/raw/master/quantifying-combining-alphas/binance_perp_daily.csv",
    format = c("url", "file", "file_fast", "aws_file")[1]
  ),
  # crypto perpetual futures contracts traded on Binance since late 2019
  tar_target(perps_lst,
    read_csv(url_csv, show_col_types = FALSE),
    pattern = map(url_csv)
  ),
  tar_target(perps_all, perps_lst,
    iteration = "vector"
  ),
  # stablecoins via  (defi)
  # 2/2) vector of stablecoin symbols
  # traded on llama.fi (defi)
  tar_files(url_stables_llama, "https://stablecoins.llama.fi/stablecoins?includePrices=true",
    format = "url"
  ),
  tar_target(stables_llama_lst,
    get_symbols_stables_llama(url_stables_llama),
    pattern = map(url_csv)
  ),
  # TODO: move stables_llama to package dataset
  # ./data-raw/stables_llama_df
  tar_target(stables_llama,
    stables_llama_lst %>% as.vector(),
    iteration = "vector"
  )
)
