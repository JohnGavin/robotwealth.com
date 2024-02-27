#' @title Sharpe ratio from output of simulation
#' @param backtest_results tibble of backtest results from simulation
#' @param days_pa number of days in calendar year. 
#' A lenth-one numeric vector.
#' @return Sharpe from backtest simulation. 
#' A lenth-one numeric vector.
#' @author John Gavin
#' @export
calc_sharpe <- function(backtest_results,
  days_pa = 365 # _not_ 355(?) in https://robotwealth.com/how-to-model-features-as-expected-returns/
  ) {
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
  
  equity %>%
    mutate(returns = Equity / lag(Equity) - 1) %>%
    na.omit() %>%
    summarise(sharpe = sqrt(days_pa) * mean(returns) / sd(returns)) %>%
    pull()
}
