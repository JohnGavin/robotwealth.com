# This file was generated by the {rix} R package v0.6.0 on 2024-03-08
# with following call:
# >rix::rix(r_ver = "f945939fd679284d736112d3d5410eb867f3b31c",
#  > r_pkgs = c(pkgs_dev,
#  > pkgs_projj) %>% unique() %>% sort(),
#  > system_pkgs = pkgs_sys %>% unique() %>% sort(),
#  > git_pkgs = pkgs_git,
#  > ide = c("other",
#  > "code",
#  > "rstudio")[1],
#  > project_path = path_default_nix,
#  > overwrite = TRUE,
#  > print = FALSE,
#  > shell_hook = "")
# It uses nixpkgs' revision f945939fd679284d736112d3d5410eb867f3b31c for reproducibility purposes
# which will install R version latest
# Report any issues to https://github.com/b-rodrigues/rix
let
 pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/f945939fd679284d736112d3d5410eb867f3b31c.tar.gz") {};
 rpkgs = builtins.attrValues {
  inherit (pkgs.rPackages) Cairo devtools dplyr fs ggplot2 glue goodpractice here httpgd lmtest lubridate pacman patchwork purrr quarto readr reticulate rmarkdown roll rvest sandwich stringr tarchetypes targets tibbletime tidyfit tidyr visNetwork;
};
 git_archive_pkgs = [(pkgs.rPackages.buildRPackage {
    name = "rix";
    src = pkgs.fetchgit {
      url = "https://github.com/b-rodrigues/rix";
      branchName = "master";
      rev = "6dcc9bcb10dcd1baaa9a7d83bab5d1445f231455";
      sha256 = "sha256-Gn0R4ND4AHE8wjtEEyHFI4Gl0p39nlb26VLRW16kClU=";
    };
    propagatedBuildInputs = builtins.attrValues {
      inherit (pkgs.rPackages) codetools httr jsonlite sys;
    };
  })
(pkgs.rPackages.buildRPackage {
    name = "rsims";
    src = pkgs.fetchgit {
      url = "https://github.com/Robot-Wealth/rsims/";
      branchName = "main";
      rev = "5ecb5cb2cc113d0b420f18a3329ee52e283f84c0";
      sha256 = "sha256-USKhpYbNMNkiGweMCUZsGW1Ad3KQ9GBj0txn442GBkQ=";
    };
    propagatedBuildInputs = builtins.attrValues {
      inherit (pkgs.rPackages) dplyr tibble tidyr stringr magrittr ggplot2 lubridate here roll Rcpp;
    };
  }) ];
  system_packages = builtins.attrValues {
  inherit (pkgs) R glibcLocales nix cairo lazygit nano oh-my-zsh openssl quarto radianWrapper
  ;
 };
  in
  pkgs.mkShell {
    LOCALE_ARCHIVE = if pkgs.system == "x86_64-linux" then  "${pkgs.glibcLocales}/lib/locale/locale-archive" else "";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";

    buildInputs = [ git_archive_pkgs rpkgs
    system_packages
    ];

  }
