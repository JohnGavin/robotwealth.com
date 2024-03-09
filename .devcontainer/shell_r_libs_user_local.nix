# https://churchman.nl/tag/r/
# nix-shell --pure shell_churchman.nix

with import <nixpkgs> {};
let
  my-r = rWrapper.override {
    packages = with rPackages; [ 
      ggplot2
      plyr
      tidyr
      devtools
    ];
  };
in  
  pkgs.mkShell {
    buildInputs = [
      bashInteractive
      my-r
    ];
    shellHook = ''
      mkdir -p "$(pwd)/_libs"
      export R_LIBS_USER="$(pwd)/_libs"
    '';
  }

