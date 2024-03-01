#' @title Adds new targets project to .yaml file
#' @description
#' All parameters are length-one character vectors.
#' Sets two \code{targets} environment variables:
#' \code{TAR_PROJECT} and \code{TAR_CONFIG}.
#' Sets target configuration via \code{tar_config_set}.
#' Parameters are stored in top-level project folder.
#'   \code{./<pr_yaml>.yaml}.
#' @param pr_title project title.
#' @param pr_yaml project yaml.
#' @param pr_script tar_script filename.
#' @param pr_store targets db to store objects.
#' @return nothing returned.
#' @author John Gavin
#' @export
tar_config_set_project <- function(
    pr_title = "conv_opt_cvxr",
  pr_yaml = paste0(pr_title, ".yaml"),
  pr_script = paste0(pr_title, ".R"),
  pr_store = paste0(pr_title, "_store")
){
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
} # tar_config_set_project
