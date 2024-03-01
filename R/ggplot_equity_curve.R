#' @title Equity curve from output of backtest 
#' @description
#' Equity curve is output 
#' as a ggplot object to be plotted.
#' @param backtest_results Backtest results. A tibble
#' @param commission_pct Percent commission per trade. 
#' @param trade_on Column name in \code{backtest_results}.
#' Real length-one vector.
#' @return ggplot object
#' @author John Gavin
#' @export
ggplot_equity_curve <- function(backtest_results,
  commission_pct,
  trade_on = "close") {
  margin <- backtest_results %>%
    group_by(Date) %>%
    summarise(Margin = sum(Margin, na.rm = TRUE))
  
  cash_balance <- backtest_results %>%
    filter(ticker == "Cash") %>%
    select(Date, Value) %>%
    rename("Cash" = Value)
  
  equity <- cash_balance %>%
    left_join(margin, by = "Date") %>%
    mutate(Equity = Cash + Margin)
  
  fin_eq  <- equity %>% tail(1) %>% pull(Equity)
  init_eq <- equity %>% head(1) %>% pull(Equity)
  total_return <- (fin_eq / init_eq - 1) * 100
  ann_return <- total_return * 365 / nrow(equity)
  sharpe <- equity %>%
    mutate(returns = Equity / lag(Equity) - 1) %>%
    na.omit() %>%
    summarise(sharpe = sqrt(365) * mean(returns) / sd(returns)) %>%
    pull()
  
  equity %>%
    ggplot(aes(x = Date, y = Equity)) +
    geom_line() +
    labs(
      title = "Crypto Stat Arb Simulation",
      subtitle = glue::glue(
        "Costs {commission_pct*100}% of trade value, ",
        "trade buffer = {prms$trade_buffer}, ",
        "trade on {trade_on}
          {round(total_return, 1)}% total return, {round(ann_return, 1)}% annualised, Sharpe {round(sharpe, 2)}"
      )
    )
}
