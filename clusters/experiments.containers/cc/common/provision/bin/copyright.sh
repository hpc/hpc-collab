#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/copyright.sh

## This ANCHOR is used because the shell loader may be called from multiple locations:
###  the primary host ("dom0") or from the guest host ("/vagrant/...")
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

# this wonkiness is so that this script can orient itself when run by different users
# in different dom0 home directory structures
declare -x COMMON=${BASEDIR}/common
declare -x COMMON_HOME=${COMMON}/home
declare -x COMMON_PROVISION=${COMMON}/provision

main() {
  Copyright
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}
