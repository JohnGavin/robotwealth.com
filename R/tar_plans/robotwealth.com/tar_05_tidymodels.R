# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_tidymodels <- tar_plan( #----
  # tidymodels
  # build model on rolling basis
  # only incl info upto time t
  # => rolling estimates of model coefficients
  # least squares => lm
  # robust standard errors => lm(..., vcov = ...)
  #   => autocorrelation and heteroscedasicity
  #   via sandwich package
  # 90-day window, refit every 10 days
  #   not lot of data => reactive to recent past
  # use a 90-day window and refit every 10 days
  
  # rolling model for cross-sectional features
  roll_xs_coeffs_df =
    model_df %>%
    filter(date >= start_date) %>%
    tidyfit::regress(
      demeaned_fwd_return ~ carry_decile + momo_decile,
      m("lm", vcov. = "HAC"),
      .cv = "sliding_index",
      .cv_args = list(
        lookback = lubridate::days(prms$is_days),
        step = prms$step_size, index = "date"
      ),
      .force_cv = TRUE,
      .return_slices = TRUE
    ),
  
  # rolling model for time series features
  roll_ts_coeffs_df =
    model_df %>%
    filter(date >= start_date) %>%
    # setting regression weights to zero when breakout < breakout_cutoff will give these data points zero weight in estimating coefficients
    mutate(regression_weights = case_when(breakout < prms$breakout_cutoff ~ 0, TRUE ~ 1)) %>%
    tidyfit::regress(
      total_fwd_return_simple ~ breakout,
      m("lm", vcov. = "HAC"),
      .weights = "regression_weights",
      .cv = "sliding_index",
      .cv_args = list(
        lookback = days(prms$is_days),
        step = prms$step_size, index = "date"
      ),
      .force_cv = TRUE,
      .return_slices = TRUE
    ),
  # nested dataframe: model objects + metadata
  df_roll_xs_coeffs = roll_xs_coeffs_df %>% head(),
  df_roll_ts_coeffs = roll_ts_coeffs_df %>%
    select(-settings) %>% head(),
  # slice_id = date the model goes out of sample
  # align our model coeffs
  # i.e. do _not_ use coeffs on data they were fitted on
  # needs: sandwich (where?), lmtest (where?)
  xs_coefs = roll_xs_coeffs_df %>% coef(),
  xs_coefs_df =
    xs_coefs %>%
    ungroup() %>%
    select(term, estimate, slice_id) %>%
    pivot_wider(id_cols = slice_id, names_from = term, values_from = estimate) %>%
    mutate(slice_id = as_date(slice_id)) %>%
    # lag slice id to make it out of sample (oos)
    # slice_id_oos is the date we start using the parameters
    mutate(slice_id_oos = lead(slice_id)) %>%
    rename("xs_intercept" = `(Intercept)`),
  ts_coefs = roll_ts_coeffs_df %>% coef(),
  ts_coefs_df =
    ts_coefs %>%
    ungroup() %>%
    select(term, estimate, slice_id) %>%
    pivot_wider(id_cols = slice_id, names_from = term, values_from = estimate) %>%
    mutate(slice_id = as_date(slice_id)) %>%
    # need to lag slice id to make it oos
    # slice_id_oos is the date we start using the parameters
    mutate(slice_id_oos = lead(slice_id)) %>%
    rename("ts_intercept" = `(Intercept)`),
  df_xs_coefs = xs_coefs_df %>% head(),
  df_ts_coefs = ts_coefs_df %>% head(),
  # cross-sectional features’ regression coefficients through time
  # cross-sectional estimates
  gg_xs_coefs_df =
    xs_coefs_df %>%
    select(-slice_id) %>%
    pivot_longer(cols = -slice_id_oos, names_to = "coefficient", values_to = "estimate") %>%
    ggplot(aes(x = slice_id_oos, y = estimate)) +
    geom_line() +
    facet_wrap(~coefficient, ncol = 1, scales = "free_y") +
    labs(
      title = "Cross-sectional features model parameters",
      subtitle = "Regression coefficients through time",
      caption = "coefficients for carry and momentum features change over time to reflect the changing relationship with forward returns",
      x = "Date",
      y = "Estimate"
    ),
  gg_ts_coefs_df =
    # time-series estimates
    ts_coefs_df %>%
    select(-slice_id) %>%
    pivot_longer(cols = -slice_id_oos, names_to = "coefficient", values_to = "estimate") %>%
    ggplot(aes(x = slice_id_oos, y = estimate)) +
    geom_line() +
    facet_wrap(~coefficient, ncol = 1, scales = "free_y") +
    labs(
      title = "Time-series features model parameters",
      x = "Date",
      y = "Estimate"
    ),
) # tar_tidymodels
