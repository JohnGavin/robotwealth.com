FROM mcr.microsoft.com/devcontainers/javascript-node:0-18
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install git

# FROM nixos/nix 
# CMD nix-shell -p 'rWrapper.override{packages = [ rPackages.rix ] ; } '
# CMD ["bash"]
