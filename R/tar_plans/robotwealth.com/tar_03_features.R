# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_features <- tar_plan( #----
  # features
  # How are features distributed?
  # Do features distributions imply the need for scaling?
  rolling_days_since_high_20 =
    purrr::possibly(
      tibbletime::rollify(
        function(x) {
          idx_of_high <- which.max(x)
          days_since_high <- length(x) - idx_of_high
          days_since_high
        },
        window = 20, na_value = NA
      ),
      otherwise = NA
    ),
  features =
    universe %>%
    group_by(ticker) %>%
    arrange(date) %>%
    mutate(
      # Short-term (10-day) cross-sectional momentum (buckted into deciles by date)
      # Short-term (1-day) cross-sectional carry (also bucketed into deciles by date)
      # A breakout feature defined as 
      #  number of days since the 20-day high 
      #  which we use as a time-series return predictor.
      # Breakout – closeness to recent 20 day highs: 
      #  (9.5 = new highs today / -9.5 = new highs 20 days ago)
      #  carry/momentum features as 
      #   cross-sectional predictors of returns
      breakout = 9.5 - rolling_days_since_high_20(close), # puts this feature on a scale -9.5 to +9.5
      # Momentum –  price change over last 10 days
      momo = close - lag(close, 10) / close,
      # Carry – funding over the last 24 hours
      carry = funding_rate
    ) %>%
    ungroup() %>%
    na.omit()
) # tar_features

# create a model df on our universe
