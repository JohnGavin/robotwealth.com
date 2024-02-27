# managing portfolio turnover via no-trade buffer rule 
# no trade until curr posn - target positions > trade_buffer
# no fancy math or optimisation techniques
# efficient workflow: research process -> backtest


# https://robotwealth.com/a-simple-effective-way-to-manage-turnover-and-not-get-killed-by-costs/
# rsims simulator
#   quasi-event based approach
#   user to correctly date-align 
      # prices, 
      # target weights and 
      # funding rates
      # lag your features relative to your prices
      # dplyr::pivot_wider. use date column as id_cols argument
      # for Binance perpetuals, do the opposite 
      #   – lag prices relative to funding rates
      # funding rate represents funding to long positions, 
      #   which may not be the default for many exchanges
      # uses efficient data structures 
      #   (matrixes instead of dataframes), 
      #   preallocating memory, and 
      #   offloading any bottlenecks to C++ 
# session  options
options(repr.plot.width = 14, repr.plot.height=7, warn = -1)

# install ---- 
# pak::pak("rstudio/pins-r")
# pacman::p_load_current_gh("Robot-Wealth/rsims", dependencies = TRUE)  # this will take some time the first time you build the package

pacman::p_load(
  rsims, ggplot2, roll, dplyr, 
    patchwork, tibbletime, purrr, tidyr,
  pins, readr, duckdb, reactable )

# perpetual futures data.
board <- board_folder("perp_daily_binance", versioned = FALSE)
(urll <- "https://github.com/Robot-Wealth/r-quant-recipes/raw/master/quantifying-combining-alphas/binance_perp_daily.csv")
board <- board_local()
name_df <- "binance"
# FIXME: downloads each time?!
system.time(
  board |> 
    pin_write(
      read_csv(urll), name_df,
      type = 'parquet', 
      description = "Binance perpetual daily via RobotWealth.com"
    )
) # time
board
# test pin
board %>% 
  pin_read(name_df) %>% 
  head()
board %>% 
  pin_read(name_df) %>% 
  dim()
show(pin_read(board, name_df))

# TODO: from pin (parquet) to arrow
# TODO: from to arrow to duckdb
# arrow db ----

# duckdb db ----
duckdb::duckdb("duckdb-database.duckdb") %>% 
  dbConnect() ->
  con
on.exit(dbDisconnect())
con %>% 
  # from pin (parquet) to duckdb
  duckdb_register(name_df, 
    pin_read(board, name_df))
binance_tbl <- tbl(con, name_df)
# pinned object is _not_ an arrow object
# duckdb::duckdb_fetch_arrow(url(urll))
binance_tbl %>% 
  glimpse()
binance_tbl %>% 
  pull(ticker) %>% table() %>% sort() ->
  curr 
perps <- binance_tbl %>% collect()
binance_tbl %>% dim()
perps %>% dim()


curr %>% names() %>% str_ends("USDT") %>% table()
# curr[curr == last(curr)] ; curr %>% { .[. == last(.)] }
library(reactable)
binance_tbl %>% 
  head(1e2L) %>% 
  as_data_frame() %>% 
  reactable()

# remove stablecoins
# list of stablecoins from defi llama
url <- "https://stablecoins.llama.fi/stablecoins?includePrices=true"
response <- httr::GET(url)
stables <- response %>%
  httr::content(as = "text", encoding = "UTF-8") %>%
  jsonlite::fromJSON(flatten = TRUE) %>%
  pluck("peggedAssets") %>%
  pull(symbol) %>% 
  sort()
# filter perps
perps %>% dim()
perps <- perps %>%
  filter(!ticker %in% glue::glue("{stables}USDT"))
perps %>% dim()

# just get the top 10 by trailing 30-day volume (remove previous arbitrary price filter)
perps <- perps %>%
  group_by(ticker) %>%
  mutate(trail_volume = roll_mean(dollar_volume, 30)) %>%
  na.omit() %>%
  group_by(date) %>%
  mutate(
    volume_rank = row_number(-trail_volume),
    is_universe = volume_rank <= 10
  ) %>%
  # also calculate demeaned returns for later
  mutate(demeaned_returns = total_returns_log - mean(total_returns_log, na.rm = TRUE))

# ggplot ----
# chart options
theme_set(theme_bw())
theme_update(text = element_text(size = 20))
perps %>%
  group_by(date, is_universe) %>%
  summarize(count = n(), .groups = "drop") %>%
  # filter(is_universe) %>% 
  ggplot(aes(x=date, y=count, color = is_universe)) +
  geom_line() +
  scale_y_log10() +
  labs(
    title = 'Universe size',
    subtitle = 'only ten assets in our universe'
  )


# calculate features
rolling_days_since_high_20 <- purrr::possibly(
  tibbletime::rollify(
    function(x) {
      idx_of_high <- which.max(x)
      days_since_high <- length(x) - idx_of_high
      days_since_high
    },
    window = 20, na_value = NA),
  otherwise = NA
)

features <- perps %>%
  group_by(ticker) %>%
  arrange(date) %>%
  mutate(
    breakout = lag(9.5 - rolling_days_since_high_20(close)),  # puts this feature on a scale -9.5 to +9.5
    momo = lag(close - lag(close, 10)/close),
    carry = lag(funding_returns_log)
  ) %>%
  ungroup() %>%
  na.omit()

head(features)

# calculate target weights
# filter on is_universe so that we calculate features only for stuff that's in the universe today
# (we'd have to do this differently if any of these calcs depended on past data, eg if we were doing z-score smoothing)
# then, join on original prices for backtesting

# tickers that were ever in the universe
universe_tickers <- features %>%
  filter(is_universe) %>%
  pull(ticker) %>%
  unique()

# print(length(universe_tickers))

# calculate weights ----
features %>%
  filter(is_universe) %>%
  group_by(date) %>%
  mutate(
    carry_decile = ntile(carry, 10),
    carry_weight = (carry_decile - 5.5)/5,  # will run -4.5 to 4.5
    momo_decile = ntile(momo, 10),
    momo_weight = -(momo_decile - 5.5)/5,  # will run -4.5 to 4.5
    breakout_weight = breakout / 5 , # approx - breakout runs between -9 and 9
    combined_weight = (0.4*carry_weight + 0.2*momo_weight + 0.4*breakout_weight),
    # scale weights so that abs values sum to 1 - no leverage condition
    scaled_weight = combined_weight/sum(abs(combined_weight))
  )  %>%
  select(date, ticker, scaled_weight) %>%
  # join back onto df of prices for all tickers that were ever in the universe
  # so that we have prices before and after a ticker comes into or out of the universe
  # for backtesting purposes
  right_join(
    features %>%
      filter(ticker %in% universe_tickers) %>%
      select(date, ticker, close, funding_returns_simple),
    by = c("date", "ticker")
  ) %>%
  # give anything with a NA weight (due to the join) a zero
  replace_na(list(scaled_weight = 0)) %>%
  arrange(date, ticker) ->
  model_df

# rsims simulator ----
#   quasi-event based approach
#   user to correctly date-align 
# prices, 
# target weights and 
# funding rates
# lag your features relative to your prices
# dplyr::pivot_wider. use date column as id_cols argument
# for Binance perpetuals, do the opposite 
#   – lag prices relative to funding rates
# funding rate represents funding to long positions, 
#   which may not be the default for many exchanges
# 
# get weights as a wide matrix
# note that date column will get converted to unix timestamp
backtest_weights <- model_df %>%
  pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, scaled_weight)) %>%  # pivot wider guarantees prices and theo_weight are date aligned
  select(date, starts_with("scaled_weight")) %>%
  data.matrix()

# NA weights should be zero
backtest_weights[is.na(backtest_weights)] <- 0
head(backtest_weights, c(5, 5))

# get prices as a wide matrix
# note that date column will get converted to unix timestamp
backtest_prices <- model_df %>%
  pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, scaled_weight)) %>%  # pivot wider guarantees prices and theo_weight are date aligned
  select(date, starts_with("close_")) %>%
  data.matrix()
head(backtest_prices, c(5, 5))

# get funding as a wide matrix
# note that date column will get converted to unix timestamp
backtest_funding <- model_df %>%
  pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, funding_returns_simple)) %>%  # pivot wider guarantees prices and funding_returns_simple are date aligned
  select(date, starts_with("funding_returns_simple_")) %>%
  data.matrix()
head(backtest_funding, c(5, 5))

# Binance modelling costs ----
# helper objects and functions  
# fees - reasonable approximation of actual binance costs (spread + market impact + commission)
fees <- tribble(
  ~tier, ~fee,
  0, 0.,  # use for cost-free simulations
  1, 0.0015,
  2, 0.001,
  3, 0.0008,
  4, 0.0007,
  5, 0.0006,
  6, 0.0004,
  7, 0.0002
)

# plot equity curve from output of simulation
plot_results <- function(backtest_results, weighting_protocol = "0.4/0.2/0.4 Carry/Momo/Breakout", trade_on = "close") {
  equity_curve <- backtest_results %>%
    group_by(Date) %>%
    summarise(Equity = sum(Value, na.rm = TRUE))
  
  fin_eq <- equity_curve %>%
    tail(1) %>%
    pull(Equity)
  
  init_eq <- equity_curve %>%
    head(1) %>%
    pull(Equity)
  
  total_return <- (fin_eq/init_eq - 1) * 100
  days <- nrow(equity_curve)
  ann_return <- total_return * 365/days
  sharpe <- equity_curve %>%
    mutate(returns = Equity/lag(Equity)- 1) %>%
    na.omit() %>%
    summarise(sharpe = sqrt(355)*mean(returns)/sd(returns)) %>%
    pull()
  
  equity_curve %>%
    ggplot(aes(x = Date, y = Equity)) +
    geom_line() +
    labs(
      title = "Cash Accounting Simulation",
      subtitle = glue::glue(
        "{weighting_protocol}, costs {commission_pct*100}% of trade value, trade buffer = {trade_buffer}, trade on {trade_on}
          {round(total_return, 1)}% total return, {round(ann_return, 1)}% annualised, Sharpe {round(sharpe, 2)}"
      )
    )
}

# calculate sharpe ratio from output of simulation
calc_sharpee <- function(backtest_results) {
  backtest_results %>%
    group_by(Date) %>%
    summarise(Equity = sum(Value, na.rm = TRUE)) %>%
    mutate(returns = Equity/lag(Equity)- 1) %>%
    na.omit() %>%
    summarise(sharpe = sqrt(355)*mean(returns)/sd(returns)) %>%
    pull()
}

# hysteresis == no-trade buffer (managing turnover)
# https://twitter.com/macrocephalopod/status/1373236950728052736
# https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2295345
# Multiperiod Portfolio Optimization with Many Risky Assets and General Transaction Costs
# heuristic for reducing trading: no-trade buffer
# (univariate) minimum amount of trading to keep edge
# rebalance if (position - deviation) > trade_buffer
# set trade_buffer to 
    # target a certain portfolio turnover
    # optimises the Sharpe ratio of a backtest incl costs
      # rsims::fixed_commission_backtest_with_funding
#
# min commission trading rebalance to target_weight
#    e.g. equities trading with Interactive Brokers! 
# fixed commission trading rebalance to target weight +- trade_buffer      
#   e.g. futures and most crypto exchanges

# cost-free version == trade_buffer set to zero ----
# == trading the signal precisely 
# == always rebalance back to target position

# simulation parameters
# invest constant $10,000 / no leverage
initial_cash <- 10000
capitalise_profits <- FALSE  # remain fully invested?
trade_buffer <- 0.
fee_tier <- 0.
commission_pct <- fees$fee[fees$tier==fee_tier]

# rsims simulation ----
results_df <- fixed_commission_backtest_with_funding(backtest_prices, backtest_weights, backtest_funding, trade_buffer, initial_cash, commission_pct, capitalise_profits) %>%
  mutate(ticker = str_remove(ticker, "close_")) %>%
  # remove coins we don't trade from results
  drop_na(Value)

plot_results(results_df)


# check that actual weights match intended (can trade fractional contracts, so should be equal)
# results_df %>%
#   left_join(model_df %>% select(ticker, date, scaled_weight), by = c("ticker", "Date" = "date")) %>%
#   group_by(Date) %>%
#   mutate(
#     actual_weight = Value/(initial_cash)
#   )  %>%
#   filter(scaled_weight != 0) %>%
#   tail(10)

# add costs but keep our trade_buffer at zero
# cost = pay 0.15% of value of each trade
# explore costs-turnover tradeoffs
# with costs, no trade buffer
fee_tier <- 1.
commission_pct <- fees$fee[fees$tier==fee_tier]

# simulation
results_df <- cash_backtest(
  backtest_prices,
  backtest_weights,
  trade_buffer,
  initial_cash,
  commission_pct,
  capitalise_profits
) %>%
  mutate(ticker = str_remove(ticker, "close_")) %>%
  # remove coins we don't trade from results
  drop_na(Value)

results_df %>%
  plot_results()

# daily turnover / trading capital (%) ----
results_df %>%
  filter(ticker != "Cash") %>%
  group_by(Date) %>%
  summarise(Turnover = 100*sum(abs(TradeValue))/initial_cash) %>%
  ggplot(aes(x = Date, y = Turnover)) +
  geom_line() +
  geom_point() +
  labs(
    title = "Turnover as % of trading capital",
    y = "Turnover, %"
  )
# turnover > 0.5*portfolio on a single day
# turnover > portfolio!

# dollar turnover by ticker for a few days (Feb)
# on a particular few days
results_df %>%
  filter(Date >= "2024-02-01", Date <= "2024-02-07") %>%
  filter(abs(TradeValue) > 0) %>%
  ggplot(aes(x = Date, y = abs(TradeValue), fill = ticker)) +
  geom_bar(stat = "identity", position = "stack", colour = "black") +
  labs(
    title = "Dollar Turnover by ticker Feb 1-7",
    y = "Turnover, $"
  )

# trade_buffer to max historical after-cost Sharpe ratio
# find appropriate trade buffer by optimising historical sharpe
sharpes <- list()
trade_buffers <- seq(0, 0.1, by = 0.01)
for(trade_buffer in trade_buffers) {
  sharpes <- c(
    sharpes,
    cash_backtest(
      backtest_prices,
      backtest_weights,
      trade_buffer,
      initial_cash,
      commission_pct,
      capitalise_profits
    ) %>%
      calc_sharpee()
  )
}
sharpes <- unlist(sharpes)
data.frame(
  trade_buffer = trade_buffers,
  sharpe = sharpes
) %>%
  ggplot(aes(x = trade_buffer, y = sharpe)) +
  geom_line() +
  geom_point(colour = "blue") +
  geom_vline(xintercept = trade_buffers[which.max(sharpes)], linetype = "dashed") +
  labs(
    x = "Trade Buffer Parameter",
    y = "Backtested Sharpe Ratio",
    title = glue::glue("Trade Buffer Parameter vs Backtested Sharpe, costs {commission_pct*100}% trade value"),
    subtitle = glue::glue("Max Sharpe {round(max(sharpes), 2)} at buffer param {trade_buffers[which.max(sharpes)]}")
  )
# 0.06 maximised our historical after-cost Sharpe
# > 0.06 hedge risk out-of-sample performance worse than in-sample 
# get back original with costs simulation results
initial_cash <- 10000
capitalise_profits <- FALSE  # remain fully invested?
trade_buffer <- 0.06
fee_tier <- 1.
commission_pct <- fees$fee[fees$tier==fee_tier]

# simulation
results_df <- cash_backtest(backtest_prices, backtest_weights, trade_buffer, initial_cash, commission_pct, capitalise_profits) %>%
  mutate(ticker = str_remove(ticker, "close_")) %>%
  # remove coins we don't trade from results
  drop_na(Value)

# simulation results
results_df %>%
  plot_results()
# turnover
results_df %>%
  filter(ticker != "Cash") %>%
  group_by(Date) %>%
  summarise(Turnover = 100*sum(abs(TradeValue))/initial_cash) %>%
  ggplot(aes(x = Date, y = Turnover)) +
  geom_line() +
  geom_point() +
  labs(
    title = "Turnover as % of trading capital",
    y = "Turnover, %"
  )
# dollar turnover by ticker for a few days
# on a particular few days
results_df %>%
  filter(Date >= "2024-02-01", Date <= "2024-02-07") %>%
  filter(abs(TradeValue) > 0) %>%
  ggplot(aes(x = Date, y = abs(TradeValue), fill = ticker)) +
  geom_bar(stat = "identity", position = "stack", colour = "black") +
  labs(
    title = "Dollar Turnover by ticker Feb 1-7",
    y = "Turnover, $"
  )
