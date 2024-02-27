# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_universe <- tar_plan( #----
  # universe: top 30 Binance (defi) perpetual futures 
  #   ranked by trailing, rolling 30-day, dollar volume
  #   excl stables and wrapped tokens
  #   https://robotwealth.com/quantifying-and-combining-crypto-alphas/
  # Exclude: stables and wrapped tokens
  perps_ex_stbls = {
    tmp <- stables_llama
    perps_all %>%
      # remove liquid non-volatile? stablecoins
      filter(!ticker %in%
          # not "{stables_llama}USDT"
          glue::glue("{tmp}USDT"))
  },
  universe =
    perps_ex_stbls %>%
    group_by(ticker) %>%
    # also calculate returns for later
    mutate(
      total_return_simple = funding_rate + (close - lag(close, 1)) / lag(close, 1),
      total_return_log = log(1 + total_return_simple),
      total_fwd_return_simple = dplyr::lead(funding_rate, 1) + (dplyr::lead(close, 1) - close) / close,
      total_fwd_return_log = log(1 + total_fwd_return_simple)
    ) %>%
    mutate(trail_volume = roll_mean(dollar_volume, 30)) %>%
    na.omit() %>%
    group_by(date) %>%
    mutate(
      volume_rank = row_number(-trail_volume),
      is_universe = volume_rank <= prms$universe_size,
    ),
  gg_univ_size =
    universe %>%
    group_by(date, is_universe) %>%
    summarize(count = n(), .groups = "drop") %>%
    ggplot(aes(x = date, y = count, color = is_universe)) +
    geom_line() +
    labs(
      title = "Universe size: top 30 Binance perpetual futures",
      subtitle = "Ranked by trailing, rolling 30-day, dollar volume\nExcludes stables and wrapped tokens"
    ),
)
