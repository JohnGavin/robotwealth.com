# make project environment available to others
# https://nixos.org/manual/nixpkgs/stable/#installation
# nix-shell --pure shell_others.nix
with import <nixpkgs> {};
{
  robotweath_com = stdenv.mkDerivation {
    name = "robotweath_com";
    version = "1";
    src = if lib.inNixShell then null else nix;

    buildInputs = with rPackages; [
      R
      ggplot2
      knitr
    ];
  };
}
