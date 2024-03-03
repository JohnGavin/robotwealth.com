# TODO: rebuild image from scratch to minimise nixos image size
#   https://semaphoreci.com/blog/reduce-docker-image-size
#
###
# ln -Fs ~/Documents_GitHub/robotwealth.com/Dockerfile ~/Documents_GitHub/robotwealth.com/.devcontainer/Dockerfile
# ls -lhrt ./.devcontainer/Dockerfile
# MYDATA_DIR=/Users/johngavin/Datashare; export MYDATA_DIR
# IP=$(ifconfig en0 | grep 'inet ' | awk '{print $2}'); export IP
# docker run -ti --rm -u "$USERNAME" \
#   -w /Users/"$USERNAME" \
#   -e DISPLAY=$IP:0 \
#   -v $MYDATA_DIR:/home/"$USERNAME"/data \
#   -v /tmp/.X11-unix:/tmp/.X11-unix \
#   ttmmghmm/"$USERNAME" /bin/bash
# docker run -ti --rm ttmmghmm/$IMG:latest
# https://stackoverflow.com/questions/46018102/how-can-i-use-matplotlib-pyplot-in-a-docker-container
# TODO: root in /
# TODO: plot(1:10)
# NB: linux/amd64 NOT --platform linux/amd64 --privileged
# 	--env DATABASE_URL=loremipsum \
# 	--env flag accessible as an env var at _run_time
#
# https://github.com/b-rodrigues/nix_experiments/blob/master/Dockerfile
# https://www.brodrigues.co/blog/2023-07-13-nix_for_r_part1/

# Stage One: create dev image
# IMG=dev
# echo $IMG
# docker build -f Dockerfile --target image_$IMG -t ttmmghmm/$IMG .
# --build-arg DEV=dev --build-arg PROJ=proj --build-arg GITHUB_PAT=$GITHUB_PAT --build-arg USERNAME=rstudio .
# 5 mins / 4.7gb
FROM nixos/nix AS image_dev

# create Linux group and user, both called <pkg-name>.
#   - instead of the default root user
# https://hosting.analythium.io/dockerizing-shiny-applications/
ARG DEV=dev
# auto creates rix_dev folder
WORKDIR /home/$DEV/
COPY $DEV.nix ./$DEV.nix
# create DEV user/group & build/run DEV image
ARG RTEXT=' sessionInfo() ; system("ls -lahrt") ; getwd() '
RUN nix-shell ./$DEV.nix --verbose --run " Rscript -e '$RTEXT' " >> ./sessionInfo_$DEV.txt
CMD ["radian"]
# CMD ["R", "-e", "shiny::runApp('/home/app')"]

# Stage Two: Create project/package image
# IMG=proj
# docker build -f Dockerfile --target image_$IMG -t ttmmghmm/$IMG .
# 2 mins / 5gb
FROM image_dev AS image_proj
ARG PROJ=proj
COPY $PROJ.nix ./$PROJ.nix
# build/run PROJ image
RUN  nix-shell ./$PROJ.nix --run " Rscript -e '$RTEXT' " >> ./sessionInfo_$PROJ.txt
CMD ["radian"]

# docker images ttmmghmm/"$IMG"
# echo "$DOCKER_PSWD" | docker login -u ttmmghmm --password-stdin
# docker push ttmmghmm/"$IMG":latest
# docker pull ttmmghmm/"$IMG":latest
# docker rmi ttmmghmm/nix_docker
~/Downloads/dist_mac_m1/docker-slim \
  build ttmmghmm/"$IMG"
  --sensor-ipc-mode proxy \
  --sensor-ipc-endpoint 172.17.0.1 \
  --http-probe=false ttmmghmm/"$IMG" ;
# proj before 5,053,249,935

# TODO: 'addgroup' not valid on nixos?
# addgroup --system $DEV && \
# adduser --system --ingroup $DEV $DEV && \
# cd /home/$DEV/ && \
# USER ${DEV}
