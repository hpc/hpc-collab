#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/nodup.sh

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

# this wonkiness is so that this script can orient itself when run by different users
# in different dom0 home directory structures
declare -x COMMON=${BASEDIR}/common
declare -x COMMON_HOME=${COMMON}/home
declare -x COMMON_PROVISION=${COMMON}/provision
declare -x COMMON_USERADD=${COMMON_PROVISION}/useradd
declare -x ID=$(id -n -u)

declare -x PWD=$(pwd)
declare -x REQUESTED_HOST=${1}

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

SetFlags >/dev/null 2>&1

if [ -z "${REQUESTED_HOST}" ] ; then
  ErrExit ${EX_SOFTWARE} "REQUESTED_HOST empty" 
fi

if [ -z "${COMMON}" ] ; then
  ErrExit ${EX_SOFTWARE} "COMMON empty"
fi

if [ -z "${STATE_D}" ] ; then
  ErrExit ${EX_SOFTWARE} "STATE_D empty"
fi

if [ -z "${STATE_RUNNING}" ] ; then
  ErrExit ${EX_SOFTWARE} "STATE_RUNNING empty"
fi

if [ -z "${STATE_PROVISIONED}" ] ; then
  ErrExit ${EX_SOFTWARE} "STATE_PROVISIONED empty"
fi

for d in ${COMMON} ${STATE_D} ${STATE_RUNNING} ${STATE_PROVISIONED}
do
  if [ ! -d ${d} ] ; then
    ErrExit ${EX_SOFTWARE} "${d} not a directory"
  fi
done

if [ -f ${STATE_PROVISIONED}/${REQUESTED_HOST} ] ; then
  Verbose " provisioned"
  exit ${EX_OK}
fi

## @todo collect the provider from the Vagrantfile and select which mechanism to list, or use vagrant commands
#existing=$(VBoxManage list vms)
existing=$(echo $(vagrant global-status | egrep 'running|poweroff|suspend' | awk '{print $2}'))
for m in ${existing}
do
  if [ -f ${STATE_PROVISIONED}/${m} ] ; then
    #Verbose " ${m}: provisioned [skipped]"
    continue
  fi
  echo ${existing} | grep ${REQUESTED_HOST} >/dev/null 2>&1
  rc=$?
  if [ ${rc} -eq ${GREP_FOUND} ] ; then
    ErrExit ${EX_ALREADY} "vagrant instance \"${REQUESTED_HOST}\" already exists, but was not fully provisioned.\nTo manually remove it: 'vagrant destroy ${REQUESTED_HOST}' or 'make ${REQUESTED_HOST}!'"
  fi

done

if [ -n "${REQUESTED_HOST}" ] ; then
  rm -f ${STATE_RUNNING}/${REQUESTED_HOST} ${STATE_PROVISIONED}/${REQUESTED_HOST}
fi

trap '' 0
exit ${EX_OK}
