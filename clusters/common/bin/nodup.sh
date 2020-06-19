#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/nodup.sh

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}

if [ ${VC} = "_VC_UNSET_" ] ; then
  declare -x VC=$(basename $(pwd))
  declare -x CLUSTERNAME=${VC}
  echo ${0}: VC is unset. Assuming: \"${VC}\"
fi

declare -x ANCHOR=../common
declare -x LOADER_SHLOAD=${ANCHOR}/loader/shload.sh
declare -x BASEDIR=${ANCHOR}/..

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LOADER_SHLOAD}"
  exit 99
fi
source ${LOADER_SHLOAD}

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

# this wonkiness is so that this script can orient itself when run
# in different dom0/host home directory structures, inside and outside the cluster

declare -x REQUESTED_HOST=${1}
if [ ${#VC} -ne 2 ] ; then
  declare -x VC=${1:0:2}
fi

declare -x COMMON=${BASEDIR}/${VC}/common
declare -x STATE_D=${COMMON}/._state

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

declare -x STATE_RUNNING=${STATE_D}/running
declare -x STATE_PROVISIONED=${STATE_D}/provisioned

for d in ${BASEDIR} ${COMMON} ${STATE_D} ${STATE_RUNNING} ${STATE_PROVISIONED}
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
  if [ "${m}" = "${REQUESTED_HOST}" ] ; then
    ErrExit ${EX_ALREADY} "vagrant instance \"${REQUESTED_HOST}\" already exists, but was not fully provisioned.\nTo manually remove it: 'make -C ${REQUESTED_HOST:0:2} ${REQUESTED_HOST}_UNPROVISION'; make ${REQUESTED_HOST}\n [${m}]"
  fi

done

if [ -n "${REQUESTED_HOST}" ] ; then
  rm -f ${STATE_RUNNING}/${REQUESTED_HOST} ${STATE_PROVISIONED}/${REQUESTED_HOST}
fi

trap '' 0
exit ${EX_OK}
