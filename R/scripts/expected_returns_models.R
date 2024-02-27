# at each t, given expected returns at t, ----
# best portfolio given constraints?
# optimisation problem,

# https://robotwealth.com/quantifying-and-combining-crypto-alphas/ ---
# packages ----
# **tidymodels framework**
# **rsims for simulation**
#   rsims::fixed_commission_backtest_with_funding
#   tidyfit::regress
#   lmtest::?
#   sandwich::?
#  does relative carry/momentum predict
#   out/under-performance?
# use breakout feature as time-series overlay
#   to predict forward returns for each asset
#   in the time-series, _not_ in the cross-section.
# demonstrate how to combine
#   cross-sectional and
#   time-series features
#   into a single long-short strategy


# expected return models ----
# https://robotwealth.com/how-to-model-features-as-expected-returns/
#   features ~ expected returns
#   carry, momentum, and breakout features
#     https://robotwealth.com/quantifying-and-combining-crypto-alphas/
# objective of predicting and capitalising on future returns
# make optimisation and implementation more intuitive
# direct comparison between features
# framework to add new signals or reassessing existing ones
# common risk models
# e.g. covariance estimates
# expected return & risk models
# direct comparison with trading costs
# optimisation techniques to trade-off
# return, risk, and turnover given constraints

### benign but real **biases** ----
#   => performance deteriorates out of sample
# 1) a degree of **future peeking** cos a model type for each feature.
#   linear model for carry and momentum
#     cos saw (future peek) (noisily) linear relationship
#     between these features and expected returns.
#   i.e. we estimate model coef of on a rolling basis
#     that prevents future peeking,
#     _but_ the model type itself was chosen
#     based on knowledge of the entire dataset.
# 2) two new meta-parameters:
#   length of model estimation window,
#   frequency used to refit the model
#   try many values => some data snooping
# assumptions ----
# features modeled as expected returns
# => consistent framework for trading decisions
# incl structuring decisions as optimisation problem
#
# assumes: good understanding of features
#   How features distributed
#   How features relationship with expected returns
#     changes across their range(?)
# sensible basis for modeling changes or just noise?
# How predictive power changes by time


pacman::p_load( # dev pkgs ----
  targets, devtools,
  # avoid all tidyverse pkgs
  stringr, dplyr, purrr, readr, tidyr, tibble, ggplot2 #  tidyverse, lubridate forcats
) #  tictoc prettyunits
# targets config ----
pr_title <- "exp_ret_mdl"
pr_yaml <- paste0(pr_title, ".yaml")
pr_script <- paste0(pr_title, ".R")
pr_store <- paste0(pr_title, "_store")
Sys.setenv(TAR_PROJECT = pr_title)
Sys.setenv(TAR_CONFIG = pr_yaml)
Sys.getenv("TAR_PROJECT", pr_title) %>%
  {. == pr_title} %>%
  stopifnot("expect TAR_PROJECT == pr_title" = .)
Sys.getenv("TAR_CONFIG", pr_yaml) %>%
  {. == pr_yaml} %>%
  stopifnot("expect TAR_CONFIG == pr_yaml" = .)
tar_config_set(store = pr_store, config = pr_yaml, project = pr_title)
tar_config_set(script = pr_script, config = pr_yaml, project = pr_title)
tar_config_get("store",
  config = pr_yaml, project = pr_title
) %>%
  {. == pr_store} %>%
  stopifnot("expect store == pr_store" = .)
tar_config_get("script",
  config = pr_yaml, project = pr_title
) %>%
  {. == pr_script} %>%
  stopifnot("expect store == pr_store" = .)
tar_config_projects()
readLines(pr_yaml)

# tar_script ----
targets::tar_script({
  # all libs needed inside each tar_plan
  # FIXME: why does pacman:: work inside targets?
  # session options ----
  options(repr.plot.width = 14, repr.plot.height = 7, warn = -1)
  pacman::p_load( # _project_ packages ----
    # sandwich: robust standard errors
    # & avoid using mdl coefs on their own fitted data
    sandwich, lmtest, tidyfit,
    tibbletime, roll, patchwork, rsims,
    tarchetypes, fs,
    glue, here,
    # from tidyverse,
    lubridate, stringr, dplyr, purrr, readr, tidyr, tibble, ggplot2 #  tidyverse, lubridate forcats
  )
  pacman::p_load_current_gh("Robot-Wealth/rsims",
    dependencies = TRUE)
  # chart options
  theme_set(theme_bw())
  theme_update(text = element_text(size = 20))

  # hyper parameters ----
  # TODO: pass params to tar_script

  # script functions ----
  get_prms <- function() {
    prms <- list(
      universe_size = 30,
      is_days = 90,
      breakout_cutoff = 5.5 # below this level, we set our expected return to zero
      , batches = 5,
      reps = 20
    )
    prms$hyper <- tibble(num_sims = prms$num_sims)
    prms <- c(prms, list(
      step_size = prms$universe_size * 10,
      max_ts_pos = 0.5 / prms$universe_size
    ))
    prms
  }
  # TODO: add prms to tar_data? screws up graph?
  prms <- get_prms()
  # tar_prms <- tar_plan( # FIXME: fails? ----
  #   #   prms = prms,
  #   # simulation parameters
  # ) # tar_prms
  prms_sim <- list( #----
    initial_cash = 10000,
    fee_tier = 0,
    capitalise_profits = FALSE, # remain fully invested?
    # cost-free, no trade buffer
    trade_buffer = 0.,
    commission_pct = c(
      # with costs, no trade buffer
      "yes_csts_no_trd_bffr" = 0.0015,
      "no_csts_no_trd_bffr" = 0.
    ),
    margin = 0.05
  )

  # TODO: ? move relevant .R/functions to ./R/expected_returns_models/?
  source_dir_only <- function(path_rel = "R"){
    fs::path_abs(path_rel) %>%
      fs::dir_ls(regexp = "\\.R$") %>%
      str_subset("^zzz.[Rr]$|_targets.[Rr]$", negate = TRUE) %>%
      walk(source) # %>% invisible()
    # was
    # '^[^_].+\\.R$' %>% # excl ./R/_targets.R
    #   list.files(path = "R", pattern = .) %>%
    #   walk(source)
  }
  source_dir_only("R")

  # tar_plan ----
  tar_prms <- tar_plan(#----
    # prms = {
    #   get_prms <- function() {
    #     prms <- list(
    #       universe_size = 30,
    #       is_days = 90,
    #       breakout_cutoff = 5.5 # below this level, we set our expected return to zero
    #       , batches = 5,
    #       reps = 20
    #     )
    #     prms$hyper <- tibble(num_sims = prms$num_sims)
    #     prms <- c(prms, list(
    #       step_size = prms$universe_size * 10,
    #       max_ts_pos = 0.5 / prms$universe_size
    #     ))
    #     prms
    #   } # get_prms
    #   get_prms()
    # }
  ) # tar_prms

  # incl .R functions from ./R/tar_plans/robotwealth.com
  #   not recursively tar_source(... cos of 'old' folder
  source_dir_only("R/tar_plans/robotwealth.com")

  c(
    tar_prms,
    tar_data, tar_universe,
    tar_features, tar_features_deciles,
    tar_tidymodels, tar_feat_evol, tar_rsims
  )},
  ask = FALSE,
  script = pr_script
) # script ----
tar_manifest(callr_function = NULL) # %>% View()
tar_validate(callr_function = NULL)
tar_outdated(callr_function = NULL) %>% str()
tar_progress() %>% pull(progress) %>% table() %>% sort()
# targets::tar_invalidate(a_data_from_n_sim)
tar_visnetwork(
  callr_function = NULL,
  names =
    !ends_with('_[0-9a-z]{8}') & # dynamic targets
    !starts_with('gg_') & # ggplot2
    !starts_with('df_') & # data.frame / tibble
    !ends_with('_head'),  # snapshots of data.frame
  shortcut = FALSE,
  zoom_speed = .25,   physics = TRUE,
  targets_only = TRUE, script = pr_script)
tar_make(
  callr_function = NULL, # inside Nix --pure
  script = pr_script, store = pr_store,
  reporter = c("summary", "verbose")[2]
)
# tar_process(tar_process()$value[1])
# tar_invalidate / tar_destroy("local")
# tar_meta(targets_only = TRUE) %>% glimpse()
# copy store objects to globalenv() ----
stopifnot(identical(tar_objects(), tar_objects(store = pr_store)))
# only load non-branch objects
# FAILS for gg_eq_curve_2 cos 1 digit or letter ok
regex_target_branch <-
  # _ + 1 digit or letter ok
  "_[a-z\\d]{8}$" # almost works / gg_stepwise fails
# "_[(a-z)(\\d)]{8}$"
# "^.+_[0-9a-z]{[0-9a-z]{8}.+$"
# "^.+_[0-9a-z][0-9a-z].+$"
#"^.*_(?=.*[0-9])(?=.*[a-z]).+$" # fails gg_eq_curve_1
# "^.*_[0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z]$" # almost ok
# "^.*_[0-9a-z](?=.*[0-9])(?=.*[a-z]).+$" # fails gg_eq_curve_1
#"^.*_[0-9a-z](?=.*\\d)(?=.*[a-z]).+$" # fails gg_eq_curve_1
# "^.*_[0-9a-z](?=.*[0-9a-z]).+$" # fails
#tar_objects(ends_with("regex_target_branch"))
tar_objs <- tar_objects()
(not_brnch <- tar_objs %>%
    str_subset(regex_target_branch,
      negate = T
    ) # %>% str_subset("^gg_", negate = TRUE)
)
length(tar_objs) ; length(not_brnch)
tar_load(not_brnch %>% all_of())
mget(not_brnch) %>% str(max.level = 2, list.len = 6, give.attr = FALSE)
# tar_load(tar_objects(starts_with("gg_"))) # see also any_of()
# tar_load_everything() %>% str()
(tar_load_globals())
.packages()
# print(targets::tar_read(group, branches = 2))
