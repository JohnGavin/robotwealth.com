# sourced in ~/Documents_GitHub/duckdb_arrow_sql/R/robotwealth.com/expected_returns_models.R

tar_feat_evol <- tar_plan( #----
  # feature evolution matches understanding?
  # mome coef flipped sign from mid-2022
  # returns to no-cost strategy given expected return ests
  # excl costs and turnover
  # returns v pred of expected returns by time
  # breakout feature of linear model
  #   set E(R) = .002 if E(R) > 5 else 0
  # target positions prop to cross-sectional return estimates
  #   then breakout feature tilts portfolio net long
  #     constrain maximum delta breakout adds to position
  # join and fill using slice_id to designate when the model goes oos
  exp_return_df =
    model_df %>%
    left_join(
      xs_coefs_df %>% left_join(ts_coefs_df, by = c("slice_id", "slice_id_oos")),
      by = join_by(closest(date > slice_id_oos)), suffix = c("_factor", "_coef")
    ) %>%
    na.omit() %>%
    # forecast cross-sectional expected return as
    mutate(expected_xs_return = carry_decile_factor * carry_decile_coef + momo_decile_factor * momo_decile_coef + xs_intercept) %>%
    # mean expected xs return each day is zero
    # let total expected return be xs return + ts return - allows time series expected return to tilt weights
    mutate(expected_ts_return = case_when(breakout_factor >= 5.5 ~ 0.002, TRUE ~ 0)) %>%
    ungroup(),
  
  # long-short the xs expected return
  # layer ts expected return on top
  # position by expected return
  
  # 1 in the numerator lets it get max 100% long due to breakout
  
  strategy_df =
    exp_return_df %>%
    filter(date >= start_date) %>%
    group_by(date) %>%
    mutate(xs_position = expected_xs_return - mean(expected_xs_return, na.rm = TRUE)) %>%
    # scale positions so that leverage is 1
    group_by(date) %>%
    mutate(xs_position = if_else(xs_position == 0, 0, xs_position / sum(abs(xs_position)))) %>%
    # layer ts expected return prediction
    ungroup() %>%
    mutate(ts_position = sign(expected_ts_return)) %>%
    # constrain maximum delta added by time series prediction
    mutate(
      ts_position =
        if_else(ts_position >= 0, pmin(ts_position, prms$max_ts_pos), pmax(ts_position, -prms$max_ts_pos))
    ) %>%
    mutate(position = xs_position + ts_position) %>%
    # strategy return
    mutate(strat_return = position * total_fwd_return_simple) %>%
    # scale back to leverage 1
    group_by(date) %>%
    mutate(position = if_else(position == 0, 0, position / sum(abs(position)))),
  gg_returns_plot =
    strategy_df %>%
    group_by(date) %>%
    summarise(total_ret = sum(strat_return)) %>%
    ggplot(aes(x = date, y = cumsum(log(1 + total_ret)))) +
    geom_line() +
    labs(
      title = "Cumulative strategy return",
      y = "Cumulative return"
    ),
  gg_weights_plot =
    strategy_df %>%
    summarise(net_pos = sum(position)) %>%
    ggplot(aes(x = date, y = net_pos)) +
    geom_line() +
    labs(
      x = "Date",
      y = "Net Weight"
    ),
  
  # FIXME: patchwork not working
  gg_rets_wghts =
    gg_returns_plot + gg_weights_plot +
    plot_layout(heights = c(2, 1)),
) # tar_feat_evol
tar_rsims <- tar_plan(
  # rsims: simulation given target weights and costs 
  # wrangle dfs into matrixes of target
  # positions, prices, and funding rates
  # get weights as a wide matrix
  # note that date column will get converted to unix timestamp
  backtest_weights = {
    ans <-
      strategy_df %>%
      pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, position)) %>% # pivot wider guarantees prices and theo_weight are date aligned
      select(date, starts_with("position_")) %>%
      data.matrix()
    # NA weights should be zero
    ans[is.na(ans)] <- 0
    ans
  },
  backtest_weights_head = head(backtest_weights, c(5, 5)),
  
  # get prices as a wide matrix
  # note that date column will get converted to unix timestamp
  backtest_prices = {
    strategy_df %>%
      pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, position)) %>% # pivot wider guarantees prices and theo_weight are date aligned
      select(date, starts_with("close_")) %>%
      data.matrix()
  },
  backtest_prices_head = head(backtest_prices, c(5, 5)),
  
  # get funding as a wide matrix
  # note that date column will get converted to unix timestamp
  backtest_funding = {
    strategy_df %>%
      pivot_wider(id_cols = date, names_from = ticker, values_from = c(close, funding_rate)) %>% # pivot wider guarantees prices and funding_returns_simple are date aligned
      select(date, starts_with("funding_rate_")) %>%
      data.matrix()
  },
  backtest_funding_head = head(backtest_funding, c(5, 5)),
  
  # cost-free sim trades frictionlessly into target positions
  # cost-free, no trade buffer
  
  # simulation
  results_df_1 = {
    backtest_prices
    rsims::fixed_commission_backtest_with_funding(
      prices = backtest_prices,
      target_weights = backtest_weights,
      funding_rates = backtest_funding,
      trade_buffer = prms_sim$trade_buffer,
      initial_cash = prms_sim$initial_cash,
      margin = prms_sim$margin,
      commission_pct = prms_sim$commission_pct["no_csts_no_trd_bffr"],
      capitalise_profits = prms_sim$capitalise_profits
    ) %>%
      mutate(ticker = str_remove(ticker, "close_")) %>%
      # remove coins we don't trade from results
      drop_na(Value)
  },
  
  # make a nice plot with some summary statistics
  # plot equity curve from output of simulation
  gg_eq_curve_1 =
    ggplot_equity_curve(results_df_1,
      commission_pct = prms_sim$commission_pct["no_csts_no_trd_bffr"]
    ),
  
  # explore costs-turnover tradeoffs
  # TODO: add to prms_sim as a named vector?
  # with costs, no trade buffer
  # commission_pct_2 = 0.0015,
  
  # # simulation
  results_df_2 = {
    # backtest_prices
    rsims::fixed_commission_backtest_with_funding(
      prices = backtest_prices,
      target_weights = backtest_weights,
      funding_rates = backtest_funding,
      trade_buffer = prms_sim$trade_buffer,
      initial_cash = prms_sim$initial_cash,
      margin = prms_sim$margin,
      commission_pct = 
        prms_sim$commission_pct["yes_csts_no_trd_bffr"],
      capitalise_profits = prms_sim$capitalise_profits
    ) %>%
      mutate(ticker = str_remove(ticker, "close_")) %>%
      # remove coins we don't trade from results
      drop_na(Value)
  },
  gg_eq_curve_2 = ggplot_equity_curve(results_df_2,
    commission_pct =
      prms_sim$commission_pct["yes_csts_no_trd_bffr"]
  ),
  
  # no-trade buffer heuristic 
  # from the last article 
  # minimum amount of trading to harness the edge
  # find appropriate trade buffer by optimising historical sharpe
  sharpes_trade_buffers = {
    sharpes <- list()
    trade_buffers <- seq(0, 0.1, by = 0.01)
    for(trade_buffer in trade_buffers) {
      sharpes <- c(
        sharpes,
        fixed_commission_backtest_with_funding(
          prices = backtest_prices,
          target_weights = backtest_weights,
          funding_rates = backtest_funding,
          trade_buffer = trade_buffer, # prms_sim$trade_buffer,
          initial_cash = prms_sim$initial_cash,
          margin = prms_sim$margin,
          commission_pct = 
            prms_sim$commission_pct["no_csts_no_trd_bffr"],
          capitalise_profits = prms_sim$capitalise_profits
        ) %>%
          calc_sharpe()
      )
    } # returns sharpes?
    list(sharpes = unlist(sharpes), trade_buffers = trade_buffers)
  },
  gg_trd_buf_param = {
    sharpes <- sharpes_trade_buffers$sharpes
    trade_buffers <- sharpes_trade_buffers$trade_buffers
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
        # no or yes_csts_no_trd_bffr?
        title = glue::glue("Buffer prms v Sharpe, costs {prms$sims$commission_pct['no_csts_no_trd_bffr']*100}% trade value"),
        subtitle = glue::glue("Max Sharpe {round(max(sharpes), 2)} at buffer {trade_buffers[which.max(sharpes)]}")
      )
  },
  orig_res_with_costs = {
    # get back to original _with_ costs simulation results
    trade_buffer <- 0.03
    # simulation
    fixed_commission_backtest_with_funding(
      prices = backtest_prices,
      target_weights = backtest_weights,
      funding_rates = backtest_funding,
      trade_buffer = trade_buffer,
      initial_cash = prms_sim$initial_cash,
      margin = prms_sim$margin,
      commission_pct = 
        prms_sim$commission_pct["yes_csts_no_trd_bffr"],
      capitalise_profits = prms_sim$capitalise_profits
    ) %>%
      mutate(ticker = str_remove(ticker, "close_")) %>%
      # remove coins we don't trade from results
      drop_na(Value)
  },
  gg_orig_yes_cost = {
    orig_res_with_costs %>% 
      # Performance is a little higher
      # excludes first in-sample model estimation period
      ggplot_equity_curve(commission_pct = prms_sim$commission_pct["yes_csts_no_trd_bffr"])
  },
  gg_turnover = {
    # Turnover is higher cos lower trade buffer parameter
    orig_res_with_costs %>%
      filter(ticker != "Cash") %>%
      group_by(Date) %>%
      summarise(Turnover = 100*sum(abs(TradeValue))/prms_sim$initial_cash) %>%
      ggplot(aes(x = Date, y = Turnover)) +
      geom_line() +
      geom_point() +
      labs(
        title = "Turnover as % of trading capital",
        y = "Turnover, %"
      )
  }, # gg_turnover
) # tar_rsims
# good result for simple model
# benefit: features all modelled on same scale
#   makes features directly comparable
# new signals => same modeling process

