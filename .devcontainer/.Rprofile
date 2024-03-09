### File generated by `rix::rix_init()` ###
# 1. Currently, system RStudio does not inherit environmental variables
#   defined in `$HOME/.zshrc`, `$HOME/.bashrc` and alike. This is workaround to 
#   make the path of the nix store and hence basic nix commands available
#   in an RStudio session
# 2. For nix-R session, remove `R_LIBS_USER`, system's R user library.`.
#   This guarantees no user libraries from the system are loaded and only 
#   R packages in the Nix store are used. This makes Nix-R behave in pure manner
#   at run-time.
{
    is_rstudio <- Sys.getenv("RSTUDIO") == "1"
    is_nixr <- nzchar(Sys.getenv("NIX_STORE"))
    if (isFALSE(is_nixr) && isTRUE(is_rstudio)) {
        cat("{rix} detected RStudio R session")
        old_path <- Sys.getenv("PATH")
        nix_path <- "/nix/var/nix/profiles/default/bin"
        has_nix_path <- any(grepl(nix_path, old_path))
        if (isFALSE(has_nix_path)) {
            Sys.setenv(PATH = paste(old_path, nix_path, sep = ":"))
        }
        rm(old_path, nix_path)
    }
    
    if (isTRUE(is_nixr)) {
        current_paths <- .libPaths()
        userlib_paths <- paste(Sys.getenv("R_LIBS_USER"), collapse = "|")
        user_dir <- grep(userlib_paths, current_paths)
        sub_dir <- grep(getwd(), userlib_paths)
        # keep paths that are subdirectories in .libPaths()
        keep_paths <- setdiff(user_dir, sub_dir)
        new_paths <- current_paths[-]
        .libPaths(new_paths)
        rm(current_paths, userlib_paths, user_dir, new_paths)
    }
    rm(is_rstudio, is_nixr)
}
