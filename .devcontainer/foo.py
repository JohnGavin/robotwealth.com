#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ ps.numpy ])"
#!nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/e51209796c4262bfb8908e3d6d72302fe4e96f5f.tar.gz
# Python3.10, numpy & sys deps always use 
# git commit e51209796c4262bfb8908e3d6d72302fe4e96f5f 
# of Nixpkgs for all of package versions
# https://nixos.org/manual/nixpkgs/stable/#python
# nix-shell ./foo.py
import numpy as np
a = np.array([1,2])
b = np.array([3,4])
print(f"The dot product of {a} and {b} is: {np.dot(a, b)}")
