# https://robotwealth.com/building-intuition-for-trading-with-convex-optimisation-with-cvxr/

# signals that are predictive of next-day returns
#   strength and decay characteristics
#   turnover impact from rate of signals change
#   change over time of signals
#   modelled signals as expected returns
# maximise your expected returns subject to
#   limits
#   positions concentrated
#   net long or short
#   leverage
#
# no-trade buffer - hysteresis
# only rebalance positions
#  if position > percentage of your target
#  https://robotwealth.com/a-simple-effective-way-to-manage-turnover-and-not-get-killed-by-costs/
#
#  real-world constraints directly
# incl risk models
# e.g. covariance estimates, Value-at-Risk, etc
# flexible and scalable:
#   add new signals or
#   risk estimates without re-fitting anything?

pacman::p_load( # dev pkgs ----
  targets, devtools,
  # avoid all tidyverse pkgs
  stringr, dplyr, purrr, readr, tidyr, tibble, ggplot2 #  tidyverse, lubridate forcats
) #  tictoc prettyunits
# targets config ----
pr_title <- "conv_opt_cvxr"
pr_yaml <- paste0(pr_title, ".yaml")
pr_script <- paste0(pr_title, ".R")
pr_store <- paste0(pr_title, "_store")
# TODO: install local (strategies) project package?
load_all()
tar_config_set_project(
  pr_title = pr_title,
  pr_yaml = pr_yaml,
  pr_script = pr_script,
  pr_store = pr_store
)
tar_config_projects() # new (pr_title) project in .yaml config file
readLines(pr_yaml)
rm(pr_yaml, pr_title)

# tar_script ----
targets::tar_script(
  {
    # all libs needed inside each tar_plan
    # FIXME: why does pacman:: work inside targets?
    # session options ----
    options(repr.plot.width = 14, repr.plot.height = 7, warn = -1)
    pacman::p_load( # _project_ packages ----
      # user objective and set of constraints
      # by combining CVXR objects representing
      # constants, variables, and parameters
      CVXR,
      tarchetypes, fs,
      glue, here,
      # from tidyverse,
      lubridate, stringr, dplyr, purrr, readr, tidyr, tibble, ggplot2, #  tidyverse, lubridate forcats
      tibbletime, roll, patchwork, rsims
    )
    pacman::p_load_current_gh("Robot-Wealth/rsims",
      dependencies = TRUE)
    # ggplot chart options ----
    options(repr.plot.width = 14, repr.plot.height = 7, warn = -1)
    theme_set(theme_bw())
    theme_update(text = element_text(size = 20))

    # script parameters ----

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
    # script functions ----

    # TODO: ? move relevant .R/functions to ./R/expected_returns_models/?
    source_dir_only <- function(path_rel = "R") {
      fs::path_abs(path_rel) %>%
        fs::dir_ls(regexp = "\\.R$") %>%
        str_subset("^zzz\\.[Rr]$|_targets\\.[Rr]$", negate = TRUE) %>%
        walk(source) # %>% invisible()
      # was
      # "^[^_].+\\.R$" %>% # excl ./R/_targets.R
      #   list.files(path = "R", pattern = .) %>%
      #   walk(source)
    }
    source_dir_only("R")

    # tar_plan ----
    # incl .R functions from ./R/tar_plans/robotwealth.com
    #   not recursively tar_source(... cos of "old" folder
    source_dir_only("R/tar_plans/robotwealth.com")

    tar_prms <- tar_plan(#----
      prms = {
        ans <- list(
          universe_size = 30,
          is_days = 90,
          breakout_cutoff = 5.5 # below this level, we set our expected return to zero
          , batches = 5,
          reps = 20
        )
        # prms$hyper <- tibble(num_sims = prms$num_sims)
        ans <- c(ans, list(
          step_size = ans$universe_size * 10,
          max_ts_pos = 0.5 / ans$universe_size
        ))
        ans},
    ) # tar_prms
    tar_not_prms <- tar_plan(#----
      x = prms$max_ts_pos
    ) # tar_not_prms

    c(
      tar_prms,
      tar_not_prms
    )
  },
  ask = FALSE,
  script = pr_script
) # script ----
tar_manifest() # %>% View()
tar_validate()
tar_outdated() %>% str()
tar_progress() %>% pull(progress) %>% table() %>% sort()
# targets::tar_invalidate(a_data_from_n_sim)
tar_visnetwork(
  names =
    !ends_with("_[0-9a-z]{8}") & # dynamic targets
    !starts_with("gg_") & # ggplot2
    !starts_with("df_") & # data.frame / tibble
    !ends_with("_head"),  # snapshots of data.frame
  shortcut = FALSE,
  zoom_speed = .25,   physics = TRUE,
  targets_only = TRUE, script = pr_script)
tar_make(
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
      negate = TRUE
    ) # %>% str_subset("^gg_", negate = TRUE)
)
length(tar_objs) 
length(not_brnch)
tar_load(not_brnch %>% all_of())
mget(not_brnch) %>% str(max.level = 2, list.len = 6, give.attr = FALSE)
# tar_load(tar_objects(starts_with("gg_"))) # see also any_of()
# tar_load_everything() %>% str()
(tar_load_globals())
.packages()
# print(targets::tar_read(group, branches = 2))
data(mtcars)
mtcars 