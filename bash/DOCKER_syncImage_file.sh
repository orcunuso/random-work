#!/bin/bash
# This script reads docker image list from DOCKER_syncImage file and syncs them to a private registry server.
# A user that has push permissions on the private registry and its token should be ready.
# The variables that starts with SRC comes from a source file (such as scriptname.sh.source)
# # can be used to comment out undesired images.

set -e
IFS="/"

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

###############################################################################

if [ $# -ne 0 ]; then
  echo "USAGE: $0"
  exit 1
fi

source `basename "$0"`.source
docker login ${SRC_REGISTRY_SERVER} -u ${SRC_REGISTRY_USER} -p ${SRC_REGISTRY_TOKEN}

while read registry project image; do

  if [[ ${registry:0:1} == "#" ]]; then continue; fi

  strImageDockerName="$registry/$project/$image"
  strImageInternName="$SRC_REGISTRY_SERVER/$project/$image"

  printf "\n"
  printf "Original Image Name: \t${white}${bold}$strImageDockerName${reset}\n"
  printf "Tagged Image Name: \t${white}${bold}$strImageInternName${reset}\n"

  docker pull "$strImageDockerName" &>/dev/null						&& printf "\t\t${green}✔ Docker pull success${reset}\n" || printf "\t\t${red}✖ Docker pull failed${reset}\n"
  docker tag "$strImageDockerName" "$strImageInternName" &>/dev/null			&& printf "\t\t${green}✔ Docker tag success${reset}\n" || printf "\t\t${red}✖ Docker tag failed${reset}\n"
  docker push "$strImageInternName" &>/dev/null						&& printf "\t\t${green}✔ Docker push success${reset}\n" || printf "\t\t${red}✖ Docker push failed${reset}\n"
  docker rmi "$strImageInternName" &>/dev/null						&& printf "\t\t${green}✔ Docker rmi success${reset}\n" || printf "\t\t${red}✖ Docker rmi failed${reset}\n"
  docker rmi "$strImageDockerName" &>/dev/null						&& printf "\t\t${green}✔ Docker rmi success${reset}\n" || printf "\t\t${red}✖ Docker rmi failed${reset}\n"
  printf "\n"

done < ./DOCKER_syncImage

docker logout ${SRC_REGISTRY_SERVER}
