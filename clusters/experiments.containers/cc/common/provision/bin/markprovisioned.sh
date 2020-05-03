#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/markprovisioned.sh

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x ANCHOR=$(dirname $0)/..
declare -x LOADER_SHLOAD=${ANCHOR}/loader/shload.sh
declare -x BASEDIR=${ANCHOR}/../..

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LIB_SHLOAD}"
  exit 99
fi
source ${LOADER_SHLOAD}

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

declare -x PWD=$(pwd)
declare -x CFG=cc/cfg
declare -x ID=$(id -n -u)
declare -x REQUESTED_HOST=${1-""}

declare -x STATE=${COMMON}/._state
declare -x RUNNING=${STATE}/running
declare -x PROVISIONED=${STATE}/provisioned

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

main() {

  if [ -n "${REQUESTED_HOST}" ] ; then
    flag=${REQUESTED_HOST}
    running=${RUNNING}/${flag}
    provisioned=${PROVISIONED}/${flag}

    if [ -f ${running} ] ; then
      rm -f ${running}
    fi

    mkdir -p ${PROVISIONED}
    touch ${provisioned}
  fi

  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}
