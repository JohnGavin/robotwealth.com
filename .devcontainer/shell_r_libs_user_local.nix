# https://churchman.nl/tag/r/
#   export "R_LIBS_USER"="./_r_libs_user"  
#   Sys.setenv("R_LIBS_USER" = "./_r_libs_user") 
# nix-shell --pure shell_r_libs_user_local.nix

with import <nixpkgs> {};
let
  my-r = rWrapper.override {
    packages = with rPackages; [ 
      ggplot2
      dplyr
      tidyr
      devtools
    ];
  };
in  
  pkgs.mkShell {
    buildInputs = [
      bashInteractive
      oh-my-zsh
      my-r
    ];
    # NB: shell hook to create local user lib
    #   export "R_LIBS_USER"="./_r_libs_user" or 
    #   Sys.setenv("R_LIBS_USER" = "./_r_libs_user") 
    shellHook = ''
      mkdir -p "$(pwd)/_r_libs_user"
      export R_LIBS_USER="$(pwd)/_r_libs_user"
    '';
    # Install local lib
    # Sys.getenv("R_LIBS_USER") ; install.packages("rix", repos = c("https://b-rodrigues.r-universe.dev", "https://cloud.r-project.org"))
  }

