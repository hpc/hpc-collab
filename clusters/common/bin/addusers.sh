#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/addusers.sh
## @brief after the cluster is configured, bulk add user accounts to OS and slurm associations for a list of users
##
## 
## Input list is a command line argument list
## @todo @future, stdin may be a list of user monikers
## 
## Using the User.Template structure in the default useradd configuration directory,
## construct a pseudo config tree and call the generic AddUserAccount() function on that branch.

## Warn if user is already present, provided 'VERBOSE' = true
## If user is already present, no-op is successful.
## 
## AutoAssign uid and gid values, based on the standard User.Template.
## 
## Similar to synchome or synclogs, this is run from the host. See: MODE
##

set -o nounset

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

declare -x MODE=""
if [ "${isvirt}" != "none" ] ; then
  # running on VM, add users' accounts to all nodes, on one of them (Features=controller),
  # add slurm user accounts and associations
  # assume 
  declare -x ANCHOR=${ANCHOR_INCLUSTER}
  MODE="cluster"
else
  MODE="host"
  ## the invocation directory is expected to be the clusters/${VC} directory
  ## % pwd
  ## <git-repo>/clusters/vc
  ## % env VC=vc ../../clusters/common/bin/addusers.sh
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

declare -x PWD=$(pwd)

declare -x CLUSTERNAME=${CLUSTERNAME:-$(basename ${VC})}
declare -x CFG=$(realpath ${VC}/cfg)
declare -x DEFAULT_ARGS="-V -T"
declare -x ORIG_ARG0=""
declare -x ORIG_ARGS=""
declare -x ARG_SEP=":::"
declare -x ID=$(id -n -u)
declare -x GID=$(id -n -g)
declare -x IAM=$(basename $0 .sh)

declare -x NODELIST=""
declare -x SSH_OPTARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o CheckHostIP=no"
declare -x SSH="ssh -q ${SSH_OPTARGS} "

declare -x TMPDIR=${TMPDIR:-/tmp}
declare -x TRACE=""
declare -x TSTAMP=$(date +%Y.%m.%d.%H%M)
declare -x USERLIST_FILE=""
declare -x USERLIST=""
declare -x VERBOSE=""
declare -x WORK_D=${TMPDIR:-/tmp}/${IAM}.${TSTAMP}

SetVerbose() {
  VERBOSE=${1:-"true"}
}

## @fn SetTrace()
## @brief generates a tracefile on exit showing timestamps for each line
SetTrace() {
  if [ -z "${TRACE}" ] ; then
    return
  fi

  _now_ms=$(date +%s%N)
  export PS4='$(((`date +%s%N`-${_now_ms})/1000000))\011${LINENO}\011${FUNCNAME[0]\011+${FUNCNAME[0]}() }'
  Rc ErrExit ${EX_OSFILE} "mkdir -p ${WORK_D}"
  exec 17> ${TMPDIR}/${IAM}.${TSTAMP}.trace
  BASH_XTRACEFD="17"
  set -x
  return
}

# @fn TraceOff()
#
TraceOff() {
  set +xv
  return
}

# @fn SufficientAuth()
#
SufficientAuth() {
  if [ "${ID}" != "root" ] ; then
    ErrExit ${EX_NOPERM} "Sorry. Insufficient authority to add users."
  fi
  return
}

# @fn EscalateAuthCheck()
#
EscalateAuthCheck() {
  Rc ErrExit ${EX_NOPERM} "sudo true"
  return
}

# @fn CheckTemplate()
#
CheckTemplate() {
  local utemplate_d=${USERADD}/User.Template
  local utemplate_flag=${utemplate_d}/Template

  if [ -z "${USERADD}" ] ; then
    ErrExit ${EX_CONFIG} "USERADD empty"
  fi
  if [ ! -d "${USERADD}" ] ; then
    ErrExit ${EX_OSFILE} "USERADD:${USERADD} not a directory"
  fi
  if [ ! -d "${utemplate_d}" ] ; then
    ErrExit ${EX_CONFIG} "utemplate_d:${utemplate_d}"
  fi
  if [ ! -f "${utemplate_flag}" ] ; then
    ErrExit ${EX_CONFIG} "utemplate_flag:${utemplate_flag} does not exist"
  fi
  return
}

## @fn CreateUserCfg()
##
CreateUserCfg() {
  local u=${1:-_no_user_moniker_}
  local u_d=""
  local uid_first=""
  local uid=""
  local gid=""
  local maxuid=$(getent passwd | grep -v nobody | awk -F: '{ print $3 }' | sort -n | uniq | tail -1)
  local maxgid=$(getent passwd | grep -v nobody | awk -F: '{ print $4 }' | sort -n | uniq | tail -1)
  local useradd=/home/$(basename ${VC})/common/provision/useradd

  u_d=${WORK_D}/${u}
  if [ "${u_d}" = "${TMPDIR}/_no_user_moniker_" ] ; then
    ErrExit ${EX_SOFTWARE} "CreateUserCfg(): u_d:${u_d}"
  fi

  Rc ErrExit ${EX_OSFILE} "mkdir -p ${u_d}"
  Rc ErrExit ${EX_OSFILE} "rsync -lr ${useradd}/User.Template/ ${u_d}"
  Rc ErrExit ${EX_OSFILE} "[ -d ${u_d} ] && chmod -R u+w ${u_d}"
  Rc ErrExit ${EX_OSFILE} "mv ${u_d}/sudoers.d/User.Template ${u_d}/sudoers.d/${u}"
  Rc ErrExit ${EX_OSFILE} "sed -i \"s/User.Template/${u}/\" ${u_d}/sudoers.d/${u} ;"
  Rc ErrExit ${EX_OSFILE} "rm ${u_d}/Template"

  uid=$(( maxuid + 1 ))
  local broken_config=($(ls ${u_d}/uid/*))

  if [ ${#broken_config[@]} -gt 1 ] ; then
    if [ "${broken_config[0]}" -ne "${broken_config[1]}" -a "${broken_config[1]}" -eq "${uid}" ] ; then
      Warn ${EX_SOFTWARE} "rm -f ${broken_config[0]}"
      Rc ErrExit ${EX_SOFTWARE} "rm -f ${broken_config[0]}"
    else
      ErrExit ${EX_CONFIG} "${u_d}/uid/*:${broken_config} -- insufficient cleanup from prior attempt to add user?"
    fi
  fi
  Rc ErrExit ${EX_OSFILE} "mv ${u_d}/uid/* ${u_d}/uid/${uid}"

  gid=$(( maxgid + 1 ))
  broken_config=($(ls ${u_d}/gid/*))
  if [ ${#broken_config[@]} -gt 1 ] ; then
    ErrExit ${EX_CONFIG} "${u_d}/gid/*:${broken_config}"
  fi
  Rc ErrExit ${EX_OSFILE} "mv ${u_d}/gid/* ${u_d}/gid/${gid}"

  Rc ErrExit ${EX_OSFILE} "rm -rf ${u_d}/verify/"
  Rc ErrExit ${EX_OSFILE} "sudo chown -R ${ID}:${GID} ${u_d}"
  Rc ErrExit ${EX_OSFILE} "sudo mkdir -p /home/vagrant/common/home/${u}"
  Rc ErrExit ${EX_OSFILE} "sudo ln -s -f /home/vagrant/common/home/${u} /home/${u}"

  return
}

## @fn CreateUserCfgTree()
##
CreateUserCfgTree() {
  local u

  for u in ${USERLIST}
  do
    CreateUserCfg ${u}
  done
  return
}

## @fn AddUsersToThisHost() {
## for all nodes, invoke the generic AddUserAccount function
##
AddUsersToThisHost() {
  local u

  if [ -z "${USERLIST}" ] ; then
    return
  fi

  EscalateAuthCheck
  for u in ${USERLIST}
  do
    if [ "${ID}" != "root" ] ; then
      vc=${VC/\//}
      if [ -n "${VERBOSE}" ] ; then
        Warn ${EX_NOPERM} "Insufficient authorization: will attempt to re-execute (\"env VC=${vc} ${ORIG_ARG0} ${ORIG_ARGS}\") with higher privileges"
      fi
      Rc ErrExit ${EX_OSFILE} "sudo rm -rf ${WORK_D}/${u}"
      Rc ErrExit ${EX_OSFILE} "echo ${u} | sudo -n -E -- env VC=${vc} bash ${ORIG_ARG0} ${ORIG_ARGS}"
    else
      AddUserAccount ${WORK_D}/${u}
    fi
    # if the user hasn't just input the list of users, emit them as we add them to the cluster 
  done
  local msg=""
  HOSTNAME=${HOSTNAME:-$(hostname -s)}
  if [ -z "${USERLIST_FILE}" -a -n "${USERLIST}" ] ; then
    msg=" ${HOSTNAME}: ${USERLIST}"
  else
    msg=" ${HOSTNAME}"
  fi
  Verbose " ${msg}"
  return
}

## @fn AddUsersToNode() {
## for all nodes, reach into them and invoke AddUsersToThisHost
AddUsersToNodes() {
  local n
  local vc=$(basename ${VC})
  local incluster_path="/home/${vc}/common/provision/bin/${IAM}.sh"
  local workdir=/home/vagrant/cfg/provision
  local nodelist=${NODELIST}
  local notfirst=""

  for n in ${nodelist}
  do 
    if [ -n "${USERLIST}" ] ; then
      if [ -n "${VERBOSE}" ] ; then
        echo -n "${notfirst}${n}" >&2
      fi
      Rc ErrExit ${EX_OSERR} "echo ${USERLIST} | ${SSH} ${n} \"cd ${workdir}; env VC=${vc} ${incluster_path}\" ;"
      notfirst=" "
    fi
  done
  if [ -n "${VERBOSE}" ] ; then
    echo ''
  fi
  return
}


## @fn AddUsersToSlurmDB()
## for all nodes, reach into them and invoke AddUsersToThisHost
AddUsersToSlurmDB() {
  HOSTNAME=${HOSTNAME:-$(hostname -s)}
  local nodeFeatures=$(scontrol show node ${HOSTNAME} -o | sed 's/^.* AvailableFeatures=//' | sed 's/ .*$//' | sed 's/,/ /g')
  local f
  local u
  local addAssoc=""
  for f in ${nodeFeatures}
  do
    if [ "${f}" = "login" ] ; then
      addAssoc="true"
    fi
  done
  if [ -z "${addAssoc}" ] ; then
    return
  fi

  for u in ${USERLIST}
  do
    AddSlurmAccountUserAssociations ${WORK_D}/${u}
  done
	return
}

## @fn ConstructNodeList() {
##
ConstructNodeList() {
  local n=""
  local cfglist=""
  local nodes=""

  ## for the cluster definition specified by VC
  cfglist=$(echo $(ls -d ${CFG}/*))
  for n in ${cfglist}
  do
    if [ -L "${n}" ] ; then
      continue
    fi
    if [ -d "${n}" ] ; then
      ## @todo also check for key attributes? sanity check the tree, etc
      if [ -n "${nodes}" ] ; then
        nodes="${nodes} $(basename ${n})"
      else
        nodes="$(basename ${n})"
      fi
    fi
  done
  export NODELIST="${nodes}"
  return
}

# @fn ReadUsers()
#
ReadUsers() {
  readfrom=${1:-"-"}
  local userlist=""
  local line=""

  while read line
  do
    if [ -z "${line}" ] ; then
      return
    fi
    local word=""
    for word in ${line}
    do
      if [ -n "${userlist}" ] ; then
        userlist="${userlist} ${word}"
      else
        userlist="${word}"
      fi
    done
  done < <(cat ${readfrom})

  echo "${userlist}"
  return
}

# @fn UserListFrom()
#
UserListFrom() {
  userlist_file=${1:-"-"}
  local userlist=""

  userlist=$(ReadUsers ${userlist_file})
  if [ -z "${userlist}" ] ; then
    if [ -n "${VERBOSE}" ] ; then
      ErrExit ${EX_SOFTWARE} "EX_SOFTWARE UserListFrom(userlist_file:${userlist_file}): USERLIST: empty"
    fi
  fi

  echo ${userlist}
  return
}

# @fn ParseArgs()
# ParseArgs() is not re-entrant, modifies OPTIND
# This ParseArgs/Main structure where we set a known internal key
# and then check for it during the action phase is an old habit from
# when it made sense to do this with a bitfield.
# Some might claim a minor security benefit, in that the actual implementation
# routines need not be known to the upper layer arg parsing layer.
# It might still make sense if we wanted to rearrange the order of the requests.
#
# Note: called as a sub-process, information returned is via stdout, 'export' & 'setenv' are meaningless
#
ParseArgs() {
  local opt
  local _doWhat=""
  local userlistfilepath=""
  local prefix=""
  local suffix=""

  while getopts "f:VvTt" opt; do
    case "${opt}" in
    "f")
        ## _doWhat unmodified
        if [ -n "${OPTARG}" ] ; then
          userlistfilepath="${OPTARG}"
          if [ ! -f "${userlistfilepath}" ] ; then
            ErrExit ${EX_SOFTWARE} "EX_SOFTWARE ${IAM} '-f': ${userlistfilepath} does not exist"
            exit ${EX_SOFTWARE}
          fi
          prefix="${userlistfilepath} ${ARG_SEP} "
          shift
        else
          ErrExit ${EX_USAGE} "EX_USAGE ${IAM} '-f' requires an argument of <userlist-file-pathname>"
          exit ${EX_USAGE}
        fi
      ;;
    "T"|"t")
        _doWhat="SetTrace ${_doWhat}"
      ;;
    "v")
        # turn off verbosity
        _doWhat="${_doWhat/SetVerbose /}"
      ;;
    "V")
        # turn on verbosity
        _doWhat="SetVerbose ${_doWhat}"
      ;;
    *)
        printf "Usage: ${IAM} unknown argument\n" >&2
        exit ${EX_USAGE}
     ;;
    esac
  done
  shift $((OPTIND -1))
  if [ $# -gt 0 ] ; then
    suffix=" $@"
  fi
  echo "${prefix}${_doWhat}${suffix}"
  return
}

# @fn Do()
# @brief successively call functions in the arg list
#
Do() {
  local _s=""
  local rc=${EX_OK}

  for _s in $@
  do
    rc=$(type -t ${_s})
    if [ "${rc}" = "function" ] ; then
      ${_s}
    fi
  done
  Verbose ""
  return
}

# @fn main()
#
main() {
  local _vc=$(echo $(basename $(cd ${VC}; pwd)))
  local _f=""
  local rc=${EX_OK}
  local separg=""
  declare -A DoWhat
  local ul=""

  export ORIG_ARG0="${0}"
  export ORIG_ARGS="${*:-${DEFAULT_ARGS}}"
  DoWhat=$(ParseArgs ${ORIG_ARGS})
  rc=$?
  if [ "${rc}" -ne ${EX_OK} ] ; then
    ErrExit ${EX_SOFTWARE} "${IAM}: ParseArgs(): ${DoWhat} error rc:${rc}"
  fi

  SetFlags
  Rc ErrExit ${EX_OSFILE} "mkdir -p ${WORK_D}"
  trap "[ -d ${WORK_D} ] && chmod -R u+w ${WORK_D}; rm -rf ${WORK_D} >/dev/null 2>&1" 1 2 3 15

  # These are treated specially so that they take effect before any other functions
  # no matter where in the argument string that it was presented
  for _f in SetVerbose SetTrace
  do
    if [[ "${DoWhat}" =~ "${_f} " ]] ; then
      ${_f} ${_f,,/set//}
      DoWhat=${DoWhat%${_f} }
    fi
  done

  if [[ "${DoWhat[0]}" =~ "${ARG_SEP}" ]] ; then
    DoWhat=${DoWhat%${ARG_SEP} }
    DoWhat=${DoWhat%${USERLIST_FILE} }
    if [ -s "${DoWhat}" ] ; then
      USERLIST_FILE=${DoWhat}
    fi
  fi
  ul=""
  if [ -n "${USERLIST_FILE}" ] ; then
    ul=$(UserListFrom ${USERLIST_FILE})
    rc=$?
    if [ "${rc}" -ne ${EX_OK} ] ; then
      ErrExit ${EX_SOFTWARE} "${ul[*]}"
    fi
  fi
  export USERLIST="${ul[*]}"

  if [ -z "${USERLIST}" ] ; then
    local isatty=$(echo $(tty))
    ul=""
    if [ "${isatty}" != "not a tty" ] ; then
      echo " No user list file. Please enter user names, one per line, end with ^D:" >&2
    fi
    ul=$(UserListFrom /dev/stdin)
    rc=$?
    if [ "${rc}" -ne ${EX_OK} ] ; then
      ErrExit ${EX_SOFTWARE} "${ul[*]}"
    fi
    if [ -n "${ul}" ] ; then
      export USERLIST="${USERLIST} ${ul[*]}"
    fi
  fi

  EscalateAuthCheck
  case "${MODE}" in
  "cluster")
    DoWhat="${DoWhat} CheckTemplate CreateUserCfgTree AddUsersToThisHost AddUsersToSlurmDB"
    ;;
  "host")
    DoWhat="${DoWhat} ConstructNodeList AddUsersToNodes"
    ;;
  *)
    ErrExit ${EX_USAGE} "MODE:${MODE} unrecognized"
    ;;
  esac

  Do ${DoWhat}
  Rc ErrExit ${EX_OSFILE} "chmod -R u+w ${WORK_D}; rm -rf ${WORK_D} >/dev/null 2>&1"
  trap '' 0
  exit ${EX_OK}
}

main $@ || ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
