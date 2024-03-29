# This file was generated by the {rix} R package v0.6.0 on 2024-03-03
# with following call:
# >rix::rix(r_ver = "fa9a51752f1b5de583ad5213eb621be071806663",
#  > r_pkgs = c(pkgs_dev,
#  > pkgs_proj),
#  > system_pkgs = pkgs_sys,
#  > git_pkgs = pkgs_git,
#  > ide = c("other",
#  > "code",
#  > "rstudio")[1],
#  > project_path = path_default_nix,
#  > overwrite = TRUE,
#  > print = TRUE,
#  > shell_hook = shell_hook)
# It uses nixpkgs' revision fa9a51752f1b5de583ad5213eb621be071806663 for reproducibility purposes
# which will install R version latest
# Report any issues to https://github.com/b-rodrigues/rix
let
 pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/fa9a51752f1b5de583ad5213eb621be071806663.tar.gz") {};
 rpkgs = builtins.attrValues {
  inherit (pkgs.rPackages) Cairo devtools dplyr fs ggplot2 goodpractice httpgd pacman purrr quarto readr reticulate rmarkdown rvest stringr tarchetypes targets tidyr visNetwork;
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
  inherit (pkgs) R glibcLocales nix cairo lazygit nano oh-my-zsh openssl quarto radianWrapper;
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

    buildInputs = [ git_archive_pkgs rpkgs  system_packages  ];
      shellHook = "radian";
  }
