
FROM nixos/nix AS image_proj
RUN nix-shell -p 'rWrapper.override{packages = [ rPackages.pacman ];}'
CMD ["bash"]

