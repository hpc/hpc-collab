#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/ingestfromhost.sh

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
declare -x COMMON_USERADD=${COMMON_PROVISION}/useradd
declare -x ID=$(id -n -u)
declare -x HOME=${HOME:-/tmp}
declare -x SITE_VARS=${ENV}/site-vars.sh

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

  echo ${shell} ${home}
  return
}

main() {
  SetFlags
  local common_home=${COMMON_HOME}
  local REQUESTED_HOST=${1:-""}
  local calling_args=($@)
  shift

  if [ $# -lt 2 ] ; then
    ErrExit ${EX_USAGE} "arguments? expected calling host and possibly :<KEYWORD>"
  fi

  configParams=($(chkConfig))
  rc=$?
  if [ ${rc} -eq ${EX_ALREADY} ] ; then
    Verbose "  provisioned"
    exit ${EX_OK}
  fi
  shell=$(echo ${configParams[0]})

  home=$(echo ${configParams[1]})
  export HOME=$(echo ${home})

  if [ ! -x "$(which ${shell})" ] ; then
    ErrExit ${EX_USAGE} "shell: ${shell} is not executable"
  fi
  if [ ! -d "${home}" ] ; then
    ErrExit ${EX_USAGE} "home: ${home} is not a directory"
  fi

  dotfiles=""
  dotssh=""
  files=""

  for f in $@
  do
    case "${f}" in
    :DOTFILES)
      case "${shell}" in
        *bash*)  _dotfiles="${home}/.profile* ${home}/.bash*"                                ;;
        *csh*)   _dotfiles="${home}/.csh* ${home}/.log*"                                     ;;
	*fish*)  _dotfiles="${home}/.config/fish"                                            ;;
        *zsh*)   _dotfiles="${home}/.zprofile ${home}/.zlog* ${home}/.zshrc ${home}/.zshenv" ;;
        *sh*|"") _dotfiles="${home}/.profile"                                                ;;
      esac

      for _f in ${_dotfiles}
      do
        if [ -d "${_f}" -o \( -f "${_f}" -a -s "${_f}" \) ] ; then
          dotfiles="${dotfiles} ${_f}"
        fi 
      done
      if [ -n "${VERBOSE}" -a -n "${dotfiles}" ] ; then
        Verbose ":DOTFILES ${dotfiles}"
      fi
      ;;

    :DOTSSH)
      sshfiles=$(ls ${home}/.ssh)
      for s in ${sshfiles}
      do
        case "${s}" in
          *.pub|identity|authorized_keys|config) dotssh="${dotssh} ${home}/.ssh/${s}" ;;
          id_rsa|id_dsa|id_ecdsa|id_ed25519)                                     ;;
          *)                                     dotssh="${dotssh} ${home}/.ssh/${s}" ;;
        esac
      done
      if [ -n "${VERBOSE}" -a -n "${dotssh}" ] ; then
        Verbose ":DOTSSH ${dotssh}"
      fi
      ;;

    *)
      if [ ! -r ${f} ] ; then
        ErrExit ${EX_OSFILE} "f:${f} is not readable"
      fi
      d=$(dirname ${f})
      if [ ! -d "${common_home}/${d}" ] ; then
        Rc ErrExit ${EX_OSFILE} "mkdir -p ${common_home}/${d}"
      fi
      files="${files} ${f}"
      if [ -n "${VERBOSE}" -a -n "${files}" ] ; then
        Verbose "files: ${files}"
      fi
      ;;
    esac
  done

  if [ -n "${dotssh}" -o -n "${dotfiles}" ] ; then
    if [ ! -d "${common_home}" ] ; then
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${common_home}"
    fi
    if [ -n "${dotssh}" ] ; then
      if [ ! -d ${common_home}/.ssh ] ; then
        Rc ErrExit ${EX_OSFILE} "mkdir -p ${common_home}/${ID}/.ssh"
        Rc ErrExit ${EX_OSFILE} "chmod 0700 ${common_home}/${ID}/.ssh"
      fi
    fi
  fi

  rsync_args=cauW
  if [ -n "${VERBOSE}" ] ; then
    rsync_args="${rsync_args}v"
  fi

  for f in ${dotfiles}
  do
    if [ -d ${f} ] ; then
      _f=${f##${home}}
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${common_home}/${ID}/${_f}"
      Rc ErrExit ${EX_OSFILE} "rsync -${rsync_args} ${f}/ ${common_home}/${ID}/${_f}"
    else
      Rc ErrExit ${EX_OSFILE} "rsync -${rsync_args} ${f} ${common_home}/${ID}/"
    fi
  done
  for f in ${dotssh}
  do
    Rc ErrExit ${EX_OSFILE} "rsync -${rsync_args} ${f} ${common_home}/${ID}/.ssh/"
  done
  for f in ${files}
  do
    Rc ErrExit ${EX_OSFILE} "rsync -${rsync_args} ${f} ${common_home}/${ID}/${f}"
  done

  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}
