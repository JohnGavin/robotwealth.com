## code to prepare `DATASET` dataset goes here

# targets setup
scr <- as.character(quote(exp_ret_mdl.R))
str <- as.character(quote(exp_ret_mdl_store))
targets::tar_config_set(script = scr, store = str)

# stablecoins
stablecoins <- targets::tar_read(stables_llama)
usethis::use_data(stablecoins, overwrite = TRUE)
# https://r-pkgs.org/data.html#sec-documenting-data
# ./R/data.R

# perps_all
perps <- targets::tar_read(perps_all)
perps %>% glimpse()
perps %>% pull(date) %>% range()
perps %>%
  filter(date > "2022-12-31") ->
  perps_2301_2402
usethis::use_data(perps_2301_2402, overwrite = TRUE)
