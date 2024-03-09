# https://churchman.nl/2019/01/22/using-nix-to-create-python-virtual-environments/

# https://nixos.org/manual/nixpkgs/stable/#python
# python.withPackages function
# Using Python
# Ad-hoc temporary Python environment with nix-shell
# nix-shell -p 'python311.withPackages (ps: with ps; [ numpy ])' --run 'python3 foo.py'
# nix-shell -p 'python311.withPackages(ps: with ps; [ pyarrow pandas seaborn ])' --run 'python3'

# import <nixpkgs> function & {} call it
with import <nixpkgs> {};

# generic: spans all tools & langs in Nixpkgs
# brings nixpkgs attributes into local scope
let
  # withPackages create 3.11 environment
  pythonEnv = python311.withPackages (ps: [
    ps.pandas
    ps.seaborn
    # ps.polars
    ps.requests
  ]);
in mkShell {
  packages = [
    # not just interpreter + its dependencies
    pythonEnv
    # tools
    black
    mypy
    # libraries
    libffi
    openssl
  ];
}

