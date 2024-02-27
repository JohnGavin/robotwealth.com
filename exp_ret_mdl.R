library(targets)
options(repr.plot.width = 14, repr.plot.height = 7, warn = -1)
pacman::p_load(sandwich, lmtest, tidyfit, tibbletime, roll, patchwork, 
    rsims, tarchetypes, fs, glue, here, lubridate, stringr, dplyr, 
    purrr, readr, tidyr, tibble, ggplot2)
pacman::p_load_current_gh("Robot-Wealth/rsims", dependencies = TRUE)
theme_set(theme_bw())
theme_update(text = element_text(size = 20))
get_prms <- function() {
    prms <- list(universe_size = 30, is_days = 90, breakout_cutoff = 5.5, 
        batches = 5, reps = 20)
    prms$hyper <- tibble(num_sims = prms$num_sims)
    prms <- c(prms, list(step_size = prms$universe_size * 10, 
        max_ts_pos = 0.5/prms$universe_size))
    prms
}
prms <- get_prms()
prms_sim <- list(initial_cash = 10000, fee_tier = 0, capitalise_profits = FALSE, 
    trade_buffer = 0, commission_pct = c(yes_csts_no_trd_bffr = 0.0015, 
        no_csts_no_trd_bffr = 0), margin = 0.05)
source_dir_only <- function(path_rel = "R") {
    fs::path_abs(path_rel) %>% fs::dir_ls(regexp = "\\.R$") %>% 
        str_subset("^zzz.[Rr]$|_targets.[Rr]$", negate = TRUE) %>% 
        walk(source)
}
source_dir_only("R")
tar_prms <- tar_plan()
source_dir_only("R/tar_plans/robotwealth.com")
c(tar_prms, tar_data, tar_universe, tar_features, tar_features_deciles, 
    tar_tidymodels, tar_feat_evol, tar_rsims)
