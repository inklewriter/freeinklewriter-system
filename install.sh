#!/bin/bash

set -e 


_msg(){ echo $@; }
_panic(){ _msg $@; exit 2; }
_apt_update(){ [[ -n "$apt_updated" ]] && return ; apt update;}
_require_package(){ 
  local bin=$1
  local pack=${2:-$1}
  _msg "Installing $pack"
  _apt_update
  which $bin &>/dev/null || apt install -y --no-install-recommends $pack 
}
declare -a installationMethods
installationMethods+=( "docker" )
installationMethods+=( "native" )
apt_updated=""

# check is root
[[ "root" != "$( whoami )" ]] && _panic "You must run this script as root. Exiting."


# Choose installation method
_msg "Please choose the installation method."
select method in ${installationMethods[@]}; do 

  let $(( REPLY-- ))
  [[ -z ${installationMethods[$REPLY]} ]] && _panic "No such method. Exiting"
  break

done

# check required executables
_require_package lsb_release lsb-release
# Detect the system
architecture=$( uname -m )
release=$(lsb_release -rs)
distrib=$(lsb_release -is)

if [[ "${method}" == "docker" ]]; then 

  _require_package docker-compose
  _require_package docker docker.io


  if [[ "$architecture" != "x86_64" ]] && [[ "$architecture" != "armv7" ]]; then 
    _panic "Invalid architecture '$architecture'. Exiting"
  fi

  defaultDockerDir=/opt/inklewriter
  read -p "$( _msg "Please define the permanent installation folder (Default: $defaultDockerDir): ")" dockerDir
  dockerDir=${dockerDir:-$defaultDockerDir}
  mkdir -p $dockerDir
  cp "docker-${architecture}/docker-compose.yml" "${dockerDir}"
  cp common/.env "${dockerDir}"
  cd "${dockerDir}"
  docker-compose up


elif [[ "${method}" == "native" ]]; then

  # Check for debian
  if [[ "$distrib" != "Debian" ]] || [[ $release -lt 10 ]]; then 
    _panic "This script won't run on $distrib $release"
  fi

  # Execute the native install
  _msg "Running the install script"
  bash debian-10/install.sh

fi


# EOF
