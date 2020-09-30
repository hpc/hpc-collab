#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/synchome.sh

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}

if [ ${VC} = "_VC_UNSET_" ] ; then
  declare -x VC=$(basename $(pwd))
  declare -x CLUSTERNAME=${VC}
  echo ${0}: VC is unset. Assuming: \"${VC}\"
fi

#declare -x ANCHOR=cfg/provision
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

declare -x PWD=$(pwd)

declare -x ID=$(id -n -u)
declare -x IAM=$(basename $0 .sh)
declare -x TSTAMP=$(date +%Y.%m.%d.%H%M)
declare -x REQUESTED_HOST=${1-""}
declare -x VARLOG=/var/log

declare -x STORAGE_HOST=""
declare -x DB_HOST=""
declare -x SSH_OPTARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
declare -x SSH="ssh -q ${SSH_OPTARGS}"
declare -x PROVISIONED_D=common/._state/provisioned
declare -x SESSIONID=${IAM}.${ID}.${TSTAMP}
declare -x SYNCHOME_D=${SESSIONID}.d
declare -x TMPDIR
declare -x LOGROTATE_CONF=/etc/logrotate.conf

if [ -n "${TMPDIR}" ] ; then
  if [ -d ${TMPDIR} ] ; then
    TMPDIR=${PWD}/${SYNCHOME_D}
  fi
else
  TMPDIR=/tmp/${SYNCHOME_D}
fi
declare -x TARBALL=${TMPDIR}/${SESSIONID}.tgz

# ssh to cluster's storage host, create tarball of homedir, pull it out of the cluster 
CollectHome() {
  local _vc=$(echo $(basename $(cd ${VC}; pwd)))
  local fshost="${_vc}fs"

  if [ ! -f common/._state/provisioned/${fshost} ] ; then
    ErrExit ${EX_SOFTWARE} " The cluster storage node (${fshost}) is not provisioned. There's nothing to sync."
  fi

  Rc ErrExit ${EX_CONFIG}   "ping -n -q -w 1 ${fshost}"
  Rc ErrExit ${EX_SOFTWARE} "${SSH} ${fshost} /bin/true"
  Rc ErrExit ${EX_SOFTWARE} "${SSH} ${fshost} mkdir -p ${TMPDIR}"

  # check capacity of in-cluster TMPDIR, size of $HOME/../${ID} 
  Rc ErrExit ${EX_SOFTWARE} "${SSH} ${fshost} tar -czvf ${TARBALL} -C \$HOME/.. ${ID}"

  # check sizes
  Rc ErrExit ${EX_SOFTWARE} "scp ${fshost}:${TARBALL} ${TMPDIR}"
  return
}

RsyncCollectedHome() {
  # find cluster-external home template
  # rsync from ${SYNCHOME_D} to cluster home template
  # report location

  for d in common common/home common/home/${ID}
  do
    if [ ! -d ${d} ] ; then
      ErrExit ${EX_CONFIG} "d:${d} not a directory"
    fi
  done
  target_home=$(realpath common/home/${ID})

  if [ ! -s ${TARBALL} ] ; then
    ErrExit ${EX_SOFTWARE} "TARBALL:${TARBALL} empty "
  fi
  Rc ErrExit ${EX_SOFTWARE} "tar -xzvf ${TARBALL} -C ${TMPDIR}"

  for d in ${target_home} ${TMPDIR}/${ID}
  do
    if [ ! -d ${d} ] ; then
      ErrExit ${EX_CONFIG} "d:${d} not a directory"
    fi
  done

  Rc ErrExit ${EX_SOFTWARE} "rsync -4Wacuv ${TMPDIR}/${ID}/ ${target_home}"
  Verbose " ${SESSIONID} => ${target_home}"
  return
}

main() {

  SetFlags >/dev/null 2>&1
  local _vc=$(echo $(basename $(cd ${VC}; pwd)))

  Rc ErrExit ${EX_OSFILE} "mkdir -p ${TMPDIR}"
  trap "rmdir ${TMPDIR}" 0 1 2 3 15
  CollectHome
  RsyncCollectedHome
  Rc ErrExit ${EX_OSFILE} "rm -fr ${TMPDIR}"
  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
