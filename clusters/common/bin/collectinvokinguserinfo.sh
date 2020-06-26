#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/collectinvokinguserinfo.sh

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}

if [ ${VC} = "_VC_UNSET_" ] ; then
  echo ${0}: VC is unset. Need virtual cluster identifier.
  exit 97
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

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

# this wonkiness is so that this script can orient itself when run by different users
# in different dom0 home directory structures
declare -x COMMON=${BASEDIR}/common
declare -x COMMON_HOME=${COMMON}/home
declare -x COMMON_PROVISION=${COMMON}/provision
declare -x COMMON_USERADD=${COMMON_PROVISION}/useradd
declare -x ID=$(id -n -u)
declare -x HOME=${HOME:-/tmp}
declare -x SITE_VARS=${ENV}/site-vars.sh
declare -x USER_HOME_DIR_SECONTEXT="unconfined_u:object_r:user_home_dir_t:s0"

declare -x CONSTRUCT_USERADD_DIRS="gid groups passwd secontext shell slurm sudoers.d uid"

chkConfig() {
  if [ -z "${STATE_PROVISIONED}" ] ; then
    ErrExit ${EX_CONFIG} "STATE_PROVISIONED: empty"
  fi

  if [ -z "${STATE_D}" ] ; then
    ErrExit ${EX_CONFIG} "STATE_D: empty"
  fi

  if [ -d ${STATE_D} -a -d ${STATE_PROVISIONED} -a -f ${STATE_PROVISIONED}/${REQUESTED_HOST} ] ; then
    echo "provisioned"
    exit ${EX_ALREADY}
  fi

  if [ ! -d ${COMMON_HOME} ] ; then
    ErrExit ${EX_CONFIG} "COMMON_HOME:${COMMON_HOME} not a directory"
  fi
  if [ ! -d ${COMMON_PROVISION} ] ; then
    ErrExit ${EX_CONFIG} "COMMON_PROVISION:${COMMON_PROVISION} not a directory"
  fi
  if [ ! -d ${COMMON_USERADD} ] ; then
    ErrExit ${EX_CONFIG} "COMMON_USERADD:${COMMON_USERADD} not a directory"
  fi
  if [ -z "${ID}" ] ; then
    ErrExit ${EX_CONFIG} "ID:${ID} empty"
  fi

  if [ ! -f ${SITE_VARS} ] ; then
    ErrExit ${EX_CONFIG} "SITE_VARS:${SITE_VARS} nonexistent"
  fi

  owner=$(bash -c "ls -ld ${common_home} | awk '{print \$3}'")
  if [ "${ID}" != "${owner}" ] ; then
    isvirt=$(virt-what 2>&1)
    if [[ "${isvirt}" = *virtualbox* ]] ; then 
      ErrExit ${EX_OSFILE} "ID: ${ID} is not owner of COMMON_HOME:${COMMON_HOME}, owner:${owner}"
    fi
  fi

  shell=bash
  if [ -d ${COMMON_USERADD}/${ID}/shell ] ; then
      shell=$(ls ${COMMON_USERADD}/${ID}/shell)
  fi

  home=$(bash -c "ls -ld ~${ID} | awk '{print \$9}'")
  if [ ! -d "${home}" ] ; then
    ErrExit ${EX_OSFILE} "home: ${home} is not directory"
  fi
  if [ -z "${shell}" ] ; then
    ErrExit ${EX_OSFILE} "ID: ${ID} empty shell (${COMMON_USERADD}/${ID}/shell)"
  fi

  return
}

main() {
  SetFlags >/dev/null 2>&1
  local common_home=${COMMON_HOME}
  local REQUESTED_HOST=${1:-""}
  local calling_args=($@)
  local uid
  local gid
  local numeric="^[0-9]+$"
  shift

  configParams=($(chkConfig))
  rc=$?

  shell=$(echo ${configParams[0]})

  home=$(echo ${configParams[1]})
  export HOME=$(echo ${home})

  uid=$(id -u)
  gid=$(id -g)

  for d in ${common_home}/${ID} ${COMMON_USERADD}/${ID}
  do
    if [ ! -d ${d} ] ; then
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${d}"
      Rc ErrExit ${EX_OSFILE} "chown ${uid}:${gid} ${d}"
    fi
  done


  for s in ${CONSTRUCT_USERADD_DIRS}
  do
  d=${COMMON_USERADD}/${ID}
  _s=${d}/${s}
  if [ ! -d ${_s} ] ; then
    Rc ErrExit ${EX_CONFIG} "d/s:${_s} not a directory"
  fi
  case "${s}" in
  "gid")
	if [ -z "${gid}" ] ; then
	  ErrExit ${EX_CONFIG} "gid: empty"
        fi
	if ! [[ ${gid} =~ ${numeric} ]] ; then
	  ErrExit ${EX_CONFIG} "gid:${gid} not numeric"
	fi 
        Rc ErrExit ${EX_OSFILE} "touch ${_s}/${gid}"
	;;

  "groups")
	if [ ! -f ${_s}/wheel ] ; then
          Rc ErrExit ${EX_OSFILE} "touch ${_s}/wheel"
	fi
	;;

  "passwd")
	# leave passwd dir empty to have no passwd
	;;

  "secontext")
	if [ ! -f ${_s}/${USER_HOME_DIR_SECONTEXT} ] ; then
	  Rc ErrExit ${EX_OSFILE} "touch ${_s}/${USER_HOME_DIR_SECONTEXT}"
	fi
	;;

  "shell")
  	_shell=${SHELL:-bash}
  	shell=$(which ${_shell})

  	if [ ! -x "${shell}" ] ; then
	    ErrExit ${EX_USAGE} "shell: ${shell} _shell:${_shell} SHELL:${SHELL} is not executable"
	fi
	;;

  "slurm")
	# must be constructed once the cluster is built
	;;

  "sudoers.d")
	m=${_s}/${ID}
	if [ ! -f ${m} ] ; then
	  echo "${ID} ALL=(ALL) NOPASSWD: ALL" > ${m}
	fi
	;;

  "uid")
	if [ -z "${uid}" ] ; then
	  ErrExit ${EX_CONFIG} "uid: empty"
        fi
	if ! [[ ${uid} =~ ${numeric} ]] ; then
	  ErrExit ${EX_CONFIG} "uid:${uid} not numeric"
	fi 
	_uid=$(ls ${_s})
	if [ -z "${_uid}" ] ; then
	  if [ ! -f ${_s}/${uid} ] ; then
            Rc ErrExit ${EX_OSFILE} "touch ${_s}/${uid}"
	  fi
	fi
	;;
  esac
  done
  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
