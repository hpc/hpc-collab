#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/unprovision.sh

## @brief remove "provisioned" flag file for this node, disable the automatic /vagrant mount in Vagrantfile

## This ANCHOR is used because the shell loader may be called from the
## primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}
ANCHOR_INCLUSTER=/home/${VC}/common/provision
declare -x HOSTNAME=${HOSTNAME:-$(hostname -s)}

if [ ${VC} = "_VC_UNSET_" ] ; then
  if [ -d "${ANCHOR_INCLUSTER}" -a "${ANCHOR_INCLUSTER:2}" = "${HOSTNAME:0:2}" ] ; then
    declare -x VC=${ANCHOR_INCLUSTER}
  else
    declare -x VC=${HOSTNAME:0:2}
  fi
  declare -x CLUSTERNAME=${VC}
  echo ${0}: VC is unset. Assuming: \"${VC}\"
fi

isvirt=$(systemd-detect-virt)
rc=$?

if [ "${isvirt}" != "none" -a "${MODE}" != "host" ] ; then
  # running on VM, add users' accounts to all nodes, on one of them (Features=controller),
  # add slurm user accounts and associations
  # assume 
  declare -x ANCHOR=${ANCHOR_INCLUSTER}
  declare -x MODE=${MODE:-"cluster"}
else
  declare -x MODE=${MODE:-"host"}
  ## the invocation directory is expected to be the clusters/${VC} directory
  ## % pwd
  ## <git-repo>/clusters/vc
  ## % env VC=vc MODE="host" ../../clusters/common/bin/unprovision.sh
  declare -x ANCHOR=../common
fi

declare -x LOADER_SHLOAD=$(realpath ${ANCHOR}/loader/shload.sh)
declare -x BASEDIR=$(realpath ${ANCHOR}/..)

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LOADER_SHLOAD} -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 99
fi
source ${LOADER_SHLOAD}

env_VC=$(basename ${VC})


# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

declare -x PWD=$(pwd)

if [ -f Vagrantfile ] ; then
  _d=$(pwd)
else
  makefile_dir=$(dirname `which provision.sh`)/../../..
  _d=$(cd ${makefile_dir}; pwd)
fi
VC=$(basename ${_d})

declare -x VC_COMMON=${VC}/common
declare -x VAGRANTFILE=${VC}/Vagrantfile
declare -x HOSTNAME=$(hostname -s)
declare -x STATE_D=${VC_COMMON}/._state
declare -x PROVISIONED=${STATE_D}/provisioned

declare -x REQUESTED_HOST=${1:-${HOSTNAME}}

## @fn ClearVagrantfileSyncFolderDisabled()
##
ClearVagrantfileSyncFolderDisabled() {
  local already_cleared_rc
  local rc
  vm=${1:-"_unknown_host_"}
  grep "${vm}.*synced_folder.*/vagrant" ${VAGRANTFILE} >/dev/null 2>&1
  already_cleared_rc=$?
  grep "${vm}.*synced_folder.*/vagrant.*disabled: true" ${VAGRANTFILE} >/dev/null 2>&1
  rc=$?
  if [ ${already_cleared_rc} -eq ${GREP_FOUND} -a ${rc} -eq ${GREP_FOUND} ] ; then
    sed -i~ "/${vm}.*synced_folder.*/s/, disabled: true//" ${VAGRANTFILE}
    rc=$?
    if [ ${rc} -ne ${EX_OK} ] ; then
      echo "$(basename $0): failed sed: clear synced_folder disabled: true"
      exit 1
    fi
  fi
  return
}

RemoveMarkProvisioned() {
  if [ -d ${PROVISIONED} ] ; then
    if [ -f ${PROVISIONED}/${REQUESTED_HOST} ] ; then
      rm -f ${PROVISIONED}/${REQUESTED_HOST}
    fi
  fi
  return
}

# historical
# ClearVagrantfileSyncFolderDisabled $@
RemoveMarkProvisioned $@

exit ${EX_OK}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
