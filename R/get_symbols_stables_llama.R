#' @title defi llama stablecoins 
#' @param url url to download \url{llama.fi} (default) stable coin symbols.
#'    A length-one charector vector.
#'    If null (default) 
#' @return character vector
#' @author John Gavin
#' @export
#' @examples 
#' get_symbols_stables_llama()
get_symbols_stables_llama <- function(
  url = "https://stablecoins.llama.fi/stablecoins?includePrices=true"){
  url %>% 
    httr::GET() %>% 
    httr::content(as = "text", encoding = "UTF-8") %>%
    jsonlite::fromJSON(flatten = TRUE) %>%
    pluck("peggedAssets") %>%
    pull(symbol)
}
