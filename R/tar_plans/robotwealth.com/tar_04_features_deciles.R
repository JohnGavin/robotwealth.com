# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_features_deciles <- tar_plan( #----
  # model universe with momo and carry features
  # scaled into deciles
  model_df =
    features %>%
    filter(is_universe) %>%
    group_by(date) %>%
    mutate(
      # with momo and carry features
      # scaled into deciles
      carry_decile = ntile(carry, 10),
      momo_decile = ntile(momo, 10),
      # also calculate demeaned return for everything in our universe each day for later
      demeaned_return = total_return_simple - mean(total_return_simple, na.rm = TRUE),
      demeaned_fwd_return = total_fwd_return_simple - mean(total_fwd_return_simple, na.rm = TRUE)
    ) %>%
    ungroup(),
  # start simulation from date we first have n tickers in the universe
  start_date =
    features %>%
    group_by(date, is_universe) %>%
    summarize(count = n(), .groups = "drop") %>%
    filter(count >= prms$universe_size) %>%
    head(1) %>%
    pull(date),
  # carry feature has noisily linear relationship
  # with forward cross-sectional returns
  # https://robotwealth.com/quantifying-and-combining-crypto-alphas/
  gg_carry =
    # if outlying return to the tenth decile is real
    # and stable through time,
    # => explicitly account for it in your model
    model_df %>%
    group_by(carry_decile) %>%
    summarise(mean_return = mean(demeaned_fwd_return)) %>%
    ggplot(aes(x = factor(carry_decile), y = mean_return)) +
    geom_bar(stat = "identity"),
  # momentum feature random on liquid universe.
  # liquidity dependency? as factor
  # rather non(?)-predictive
  # on our more-liquid universe
  # (but not good on larger universe either).
  # => _not_ linear model momentum feature
  gg_mome =
    model_df %>%
    group_by(momo_decile) %>%
    summarise(mean_return = mean(demeaned_fwd_return)) %>%
    ggplot(aes(x = factor(momo_decile), y = mean_return)) +
    geom_bar(stat = "identity"),
  # relationship with forward returns
  gg_mome_by_yr =
    model_df %>%
    mutate(Year = year(date)) %>%
    group_by(momo_decile, Year) %>%
    summarise(mean_return = mean(demeaned_fwd_return, na.rm = TRUE), .groups = "drop") %>%
    ggplot(aes(x = factor(momo_decile), y = mean_return)) +
    geom_bar(stat = "identity") +
    facet_wrap(~Year) +
    labs(
      title = "Momentum factor plot by year"
    ),
  # momentum feature
  # noisy inverse relationship 2020, 2021, (maybe) 2022,
  # => mean reversion 2020, 2021, 2022
  # momentum in 2023 and 2024 => flipped.
  # => update model of expected returns by time
  # => capture changing relationships
  gg_breakout1 =
    model_df %>%
    group_by(breakout) %>%
    summarise(mean_return = mean(total_fwd_return_simple)) %>%
    ggplot(aes(x = factor(breakout), y = mean_return)) +
    geom_bar(stat = "identity"),
  #  forward returns
  #   random (-9.5, 3.5)
  #   linear (4.5, ...)
  #   => stepwise linear model
  gg_stepwise1 = {
    options(repr.plot.width = 10, repr.plot.height = 4)
    data.frame(breakout = seq(from = -9.5, to = 9.5, by = 1)) %>%
      mutate(expected_return = case_when(breakout <= 3.5 ~ 0, TRUE ~ breakout * 0.005)) %>%
      mutate(groups = case_when(breakout <= 3.5 ~ 0, TRUE ~ 1)) %>%
      ggplot(aes(x = breakout, y = expected_return, group = groups)) +
      geom_line() +
      geom_point() +
      labs(
        title = "Example stepwise linear model for breakout feature"
      )
  },
  # model this feature’s expected returns as zero from -9.5 through 3.5 and the mean of the expected returns to the remaining deciles above 3.5
) # tar_feature
