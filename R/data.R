#' Stablecoins from llama
#'
#' @format ## `stablecoins`
#' A character vector of stablecoims names.
#' @source <https://stablecoins.llama.fi/stablecoins?includePrices=true>
"stablecoins"

#' OHLC and volume
#'
#' @format ## `perpetuals`
#' A tibble of non-stablecoins price and volume.
#' A tibble: 83,408 × 11:
#' \describe{
#'   \item{ticker}{Symbol name for pairs of coins}
#'   \item{date}{end of period (daily) date}
#'   \item{open, high, low, close}{price related columns}
#'   \item{dollar_volume, num_trades, taker_buy_volume, taker_buy_quote_volumne}{volume related columns}
#'   \item{funding_rate}{flow related columns}
#' }
#' The data is date-restricted - from
#'  2023-08-31 to 2024-02-13,
#'  to meet devtools::check() folder size >1Mb warnings.
#' A larger tibble is available via
#' `targets::tar_read(perps_all)` -
#' see ./data-raw/DATASET.R.
#' This covers the period 2019-09-11 to 2024-02-13.
#'
#' @source <https://github.com/Robot-Wealth/r-quant-recipes/raw/master/quantifying-combining-alphas/binance_perp_daily.csv>
"perps_2308_2402"
