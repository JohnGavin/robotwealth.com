
# https://wlandau.github.io/targets/reference/index.html  ----
# targets::tar_renv(extras = character(0)) # write _packages.R file to expose hidden deps
# tar_edit() - edit _this_ (_targets.R) file in proj folder
# tar_knit()	Run a dependency-aware knitr report.
# tar_change()	Always run a target when a custom object changes.
# tar_force()	Always run a target when a custom condition is true.
# tar_suppress()	Never run a target when a custom condition is true.

# 1. Load packages ----
options(tidyverse.quiet = TRUE)
# options(warnPartialMatchArgs = FALSE)

# get package names from DESCRIPTION file in current working directory. 
`%>%` <- magrittr::`%>%`
# T =>  "Depends", "Imports", "LinkingTo" and "Suggests"
# https://rtask.thinkr.fr/tame-your-namespace-with-a-dash-of-suggests/
# Packages
# remotes::dev_package_deps in targets preamble.R
# + not just reading DESCRI?PTION 
# + but also returning its dependency 
# + => number of package s > 100
# + devtools::check () CRAN max allowed is 20
remotes::dev_package_deps(dependencies = TRUE) %>% 
  dplyr::pull(package) %>% 
  stringr::str_replace_all("'", '') %>% 
  stringr::str_replace_all("\\\"", '') %>% 
  unique() %>% rev() ->
  pkgs
# WARNING: purrr::walk/base::lapply(pkgs, library ... FAILS targets
#   https://github.com/rstudio/renv/issues/143
#   purrr::walk(pkgs, library, character.only = TRUE, warn.conflicts = TRUE, quietly = TRUE)
# pacman::p_load(pkgs)
if ("plyr" %in% pkgs)
  # WARNING: tidymodels imports plyr so it MUST be after dplyr
  pkgs <- pkgs %>% setdiff('plyr') %>% c('plyr')
suppressMessages(suppressPackageStartupMessages({
  purrr::map2(
    pkgs, seq_along(pkgs) + 1, 
    \(x, y) library(x, pos = y, quiet = TRUE,
      character.only = TRUE, warn.conflicts = FALSE)) %>% 
    invisible() 
}))
on.exit(rm(list = c("%>%")))

# renv::init(bare = TRUE) to avoid copying unneeded dependencies from the main R lib
# remotes::dev_package_deps(dependencies = TRUE) %>% renv::install() # scrape deps from DESCRIPTION file

# Check dplyr is before plyr
# WARNING: tidymodels imports plyr so plyr MUST be after dplyr
# # # Error : `fn` must be an R function, not a primitive function
# It is caused by the search order of pacakges
#   e.g. tidymodels uses lots of packages that eventually use plyr
#   so ensure plyr is behind dplyr on the search list.
# Visit https://books.ropensci.org/targets/debugging.html for debugging advice.
srch <- search()
# srch %>% stringr::str_detect('plyr' ) %>% which()
tmp <- srch %>% stringr::str_subset("plyr") 
if (length(tmp) == 2)
  tmp %>% 
  identical(c("package:dplyr", "package:plyr")) %>% 
  stopifnot('R/tar_plans/plan_preamble.R: dplyr must be before plyr' = .)
rm(srch, tmp)


# python
# https://stackoverflow.com/questions/43829125/r-portfolioanalytics-error-on-create-efficientfrontier
# library(renv) ; # ----
# renv::install(pkgs) ; .libPaths()
# renv::use_python() # https://blog.rstudio.com/2019/11/06/renv-project-environments-for-r/#Integration_with_Python
# py_install(py_pkgs)
# renv::snapshot(packages = c(pkgs, py_pkgs), prompt = TRUE) # WARNING: 'packages' is critical
# renv::history()
# renv::revert() to pull out an old version of renv.lock based on the previously-discovered commit, and then use renv::restore() to restore your library from that state.



# 2. Options: tar_option_set() ----
# Even if you have no specific options to set,
#   call tar_option_set() to register the proper environment.
# set packages globally for all subsequent targets you define.
#   such as the names of required packages for clusters

# tar_config_set( # settings for the current project
#   "script" = "tar_map.R", 
#   store = "tar_map_store",
#   use_crew = FALSE, # crew in tar_make() if controller option set in tar_option_set() 
#   config = "config_test_targets.yaml", # Sys.getenv("TAR_CONFIG", "_targets.yaml"),
#   project = "project_test" #  Sys.getenv("TAR_PROJECT", "main")
# )
tar_option_set(
  # To deploy targets to PARALLEL jobs when running tar_make_clustermq().
  # #   Even if you have no specific options to set,
  # #   call tar_option_set() to register the proper environment.
  # manage tasks/workers # https://books.ropensci.org/targets/crew.html
  # workers run at all times, each is separate R process
  #   on same computer as the local R process
  controller = crew_controller_local(
    name = "crew_cntrl_local: default workers(4) idle(30)",
    workers = 4, # == max workers
    seconds_idle = 30 # shutdown then restart later
  ),
  tidy_eval = TRUE,
  # on err, find workspace image file in `_targets/workspaces/`.
  workspace_on_error = TRUE # error="workspace" 
)

# renv::status() not working with pkgs?!
targets::tar_option_set(
  # set packages globally for all subsequent targets you define.
  # https://books.ropensci.org/targets/practices.html#loading-and-configuring-r-packages
  # load R packages that your targets need to run
  packages = pkgs # base::setdiff(pkgs, y = c("")), # exclude some packages?
  #
  # imports
  # tar_option_set(imports = c("p1", "p2")) 
  #   => name conflict objects in p1 override the objects in p2 
  # https://books.ropensci.org/targets/practices.html#packages-based-invalidation
  # , imports = c("package1", "package2") tells targets to 
  # , imports = c("duckdb_arrow_sql") # tells targets to 
  # dive into the environments of package1 and package2 and 
  # reproducibly track all the objects it finds. 
  #   e.g. if you define a function f() in package1, 
  #     then you should see a function node for f() in the graph 
  #     produced by tar_visnetwork(targets_only = FALSE)
  #     targets downstream of f() will invalidate if you install 
  #     an update to package1 with a new version of f().
) 

# parallel clusters ----

# mirai needed below?

#
# https://books.ropensci.org/targets/practices.html#dependencies
# tar_option_get("envir") objects override everything 
#   in tar_option_get("imports") 
# Only set envir if _my_ package contains my whole data analysis project
#   i.e. other functions & objects from packages are ignored 
#     unless you supply a package environment to the 
#     envir argument of tar_option_set())
# WARNING: to make gg_lvls depend on changes in gg_bumps function
# 	via the top level lst_gg_bumps_lvls function
# targets::tar_option_set(envir = getNamespace("duckdb_arrow_sql"))
# # tar_option_set(envir = environment())

# tar_option_reset() # Reset all target options you previously chose
# tar_visnetwork(targets_only = TRUE)

# tar_option_set(
#   packages = c("dplyr", "tibble"),
#   repository = "aws",
#   resources = tar_resources(
#       aws = tar_resources_aws(
#         bucket = "r.projects.dir", 
#         prefix = paste0(basename(here()), "/_targets")
#         # library("aws.s3") ; b <- bucketlist() ; b <- get_bucket("r.projects.dir") ; purrr::map_chr(seq_along(b), ~ b[[.]]$Key)
#         # aws.s3::delete_bucket("r.projects.dir/duckdb_arrow_sql/") # fails?
#       )
#   ),
#   cue = tar_cue(file = FALSE) # optional
# )

# 3. Globals: user-defined functions & global objects into memory. ----
# ⁠  make custom functions available to the pipeline

#   _recursively_ read .R or .r files  and runs each 
# fp <- here('R', 'tar_plans') %>% set_names()
# tar_source(fp) # load HELPER R scripts into ⁠_targets.R
# 
# _not_ source(list.files(pattern = ".R"))
# _not_ fs::dir_ls(path_abs('R'), regexp = "\\.R$") %>%
#   # exclude plans_*.R and zzz*.R
#   str_subset("[.]*zzz|plan[.]*", negate = TRUE) %>%
#     # _not_ {.[str_detect(., pattern = '_targets', negate = T)] }
#   walk(source) %>% invisible()
#  _not_ map(source, here::here('R', 'tar_plan'))

# parallel and cluster to source files?
# ‘url’ without ‘remote’ => print to console,
#   shell commands for manual deployment of nodes
# cl <- mirai::make_cluster(4, url = host_url())
# cl
# parallel::parLapply(cl, fp, tar_source)
# status(cl)
# stop_cluster(cl)

# vignette("DEoptimPortfolioOptimization", package= 'DEoptim') 


# FIXME: devtools:: creates dependency so remove?
# https://books.ropensci.org/targets/practices.html#packages-based-invalidation
# devtools::install() # Fully install with install.packages() or equivalent. 
# devtools::load_all() # is NOT sufficient 
# because it does not make the packages available to _parallel_ workers.
# devtools::load_all() # Shift-Command-0 load functions in R/ into memory
# devtools::document() # Shift-Command-9 build and add documentation
# devtools::check() # SLOOOW build package locally and check


# board ----
# create a new local board - tar_url() ----
# create_board = create_board_fun() 

# https://github.com/r-lib/testthat/issues/1144
# switch import::from -> import::here
# 	no item called "imports" on the search list
# import::here(here, here)
# WARNING: import::from(dplyr) does NOT put dplyr ahead of plyr
# 
# '::' or ':::' import not declared from: ‘ellipsis’
#import::here(ellipsis)
#import::here(ellipsis, `::`, `:::`)

# WARNING:
# Error : `fn` must be an R function, not a primitive function
# Error : callr subprocess failed: `fn` must be an R function, not a primitive function
# Visit https://books.ropensci.org/targets/debugging.html for debugging advice.

