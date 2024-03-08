c("targets", "here") %>%
  sapply(library,
    character.only = TRUE,
    quietly = TRUE) %>%
  invisible()
# pacman::p_load(targets, here)
# file to declare packages that targets need
tar_config_set(script = here('R', '_targets.R'))
tar_make()
