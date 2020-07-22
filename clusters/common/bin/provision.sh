#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/provision.sh

## This file contains the main driver for the provisioning functions and libraries.

HOSTNAME=$(hostname -s)
CLUSTERNAME=${HOSTNAME:0:2}
VC=${VC:-${CLUSTERNAME}}
BASEDIR=${VC:-vagrant}

## The following cannot be in a sub-function in order for source <___> to have global scope, ex. EX_OK, etc.
declare -x PROVISION_SRC_D=/${BASEDIR}/cfg/provision

declare -x PROVISION_SRC_LIB_D=${PROVISION_SRC_D}/lib
declare -x PROVISION_SRC_INC_D=${PROVISION_SRC_D}/inc
declare -x PROVISION_SRC_ENV_D=${PROVISION_SRC_D}/env

if [ -d ${PROVISION_SRC_INC_D} ] ; then
  declare -x SH_HEADERS=$(ls ${PROVISION_SRC_INC_D})
fi
if [ -d ${PROVISION_SRC_ENV_D} ] ; then
  declare -x SH_ENV=$(ls ${PROVISION_SRC_ENV_D})
fi
if [ -d ${PROVISION_SRC_LIB_D} ] ; then
  declare -x SH_LIBS=$(ls ${PROVISION_SRC_LIB_D})
fi

# EX_SOFTWARE and EX_OK are needed if initial loader linkage fails
declare -x EX_SOFTWARE=70
declare -x EX_OK=0

if [ ! -d /${BASEDIR} ] ; then
  if [ "${BASEDIR}" != vagrant ] ; then
    if [ -d /vagrant ] ; then
      ln -s /vagrant /${BASEDIR}
      export BASEDIR=vagrant
      export PROVISION_SRC_D=/${BASEDIR}/cfg/provision
      export PROVISION_SRC_LIB_D=${PROVISION_SRC_D}/lib
      export PROVISION_SRC_INC_D=${PROVISION_SRC_D}/inc
      export PROVISION_SRC_ENV_D=${PROVISION_SRC_D}/env
      export SH_HEADERS=$(ls ${PROVISION_SRC_INC_D})
      export SH_ENV=$(ls ${PROVISION_SRC_ENV_D})
      export SH_LIBS=$(ls ${PROVISION_SRC_LIB_D})
    fi
  fi
fi

flagfile="∕${BASEDIR}:\ NOT\ MOUNTED"
if [ ! -d /${BASEDIR} ] ; then
  echo " /${BASEDIR}: not a directory"
  exit ${EX_OK}
fi

flagfile="∕${BASEDIR}:\ NOT\ MOUNTED"
if [ -f "/${BASEDIR}/${flagfile}" ] ; then
  Verbose " already provisioned? ${VC}/${flagfile} exists"
  exit ${EX_OK}
fi

for _d in ${PROVISION_SRC_D} ${PROVISION_SRC_LIB_D} ${PROVISION_SRC_INC_D} ${PROVISION_SRC_ENV_D}
do
  if [ ! -d ${_d} ] ; then
    echo "$(basename ${0}): _d:${_d} is not a directory?"
    exit ${EX_SOFTWARE}
  fi
done

if [ \( -z "${SH_HEADERS}" \) -o \( -z "${SH_LIBS}" \) -o \( -z "${SH_ENV}" \) ] ; then
  echo -e "$(basename ${0}): broken linkage, empty SH_HEADERS:${SH_HEADERS}, SH_LIBS:${SH_LIBS}, SH_ENV:${SH_ENV}"
  exit ${EX_SOFTWARE}
fi

## @brief This defines the provisioning order of operations. In some cases, especially those requiring
## custom configuration, it may be appropriate to rearrange the provisioning order of operations.

# Order of functions called
# @todo future allow main option parsing to trigger which or an arbitrary selection of these to enable severable debuggability

# This structure allows us (eventually) to invoke each of these separately
# for debugging and/or unprovisioning.

declare -x CORE_ORDER_OF_OPERATIONS="SetFlags TimeStamp VerifyEnv SetupSecondDisk CopyHomeVagrant    \
                                     CopyCommon OverlayRootFS AppendFilesRootFS CreateNFSMountPoints \
                                     InstallEarlyRPMS ConfigureLocalRepos WaitForPrerequisites       \
                                     InstallRPMS BuildSW InstallLocalSW ConfigSW SetServices UserAdd \
                                     VerifySW UpdateRPMS MarkNodeProvisioned UserVerificationJobs    "

declare -x DEBUG_DEFAULT_ORDER_OF_OPERATIONS="DebugNote VerbosePWD ClearSELinuxEnforce ${CORE_ORDER_OF_OPERATIONS}"


declare -x NORMAL_ORDER_OF_OPERATIONS="${CORE_ORDER_OF_OPERATIONS} FlagSlashVagrant TimeStamp"

declare -a REPO_DISK_LIST=( '/dev/vdb' '/dev/sdb' )
declare -x REPO_DISK
declare -x REPO_PART
declare -x REPO_PART_NO=1

## yes, there's a bash one-liner to do this, but no, this may be more readable
if [ -n "${DEBUG}" ] ; then
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${DEBUG_DEFAULT_ORDER_OF_OPERATIONS}
else
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${NORMAL_ORDER_OF_OPERATIONS}
fi

## @fn WaitForPrerequisites()
##
WaitForPrerequisites() {
  local nodes
  local retries

  if [ ! -d "${REQUIREMENTS}" ] ; then
    return
  fi

  nodes=$(echo $(ls ${REQUIREMENTS}))
  for _n in ${nodes}
  do
    Verbose " ${_n}"
    local required=$(ls ${REQUIREMENTS}/${_n})
    local req_cmds=""
    for _l in ${required}
    do
      if [ -x "${REQUIREMENTS}/${_n}/${_l}" ] ; then
        req_cmds="${req_cmds} ${_l}"
      fi
    done
    for _l in ${req_cmds}
    do
      local tstamp=`date +%Y.%m.%d.%H:%M`
      declare -i retries
      local rc
      local _e
      workdir=${REQUIREMENTS}/${_n}
      exe=${REQUIREMENTS}/${_n}/${_l}
      out=${TMP}/req.${_l}.${tstamp}.out
      _e=$(basename ${exe})
      Verbose "  ${_e} "
      retries=0
      rc=${EX_TEMPFAIL}
      local pwd=$(pwd)
      until (( ${retries} > ${REQUIREMENT_RETRY_LIMIT} )) || (( ${EX_OK} == ${rc} ))
      do
        cd ${workdir} || ErrExit ${EX_OSERR} "cd ${workdir}"
        ${exe} ${out} "${retries}/${REQUIREMENT_RETRY_LIMIT}"
        rc=$?
        (( ++retries ))
        sleep ${REQUIREMENT_RETRY_SLEEP}
      done
      cd ${pwd} || ErrExit ${EX_OSERR} "cd ${pwd}"
      if [ ${rc} -ne 0 ] ; then
        if [ -n "${HALT_PREREQ_ERROR}" ] ; then
          shutdown -h -P --no-wall +0
        fi
        ErrExit ${EX_OSFILE} "Node ${_n} failed ${_l}, retries=${retries}, rc=${rc}.   Connectivity or firewall issue between ${_n} and ${HOSTNAME}?"
      fi
    done
  done
  return
}

## @fn DebugNote()
##
DebugNote() {
  Verbose "DEBUG "
  return
}

## @fn VerbosePWD()
##
VerbosePWD() {
  Verbose "${ORIGPWD} "
  return
}

## @fn GetOSVersion()
## Collect OS release tags and normalize to RHEL or SLES
## @param /etc/os-release/
## @return void
## \callgraph
## \callergraph
##
GetOSVersion() {
  local f

  for f in /etc/os-release-upstream /etc/os-release  /etc/system-release
  do
    if [ ! -r ${f} ] ; then
      continue
    fi
    if [ -n "${OS_VERSION}" ] ; then
      echo "${OS_VERSION}"
      return
    fi

    local v
    v=$(grep -E '^ID=' ${f} | sed 's/ID=//' | sed 's/"//g')
    case "${v}" in
      rhel|"Red Hat Enterprise Linux"*|RHEL|centos|CentOS) echo "rhel" ; return  ;;
      sles|"SUSE Linux Enterprise Server"*|SLES)           echo "sles" ; return  ;;
      *) continue ;;
    esac
  done
  return
}


## Required commands for a given environment @see VerifyEnv()
declare -A RequiredCommands
# @todo build this via introspection of ourselves
# [base] linux-distribution independent required commands
RequiredCommands[base]="awk base64 basename cat dirname echo fmt grep head hostname logger ls mkdir pkill poweroff printf ps pwd rm su sed setsid stat strings stty sum tail tar test timeout"
# [cray] Cray-specific required commands
RequiredCommands[cray]=""
# [rhel] RHEL or RHEL-alike (TOSS, CentOS, &c) required commands
RequiredCommands[rhel]=""
# [sles] SuSe required commands
RequiredCommands[sles]=""
# [slurm] Slurm dependencies - all distributions
RequiredCommands[slurm]="sacct sacctmgr scontrol sdiag sinfo sprio squeue sshare"

## @fn VerifyEnv()
## verifies that the command environment appears sane (path, etc)
## @return if sane, otherwise calls ErrExit
## \callgraph
## \callergraph
##
VerifyEnv() {
  local o
  local os=""
  local ocray=""
  local require_uid=0
  local running_uid

  ORIGPWD=$(pwd)
  os=$(GetOSVersion)

  running_uid=$(id -u)
  if [ ${require_uid} -ne ${running_uid} ] ; then
    ErrExit ${EX_NOPERM} "Insufficient permissions"
  fi

  #
  if [ "${os}" = "sles" ] ; then
    ocray="cray"
    ## CRAY_PATH for jdetach and pdsh, respectively
    export PATH=${CRAY_PATH}:${PATH}
  fi

  for o in base ${os} ${ocray}
  do
    local r
    for r in ${RequiredCommands["${o}"]}
    do
      local c
      local f
      for c in ${r}
      do
        f=$(which ${c})
        #f=$(command -v ${c}) ## @todo use bashism rather than (deprecated) which
        if [ ! -x "${f}" ] ; then
          ErrExit ${EX_SOFTWARE} "${c}: ${f} is not executable"
        fi
      done
    done
  done

  if [ -z "${PGID}" ] ; then
    export PGID=$(($(ps -o pgid= -p "$$")))
    if [ -z "${PGID}" ] ; then
      ErrExit ${EX_SOFTWARE} "empty PGID"
    fi
  fi
  IsLANL

  if [ -z "${VC}" ] ; then
    ErrExit ${EX_SOFTWARE} "VC empty"
  fi
  if [ ! -d "${VC}" ] ; then
    ErrExit ${EX_SOFTWARE} "VC:${VC} not a directory"
  fi
  local flagfile="∕${BASEDIR}:\ NOT\ MOUNTED"
  if [ -f "${VC}/${flagfile}" ] ; then
    Verbose " already provisioned? ${VC}/${flagfile} exists"
    exit ${EX_OK}
  fi

  ## This node has been restarted from a poweroff after a full provisioning?
  local vagrant_mount=$(echo $(mount | grep "/${BASEDIR}"))
  local vagrant_mount_fstyp=$(echo ${vagrant_mount} | awk '{print $5}')
  local vagrant_mount_opts=$(echo ${vagrant_mount} | awk '{print $6}' | sed 's/,/ /g' | sed 's/(//' | sed 's/)//')

  if [ "${vagrant_mount_fstyp}" = "vboxsf" ] ; then
    local _o
    local ro_mount=""
    for _o in ${vagrant_mount_opts}
    do
      if [ "${_o}" = "ro" ] ; then
        ro_mount="true"
      fi
    done
    if [ -n "${ro_mount}" ] ; then
      if [ -f ${STATE_PROVISIONED}/${HOSTNAME} ] ; then
	      if [ -f ${STATE_POWEROFF}/${HOSTNAME} ] ; then
          Verbose " poweroff resumption;"
        fi
        Verbose " provisioned"
        exit ${EX_OK}
      fi
    fi
  fi

  for d in ${STATE_D} ${STATE_NONEXISTENT} ${STATE_POWEROFF} ${STATE_RUNNING} ${STATE_PROVISIONED}
  do
    Rc ErrExit ${EX_SOFTWARE} "mkdir -p ${d}"
  done

  ClearNodeState all
  MarkNodeState "${STATE_RUNNING}"

  return ${EX_OK}
}

## @fn ClearNodeState()
##
ClearNodeState() {
  local scope=${1:-_all_}

  if [ -z "${HOSTNAME}" ] ; then
    ErrExit ${EX_SOFTWARE} "HOSTNAME empty"
  fi
  if [ "${scope}" = "_all_" -o "${scope}" = "all" ] ; then
     local _d
     for _d in ${STATE_NONEXISTENT} ${STATE_POWEROFF} ${STATE_RUNNING} ${STATE_PROVISIONED}
     do
       ClearNodeState ${_d}
     done
  else
     Rc ErrExit ${EX_SOFTWARE} "rm -f ${scope}/${HOSTNAME}"
  fi
  return
}

## @fn MarkNodeState()
##
MarkNodeState() {
  local new_state=${1:-_unknown_node_state}

  if [ ! -d "${new_state}" ] ; then
    ErrExit ${EX_SOFTWARE} "new_state: ${new_state} not directory"
  fi
 
  Rc ErrExit ${EX_SOFTWARE} "touch ${new_state}/${HOSTNAME}"
  return
}

## @fn MarkNodeProvisioned()
## not atomic, but the running->provisioned transition is failure prone, so
## consumers expect that both may exist and know to honor PROVISIONED over RUNNING
##
MarkNodeProvisioned() {
  MarkNodeState "${STATE_PROVISIONED}"
  ClearNodeState "${STATE_RUNNING}"
  Rc ErrExit ${EX_OSFILE} "mount -o remount,async,relatime /"
  return
}

## @fn isRoot()
##
isRoot() {
  id=$(id -u)
  if [ 0 -ne "${id}" ] ; then
    ErrExit ${EX_NOPERM} "insufficient privilege"
  fi
  return
}

## @fn ConfigureLocalRepos()
##
ConfigureLocalRepos() {
  local createrepo=$(which createrepo 2>&1)
  local reposync=$(which reposync 2>&1)
  local rsync=$(which rsync 2>&1)
  local repos_size
  local numeric="^[0-9]+$"
  local _ingested_tarball=""
  local _ingested_tarball_flagfile="${COMMON}/repos/._ingested_tarball"
  local _have_repos=""

  for tb in ${XFR}/repos ${XFR}/repos.tar ${XFR}/repos.tgz
  do
    for op in "! -r" "! -s" "-L"
    do
      if [ ${op} "${tb}" ] ; then
        Verbose " skipped: ${tb} ${op}"
        continue
      fi
    done

    _have_repos=${tb}
    break
  done

  if [ -z "${_have_repos}" ] ; then
      Verbose "  cannot find XFR=${XFR} repos tarball or directory: ONLY_REMOTE_REPOS=true"
      export ONLY_REMOTE_REPOS="true"
      return
  fi

  repos_size=$(du -x -s -m ${_have_repos} 2>&1 | awk '{print $1}')
  if ! [[ ${repos_size} =~ ${numeric} ]] ; then
    ErrExit ${EX_CONFIG} "ingest repository is corrupt or empty: ${repos_size}"
  fi
  if [ ${repos_size} -lt 32 ] ; then
    ErrExit ${EX_CONFIG} "repos directory size is unrealistically low (${repos_size})"
  fi

  if [ -n "${ONLY_REMOTE_REPOS}" ] ; then
    return
  fi

  # only copy the repos area into this VM if we appear to be the one with repo-related tools installed
  ## XXX key on actual per-host attribute
  [ ! -x "${createrepo}" ] && return
  [ ! -x "${reposync}" ]   && return
  [ ! -x "${rsync}" ]      && return
  [ -z "${REPO_MOUNT}" ]   && return
  [ ! -b "${REPO_DISK}" ]  && return 
  [ ! -b "${REPO_PART}" ]  && return 

  Rc ErrExit ${EX_OSERR}  "mkdir -p ${REPO_MOUNT} 2>&1"
  Rc ErrExit ${EX_OSERR}  "mount ${REPO_MOUNT}    2>&1"

  declare -x CREATEREPO_CACHE=/run/createrepo/cache
  Rc ErrExit ${EX_OSERR}  "mkdir -p ${CREATEREPO_CACHE}  2>&1"

  ## XXX collect an attribute of the host from somewhere? yes, we have it in slurm.conf, but that's not (really) available yet
  houses_storage="fs$"
  if ! [[ ${HOSTNAME} =~ ${houses_storage} ]] ; then
    Verbose " HOSTNAME:${HOSTNAME} does not appear to house the repository directly, would skip repo update"
    ## return
  fi


  ## XXX where, externally, to read from -- and know that it is authoritative?
  local _enabled=""

  _enabled=$(echo $(timeout ${YUM_TIMEOUT_EARLY} ${YUM} --disablerepo=epel repoinfo local-base | grep 'Repo-status' | sed 's/Repo-status.*://'))
  if ! [[ ${_enabled} =~ *enabled* ]] ; then
    if [ ! -f ${_ingested_tarball_flagfile} ] ; then
      repos_size=$(expr ${repos_size} / 1024)
      Verbose " ingesting: ${_have_repos} ${repos_size}Gb "
      ## XXX nice to put out a progress bar but the way vagrant parses the output, a dot appears on separate lines, XXX send stderr via stdbuf?
      ## XXX Rc ErrExit ${EX_OSFILE} "cd ${COMMON}; tar -${TAR_DEBUG_ARGS}${TAR_ARGS}f ${XFR}/repos.tgz --exclude='._*' --checkpoint-action=dot --checkpoint=4096"

      if [ -d ${_have_repos} ] ; then
        # XXX choose a copy algorithm based on config flags
        # rsync is ~50% slower than tar or cp
        # Rc ErrExit ${EX_OSFILE} "rsync -az ${_have_repos} ${COMMON}"
        # - OR -
        # cp is less reliable than the other two, but equivalent in speed to tar
        # Rc ErrExit ${EX_OSFILE} " cp -arx --preserve=all ${_have_repos} ${COMMON}"
        # - OR -
        # use a tar ball & then extract
        Rc ErrExit ${EX_OSFILE} "tar -cf - -C ${_have_repos} . | \
                                  (cd ${COMMON}/repos ; tar -${TAR_DEBUG_ARGS}${TAR_ARGS}f - --exclude='._*')"
      else
        Rc ErrExit ${EX_OSFILE} "cd ${COMMON}; tar -${TAR_DEBUG_ARGS}${TAR_ARGS}f ${_have_repos} --exclude='._*'"
      fi
      _ingested_tarball=true
      Rc ErrExit ${EX_OSFILE} "touch ${_ingested_tarball_flagfile}"
    fi

    if [ -r ${YUM_REPOS_D}/${YUM_CENTOS_REPO_LOCAL} ] ; then
      Verbose " + ${YUM_CENTOS_REPO_LOCAL} "
      Rc ErrExit ${EX_OSFILE} "sed -i~ -e /^enabled=0/s/=0/=1/ ${YUM_REPOS_D}/${YUM_CENTOS_REPO_LOCAL}"
      for r in $(grep baseurl ${YUM_REPOS_D}/${YUM_CENTOS_REPO_LOCAL} | sed 's/^#.*//' | sed 's/baseurl=file:\/\///')
      do
        # @todo #workers from node attributes
        if [ ! -d ${r}/repodata ] ; then
          Rc ErrExit ${EX_CONFIG} "export basearch=${ARCH} releasever=${YUM_CENTOS_RELEASEVER} ; createrepo --workers 4 --cachedir ${CREATEREPO_CACHE} ${r}"
        fi
      done
    fi

    if [ -r ${YUM_REPOS_D}/${YUM_CENTOS_REPO_REMOTE} ] ; then
      Verbose " - ${YUM_CENTOS_REPO_REMOTE} "
      Rc ErrExit ${EX_OSFILE} "sed -i~ -e /^enabled=1/s/=1/=0/ ${YUM_REPOS_D}/${YUM_CENTOS_REPO_REMOTE}"
    fi

    size=$(du -x -s -m ${VC_COMMON}/repos | awk 'BEGIN {total=0} {total += $1} END {print total}')
    if [ "${size}" -ne 0 ] ; then
      Verbose "   ${VC_COMMON}/repos => ${COMMON}/repos ${size}Mb "
      Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${VC_COMMON} repos | \
                              (cd ${COMMON}; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
    fi
  fi

  if [ -z "${RSYNC_CENTOS_REPO}" ] ; then
    return
  fi

  for r in os updates
  do
    local repo_url=""
    local suffix=centos/7/${r}/${ARCH}
    d=${REPOS}/${suffix}

    if [ ! -d "${d}" ] ; then
      ErrExit ${EX_OSFILE} "${d} not a directory"
    fi

    case "${PREFERRED_REPO}" in
      "rsync://"*|"http://"*|"https://"*)
          repo_url=${PREFERRED_REPO}
          ;;
      *)
          local how_many_repo=${#CENTOS_RSYNC_REPO_URL[@]}
          local rand_repo=$(( ( $RANDOM % ${how_many_repo} ) + 1 ))
          repo_url=${CENTOS_RSYNC_REPO_URL[${rand_repo}]}
      ;;
    esac

    ### XXX could replace the following with reposync to not be dependent on a repository guaranteeing the rsync protocol
    ### >>> The following can be time consuming, especially if the network connection to CENTOS_RSYNC REPO_URL is slow.
    if [ -n "${repo_url}" ] ; then 
      Verbose "   ${repo_url} ${d} "
      declare -i retries=0
      rc=0 
      local _timeout=${RSYNC_TIMEOUT}
      while [ ${retries} -le ${RSYNC_RETRY_LIMIT} -a ${rc} -ne 0 ]
      do
        timeout ${RSYNC_TIMEOUT_DRYRUN} rsync --dry-run -4 -az --delete --exclude='repo*' ${repo_url}/${suffix}/ ${d} >/dev/null 2>&1
        rc=$?
        if [ "${repo_url}" != ${DEFAULT_PREFERRED_REPO} ] ; then
          if [ ${rc} -ne ${EX_OK} ] ; then
            repo_url=${DEFAULT_PREFERRED_REPO}
          fi
        # XXX else pick another repo
        fi
        (( ++retries ))
        _timeout=$(expr ${_timeout} \* retries)
        timeout ${_timeout} rsync -4 -az --delete --exclude='repo*' --exclude='._*' ${repo_url}/${suffix}/ ${d}/ >/dev/null 2>&1
        rc=$?
      done
    fi
  done

  for r in os updates local
  do
    if [ -z "${ARCH}" ] ; then
      ErrExit ${EX_OSERR} "empty ARCH"
    fi
    local suffix=centos/7/${r}/${ARCH}
    d=${REPOS}/${suffix}
    if [ ! -d ${d} ] ; then
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${d}"
    fi
    Rc ErrExit ${EX_OSERR} "${createrepo} --update --workers 4 --cachedir ${CREATEREPO_CACHE} ${d}"
  done
  return
}

## @fn CopyCommon()
##
CopyCommon() {
  local size
  local from=/${CLUSTERNAME}/common
  local to=/home${from}

  if [ -L "${VC}" ] ; then
    ErrExit ${EX_OSFILE} "${VC}: symlink"
  fi
  if [ -L "${to}" ] ; then
    Verbose "  to:${to}: symlink, skipped"
  fi
  size=$(du -x -s -m ${from} --exclude=repos\* | awk 'BEGIN {total=0} {total += $1} END {print total}')
  Verbose " ${size}Mb  ${from} => ${to}"

  Rc ErrExit ${EX_OSFILE} "mkdir -p ${to}"
  Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${from} . | \
                              (cd ${to}; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
  # prevent easy errors such as accidental modification of the transient in-cluster fs
  Rc ErrExit ${EX_OSFILE} "chmod -R ugo-w ${to}/provision"
  if [ -L "${to}/home" ] ; then
    Verbose "  ${to}/home: symlink, skipped"
  else
    Rc ErrExit ${EX_OSFILE} "chmod ugo-w ${to}/home"
  fi

  return
}

## @fn SetupSecondDisk()
##
SetupSecondDisk() {

  export REPO_MOUNT=${COMMON}/repos
  export REPO_LOCAL=${REPO_MOUNT}/local

  # Sensibly skip these: so, if we don't have a 2nd disk, but could otherwise proceed, continue
  for dsk in ${REPO_DISK_LIST[@]}
  do
    if [ ! -b "${dsk}" ] ; then
      continue
    fi
    REPO_DISK=${dsk}
    REPO_PART=${dsk}${REPO_PART_NO}
    break
  done

  if [ -z "${REPO_DISK}" ] ; then
    return
  fi

  if [ ! -b "${REPO_PART}" ] ; then
    Rc ErrExit ${EX_CONFIG} "yes | parted ${REPO_DISK} --align opt mklabel gpt 2>&1"
    Rc ErrExit ${EX_CONFIG} "yes | parted ${REPO_DISK} mkpart primary 2048s 16G 2>&1"
  fi
  Rc ErrExit ${EX_CONFIG} "mkfs.xfs -f -L repos ${REPO_PART} 2>&1"
  Rc ErrExit ${EX_CONFIG} "xfs_repair ${REPO_PART} 2>&1"
  echo "${REPO_PART}  ${COMMON}/repos  xfs rw,defaults,noatime,async,nobarrier 0 0" >> /etc/fstab
  Verbose " ${REPO_PART} ${REPO_MOUNT}"
  return
}

## @fn CopyHomeVagrant()
##
CopyHomeVagrant() {
  local size
  local msg

  # These clusters are *transient*. All data can be reproduced, replayed, regenerated with reprovisioning.
  Rc ErrExit ${EX_OSFILE} "mount -o remount,async,noatime,nobarrier /"

  Rc ErrExit ${EX_OSFILE} "sysctl -w fs.xfs.xfssyncd_centisecs=720000"
  Rc ErrExit ${EX_OSFILE} "sysctl -w fs.xfs.age_buffer_centisecs=3600"
  Rc ErrExit ${EX_OSFILE} "sysctl -w fs.xfs.filestream_centisecs=7200"
  Rc ErrExit ${EX_OSFILE} "sysctl -w fs.xfs.xfsbufd_centisecs=1800"

  if [ -L "${VC}" ] ; then
    ErrExit ${EX_OSFILE} "${VC} is a symlink"
  fi

  if [ -L "${COMMON}" ] ; then
   Verbose: " COMMON:${COMMON} symlink, skipped"
   return
  fi

  if [ ! -f ${HOMEVAGRANT}/HOME\ VAGRANT ] ; then
    if [ ! -d "${HOMEVAGRANT}" ] ; then
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${HOMEVAGRANT}"
    fi
    size=$(du -x -s -m ${VC}/* --exclude=common/repos --exclude='repos.tgz*' --exclude=repos --exclude='*.vdi' | \
				awk 'BEGIN {total=0} {total += $1} END {print total}')
    Verbose " ${size}Mb "
    Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${VC} \
       --one-file-system --exclude='common/repos' --exclude='repos.tgz*' --exclude='*.vdi' --exclude=repos --exclude='*.iso' --exclude='._*' . | (cd ${HOMEVAGRANT}; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
    Rc ErrExit ${EX_OSFILE} "touch ${HOMEVAGRANT}/HOME\ VAGRANT; chmod 0 ${HOMEVAGRANT}/HOME\ VAGRANT"
  fi

  dirs=$(echo $(ls ${COMMON}) | grep -v ":∕home∕vagrant∕common")
  for d in ${dirs}
  do
    if [ -L "${COMMON}/${d}" ] ; then
      Verbose "${COMMON}/${d}: symlink, skipped"
      continue
    fi
    if [ ! -d "${COMMON}/${d}" ] ; then
      ErrExit ${EX_OSFILE} "${COMMON}/${d} is not a directory"
    fi
  done
  Rc ErrExit ${EX_OSFILE} "chown root:root ${COMMON}/tmp"
  Rc ErrExit ${EX_OSFILE} "chmod 1777 ${COMMON}/tmp"

  if [ -f ${COMMON}/etc/hosts.allow ] ; then
    Rc ErrExit ${EX_OSFILE} "chown root:root ${COMMON}/etc/hosts.allow"
  fi
  return
}

## @fn LinkSlashVagrant()
## @note unused, but possibly useful in the future
##
LinkSlashVagrant() {
  if [ -d "${VC}" -a ! -L "${VC}" ] ; then
    Rc ErrExit ${EX_SOFTWARE} "cd /; umount -f ${VC}; rmdir ${VC}; ln -s ${HOMEVAGRANT}"
  fi
  return
}


## @fn FlagSlashVagrant()
##
FlagSlashVagrant() {

  if [ -n "${PREVENT_SLASHVAGRANT_MOUNT}" ] ; then
    local opwd=$(pwd)
    local flagfile="∕${BASEDIR}:\ NOT\ MOUNTED"
    cd /
    # 32 = (u)mount failed
    # only touch the flagfile if we haven't unmounted /${BASEDIR} ("/vagrant")
    awk '{print $5}' < /proc/self/mountinfo | egrep -s "${VC}|${BASEDIR}" >/dev/null 2>&1
    fstype=$(stat -f --format "%T" ${BASEDIR})
    if [ $? -eq ${GREP_FOUND} ] ; then
      still_in_use=$(lsof | grep -i cwd | awk '{print $9}' | grep '/' | sort | uniq | egrep "^/${BASEDIR}")
      needs_umount=$(findmnt -m | egrep '192.168.56.1|vboxsf' | awk '{print $1}' | sort -r)
      if [ -n "${still_in_use}" ] ; then
        Verbose " /${BASEDIR} is still in use. (${still_in_use})"
        Verbose " umount skipped."
      else
        any_failed_unmounts=""
        for m in ${needs_umount}
        do
          umount -f ${m} >/dev/null 2>&1
          rc=$? 
          if [ ${rc} -ne ${EX_OK} ] ; then
            any_failed_unmounts="${any_failed_unmounts} ${m}"
          fi
          if [ -z "${any_failed_unmounts}" ] ; then
            if [ "${fstype}" != "nfs" -a "${fstype}" != "vboxsf" ] ; then 
              Rc ErrExit ${EX_OSFILE} "cd ${VC}; touch ${flagfile}; chmod 0 ${flagfile}"
            fi
          fi
        done
      fi
    else
      if [ "${fstype}" != "nfs" -a "${fstype}" != "vboxsf" ] ; then 
        Rc ErrExit ${EX_OSFILE} "cd ${VC}; touch ${flagfile}; chmod 0 ${flagfile}"
      fi
    fi
    cd ${opwd}
  else
    if [ -d "${VC}" -a ! -L "${VC}" ] ; then
      Rc ErrExit ${EX_OSFILE} "mount -r -t ${fstype} vagrant ${VC}"
    fi
  fi
  # convenient short-cuts inside the cluster
  if [ ! -L /cfg ] ; then
    Rc ErrExit ${EX_OSFILE} "ln -s ${CFG_HOMEVAGRANT} /cfg"
  fi
  if [ ! -L /common ] ; then
    Rc ErrExit ${EX_OSFILE} "ln -s ${COMMON} /common"
  fi

  # some mounts are not needed post configuration
  # XXX @todo add a per-node cfg file list of umounts, as needed
  for m in ${BUILDWHERE} ${BUILDWHERE/vagrant/${VC}}
  do
    local mountpoint=$(which mountpoint)
    rc=${EX_OK}
    if [ -x "${mountpoint}" ] ; then
      ${mountpoint} ${m} >/dev/null 2>&1
      rc=$?
    fi
    if [ ${rc} -eq ${EX_OK} ] ; then
      umount -f ${m} >/dev/null 2>&1
    fi
  done

  local mem=$(expr $(grep -i MemTotal /proc/meminfo  | awk '{print $2}') / 1024)
  local procs=$(grep -i processor /proc/cpuinfo | wc -l)
  Verbose " mem:${mem}Mb procs:${procs}"
  Verbose " provisioned."
  return
}


## @fn OverlayRootFS()
##
OverlayRootFS() {
  local _src
  if [ ! -d "${ROOTFS}" ] ; then
    ErrExit ${EX_CONFIG} "${ROOTFS}: No such directory"
  fi
  _src="${ROOTFS//\/${BASEDIR}\/}"
  Verbose " source: ${_src//cfg\/provision\/..\/..\//}"
  Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${ROOTFS} . | \
	                           (cd /; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
  return
}

## @fn AppendFilesRootFS()
##
AppendFilesRootFS() {
  local _fs=$(find ${ROOTFS} -name *.append | sort -di)
  local _f

  for _f in ${_fs}
  do
    local _base=$(basename ${_f} | sed 's/\.*[0-9]*.append$//')
    if [ ! -f "${_f}" ] ; then
      ErrExit ${EX_CONFIG} "append(_base:${_base}} _f:${_f} No such file"
    fi
    for _n in ${_base}
    do
      local _appendifcommand=$(grep appendifcommand: ${_f} | sed 's/appendifcommand: //')
      local _appendwhere=$(grep appendwhere: ${_f} | sed 's/appendwhere: //')
      local _appendwhat=$(grep appendwhat: ${_f} | sed 's/appendwhat: //')
      local _dir=$(dirname ${_f} | sed "s:\/${BASEDIR}\/common::")
      local _target=$(echo ${_dir} | sed 's/^.*rootfs//')/${_base}
      local _rc

      if [ ! -f ${_target} ] ; then
        ErrExit ${EX_SOFTWARE} "append($_base) _target:${_target} does not exist"
      fi 

      if [ -n "${_appendifcommand}" ] ; then
        local rc
        eval ${_appendifcommand} >/dev/null 2>&1
        rc=$?
        if [ ${rc} -ne ${EX_OK} ] ; then
          continue
        fi
      fi

      grep -s "${_appendwhat}" ${_target} >/dev/null 2>&1
      local _rc=$?
      if [ ${GREP_NOTFOUND} -eq ${_rc} ] ; then
        local _hint=$(echo ${_appendwhat} | awk '{print $1}')
        Verbose "  ${_n} ${_hint}"

        sed -i "/${_appendwhere}/a ${_appendwhat}" ${_target} >/dev/null 2>&1
        _rc=$?
        if [ 0 -ne ${_rc} ] ; then
          ErrExit ${EX_SOFTWARE} "append($_base) sed failure: sed -i \"\/${_appendwhere}/a ${_appendwhat}\" ${_target}"
        fi
      fi
    done
  done
  return
}

## @fn CreateNFSMountPoints()
##
CreateNFSMountPoints() {
  local _dev
  local _mnt
  local _fstyp
  local _options
  local _check
  local _dump

  while read _dev _mnt _fstyp _options _check _dump
  do
    if [[ ${_def} =~ ^# ]] ; then
      continue
    fi
    if [[ ${_fstyp} =~ nfs ]] ; then
      if [ ! -d ${_mnt} -a ! -L ${_mnt} ] ; then
        Verbose "  ${_mnt}"
        Rc ErrExit ${EX_OSFILE} "mkdir -p ${_mnt}"
      fi
    fi
  done < /etc/fstab
  return
}

## @fn InstallRPMS()
##
InstallRPMS() {
  local early=${1:-"_not_early_rpms_"}
  local which
  local timeout
  local rpms_add
  local _rpms_add
  local _r
  local _disable_localrepo_arg_
  local _need_clean

  case "${1}" in
  install|"")
	    which=install
  	  timeout=${YUM_TIMEOUT_INSTALL}

      # may require this for CentOS if encountering "yum interrupted by user cancel"
      # https://forums.centos.org/viewtopic.php?t=47372
      # https://bugzilla.redhat.com/show_bug.cgi?id=1091740
      # https://bugzilla.redhat.com/show_bug.cgi?id=1099101
      if [ -f /etc/os-release ] ; then
        local centos
        centos=$(grep '^ID=' /etc/os-release | sed 's/^ID=//' | sed 's/"//g')
        if [ "${centos}" = "centos" ] ; then
          Verbose "  (CentOS bug#1099101) would force SKIP_YUMDOWNLOAD to be clear"
          # extremely high cost (in time) to do this; temporary fix is to force latest python-urlgrabber
          # into early RPMS
          # SKIP_YUMDOWNLOAD=""
          _need_clean=true
        fi
      fi

	    ;;
  early)
    	    which=early
    	    timeout=${YUM_TIMEOUT_EARLY}
          if [ -n "${YUM_LOCALREPO_DEF}" -a -n "${LOCAL_REPO_ID}" ] ; then
            if [ -f ${YUM_LOCALREPO_DEF} ] ; then
              _disable_localrepo_arg=" --disablerepo=${LOCAL_REPO_ID},local-base "
            fi
          fi
	    ;;
  local)
	    which=local
    	    timeout=${YUM_TIMEOUT_BASE}
	    ;;
  _not_early_rpms_)
	    ErrExit ${EX_SOFTWARE} "_not_early_rpms_"
	    ;;
  *)
	    ErrExit ${EX_SOFTWARE} "${1}"
	    ;;
  esac

  if [ -n "${_need_clean}" ] ; then
    Verbose "    yum -y clean metadata"
    Rc ErrExit ${EX_SOFTWARE} "yum -y clean metadata"
  fi
  ## collect list of rpms. This list may either be a string subset of rpm names, or actual rpms
  ## If it appears to be an actual RPM, we will attempt to localinstall it rather than reach out to a remote repo
  rpms_add=$(echo $(ls ${RPM}/${which} | grep -v README))
  _rpms_add=""
  _rpms_localinstall=""
  _rpms_msg=""
  for _r in ${rpms_add}
  do
    local nm=${_r//-[0-9].*/}
    _rpms_msg="${_rpms_msg} ${nm}"
    # if this appears to be an actual RPM, then do a localinstall
    if [[ ${_r} = *.rpm ]] ; then
      _rpms_localinstall="${_rpms_localinstall} ./${_r}"
      #XXX _rpms_localinstall="${_rpms_localinstall} \"./${_r}\"" -- if RPM contains a shell meaningful character like parentheses in perl rpms
    else
      _rpms_add="${_rpms_add} ${_r}"
    fi
  done

  Verbose "${_rpms_msg}"

  rpms_add=${_rpms_add}
  localinstall_add=${_rpms_localinstall}
  ## Attempt to do a bulk installation.
  ## @todo If that fails, proceed with each one singly to capture the failure.
  if [ -n "${localinstall_add}" ] ; then
    Rc Warn ${EX_IOERR} "cd ${RPM}/${which}; \
                              timeout ${timeout} ${YUM} ${_disable_localrepo_arg} --disableplugin=fastestmirror -y localinstall ${localinstall_add}"
    rc=$?
    if [ "${rc}" -ne ${EX_OK} ] ; then
      Verbose "  fallback from bulk install to individual rpms: "
      Verbose "  ${localinstall_add}"
      for _r in ${localinstall_add}
      do
        Rc Warn ${EX_IOERR} "timeout ${timeout} ${YUM} --disableplugin=fastestmirror -y update-minimal" 
        Rc Warn ${EX_IOERR} "cd ${RPM}/${which}; timeout ${timeout} ${YUM} --disableplugin=fastestmirror -y install ${_r}" 
        rc=$?
        if [ "${rc}" -ne ${EX_OK} ] ; then
          rpms_add="${rpms_add} ${_r}"
        fi
      done
    fi
  fi

  ## for rpms that are not local, possibly download them for future iterations
  for r in ${rpms_add}
  do
    if [ -n "${SKIP_YUMDOWNLOAD}" ] ; then
      continue
    fi
    if [ -n "${_need_clean}" ] ; then
      Verbose "  yum -y clean metadata && yum -y upgrade"
      Rc ErrExit ${EX_SOFTWARE} "yum -y clean metadata && yum -y upgrade"
    fi
    if [ -x $(which yumdownloader) ] ; then
      Rc ErrExit ${EX_IOERR} "timeout ${timeout} yumdownloader --resolve --destdir=${RPM}/${which} --archlist=${ARCH} \"${r}\" ; "
    else
      ## change the downloaddir to the local repo (${COMMON}/repos) rather than remain in the configuration tree
      Rc ErrExit ${EX_IOERR} "timeout ${timeout} ${YUM} ${_disable_localrepo_arg} --downloadonly --downloaddir=${RPM}/${which} --disableplugin=fastestmirror install \"${r}\" ; "
    fi
    Rc ErrExit ${EX_IOERR} "rm -f ${RPM}/${which}/\"${r}\" ; "
  done

  if [ -n "${rpms_add}" ] ; then
    declare -i retries
    local rc
    retries=0
    rc=${EX_TEMPFAIL}
    while [ ${retries} -lt ${YUM_RETRY_LIMIT} -a ${rc} -ne ${EX_OK} ]
    do
      local _which_repos
      cd ${RPM}/${which}
      ## if the local repos.tgz appears recent, "--disablerepo=\*", otherwise... 
      _which_repos=""
      if [ -z "${_disable_localrepo_arg}" -a -f "${YUM_LOCALREPO_DEF}" -a -n "${LOCAL_REPO_ID}" ] ; then
        #_which_repos="--disablerepo=\* --enablerepo=local-base,local-base-updates,${LOCAL_REPO_ID}"
        _which_repos="--enablerepo=local-base,local-base-updates,${LOCAL_REPO_ID}"
      else
        #_which_repos="--disablerepo=\* --enablerepo=local-base,local-base-updates"
        _which_repos="--enablerepo=local-base,local-base-updates"
      fi
      if [ "${retries}" -ne 0 -a "${which}" != "early" ] ; then
        _which_repos=""
      fi
      timeout ${timeout} ${YUM} --disableplugin=fastestmirror ${_which_repos} -y install ${rpms_add}
      rc=$?
      (( ++retries ))
    done
  fi
  return
}

## @fn InstallEarlyRPMS()
##
InstallEarlyRPMS() {
  InstallRPMS early $@
  return
}

## UserAdd()
##
UserAdd() {
  local ETC_DEFAULT_USERADD=/etc/default/useradd

  if [ ! -d ${USERADD} ] ; then
    ErrExit ${EX_CONFIG} "${USERADD} No such file or directory"
  fi
  cd ${USERADD} || ErrExit ${EX_OSERR} "cd ${USERADD}"
  local users_add=$(echo $(ls ${USERADD}))
  local u

  if [ -f ${ETC_DEFAULT_USERADD} ] ; then
    ## XXX sed-fu
    sed -i~ -e "/HOME=\/home/d"  ${ETC_DEFAULT_USERADD}
    sed -i~ -e "/INACTIVE=-1/i\
HOME=${HOME_BASEDIR}" ${ETC_DEFAULT_USERADD}
    if [ $? -ne ${EX_OK} ] ; then
      ErrExit ${EX_SOFTWARE} "sed /INACTIVE=-1/i => HOME=${HOME_BASEDIR}"
    fi
  fi

  for u in ${users_add}
  do
    if [ -L ${USERADD}/${u} -o -f ${USERADD}/${u} ] ; then
      if [ "${u}" != "README" ] ; then
        Warn ${EX_SOFTWARE} "skipped: ${USERADD}/${u} symlink/regular file"
      fi
      continue
    fi
    if [ ! -d ${USERADD}/${u} ] ; then
      ErrExit ${EX_CONFIG} "${USERADD}/${u} is not a directory"
    fi
    if [ -f ${USERADD}/${u}/Template ] ; then
      continue
    fi
    cd ${USERADD}/${u} || ErrExit ${EX_OSERR} "cd ${USERADD}/${u}"
    local uid=""
    local gid=""
    local shell_arg=""
    local shell
    local shellpath
    local groups
    local group_arg
    local dir_arg
    local exists
    local multiple=""
    local numeric="^[0-9]+$"

    if [ -d multiple ] ; then
      multiple=$(echo $(ls multiple))
    fi
    if [ -z "${multiple}" ] ; then
      multiple=1
    fi
    if ! [[ ${multiple} =~ ${numeric} ]] ; then
      ErrExit ${EX_CONFIG} "user: ${multiple}, non-numeric"
    fi

    if [ ! -d uid ] ; then
      ErrExit ${EX_CONFIG} "user: ${u}, no uid"
    fi
    uid=$(echo $(ls uid))
    if [ ! -d gid ] ; then
      ErrExit ${EX_CONFIG} "user: ${u}, no gid"
    fi
    gid=$(echo $(ls gid))

    for m in $(echo $(seq 1 ${multiple}))
    do
      local U=${u}
      local _uid
      local _gid
      local msg

      _uid=$(expr ${uid} + ${m} - 1)
      _gid=$(expr ${gid} + ${m} - 1)

      if [ "${multiple}" -eq 1 ] ; then
        U=${u}
      else
        U="${u}${m}"
      fi
      msg="${msg} ${U}: "

      if [ -d shell ] ; then
        shell=$(ls shell)
        shellpath=$(which $shell 2>&1)
        if [ -x "${shellpath}" ] ; then
          shell_arg="-s ${shellpath}"
        else
          Verbose "  Warning: ${shellpath} -- not executable"
        fi
      fi

      group_arg=""
      if [ -d groups ] ; then
        local ls_groups=$(echo $(ls groups))
        groups=$(echo ${ls_groups} | sed 's/ /,/g')

        if [ -n "${groups}" ] ; then 
          group_arg="-G ${groups}"
          msg="${msg} groups:${groups}"
        fi
      fi

      dir_arg=""
      dir=""
      if [ -d ${HOME_BASEDIR} -o -d ${HOME_BASEDIR}/${U} ] ; then
        if [ -d ${HOME_BASEDIR}/${U} ] ; then
          dir_arg="-d ${HOME_BASEDIR}/${U}"
          dir=${HOME_BASEDIR}/${U}
        elif [ -d ${HOME_BASEDIR} ] ; then
          dir_arg="-b ${HOME_BASEDIR}"
          dir=${HOME_BASEDIR}/${U}
        fi
      fi

      exists=$(echo $(getent passwd ${U} 2>&1))
      if [ -z "${exists}" ] ; then
        gid_explicit=""
        if (( ${uid} != ${gid} )) ; then
          group_arg="-G ${_gid}"
        else
          gid_explicit="-U"
        fi
        Rc ErrExit ${EX_OSERR} "useradd -u ${_uid} ${gid_explicit} -o ${shell_arg} ${group_arg} ${dir_arg} ${U}"
      else
        if [ -n "${shell_arg}" ] ; then
          Rc ErrExit ${EX_OSERR} "chsh ${shell_arg} ${U}"
        fi
        if [ -n "${group_arg}" ] ; then
          Rc ErrExit ${EX_OSERR} "usermod ${group_arg} ${U}"
        fi
        if [[ ${dir_arg} =~ -d ]] ; then
          Rc ErrExit ${EX_OSERR} "usermod ${dir_arg} ${U}"
        fi
      fi

      if [ -d "${USERADD_PASSWD}" ] ; then
        if [ ! -f "${USERADD_PASSWD_CLEARTEXT}" -a ! -f "${USERADD_PASSWD_ENCRYPTED}" ] ; then
          msg="${msg} -passwd"
          Rc ErrExit ${EX_OSERR} "passwd -d ${U} >/dev/null 2>&1"

        elif [ -f "${USERADD_PASSWD_ENCRYPTED}" -a -s "${USERADD_PASSWD_ENCRYPTED}" ] ; then
          local pw=$(echo $(cat ${USERADD_PASSWD_ENCRYPTED}))
          Rc ErrExit ${EX_OSERR} "echo \"${U}:${pw}\" | chpasswd -e"

        elif [ -f "${USERADD_PASSWD_CLEARTEXT}" -a -s "${USERADD_PASSWD_CLEARTEXT}" ] ; then
          local pw=$(echo $(cat ${USERADD_PASSWD_CLEARTEXT}))
          Verbose "   Note: setting cleartext passwd for user:${U} (Ensure PermitEmptyPasswords is allowed in sshd_config.)"
          Rc ErrExit ${EX_OSERR} "echo \"${U}:${pw}\" | chpasswd "

        else
          ErrExit ${EX_CONFIG} "broken password config: ${USERADD}/${U}/${USERADD_PASSWD}"
        fi
      fi

      if [ -d ${USERADD}/${u}/secontext ] ; then
        local u_secontext=$(echo $(ls ${USERADD}/${u}/secontext))
        if [ -n "${u_secontext}" ] ; then
          if [ -d ${dir} ] ; then
            local fstyp=$(stat -f --format="%T" .)
            case "${fstyp}" in
            xfs|ext*|jfs|ffs|ufs|zfs)
              Rc ErrExit ${EX_OSERR} "chcon -R ${u_secontext} ${dir}"
              local u_setype=$(echo "${u_secontext}" | sed 's/:/ /g' | awk '{print $3}')
              if [ -z "${u_setype}" ] ; then
                ErrExit ${EX_CONFIG} "${u}:empty u_setype, u_secontext:${u_secontext}" 
              fi
              Rc ErrExit ${EX_OSERR} "semanage fcontext -a -t ${u_setype} ${dir}/\(/.*\)\? ;"
              ;;
            nfs)
              # silently skip
              ;;
            *)
              Verbose " unable to set secontext:${u_secontext}"
              Verbose " on dir: ${dir}, which has a file system type,"
              Verbose " fstype:${fstyp}  which does not implement secontext extended attributes."
              ;;
            esac
          fi
        fi
      fi

      if [ -d ${dir} ] ; then
        if [ ! -L ${home}/${U} ] ; then
          Rc ErrExit ${EX_OSFILE} "ln -f -s ${dir} /home/${U}"
        fi
        Rc ErrExit ${EX_OSFILE} "chown -h ${U} /home/${U} >/dev/null 2>&1"
        Rc ErrExit ${EX_OSFILE} "chown -R ${U} ${dir}     >/dev/null 2>&1"
      fi

      if [ ! -d "${ETC_SUDOERS_D}" ] ; then
        ErrExit ${EX_OSFILE} "${ETC_SUDOERS_D}: not a directory or does not exist, ${u}"
      fi
      local u_sudoers_d=${USERADD}/${u}/${SUDOERS_D}
      if [ -d "${u_sudoers_d}" ] ; then
        if [ -f "${u_sudoers_d}/${u}" ] ; then
          Rc ErrExit ${EX_OSFILE} "cp ${u_sudoers_d}/${u} ${ETC_SUDOERS_D}/${U}"
          Rc ErrExit ${EX_OSFILE} "sed -i -e 's/${u}/${U}/' ${ETC_SUDOERS_D}/${U} ; "
          msg="${msg} +sudo"
        fi
      fi
      Verbose " ${msg}"
      Verbose ""
      msg=""

      if [ -d "${USERADD}/${U}" ] ; then
        local _home=${HOME_BASEDIR}/${U}
        local home_useradd=${_home}/useradd
        local useradd_d=${USERADD}/${U}

        Rc ErrExit ${EX_OSFILE} "chown -R -h ${U}:${U} ${useradd_d}"
        if [ -d "${useradd_d}/useradd" ] ; then
          Rc ErrExit ${EX_OSFILE} "ln -s ${useradd_d} ${home_useradd}"
          Rc ErrExit ${EX_OSFILE} "chown -h ${U}:${U} ${home_useradd}"
        fi
      fi

    done
  done

  cd ${ORIGPWD} || ErrExit ${EX_OSERR} "cd ${ORIGPWD}"
  return
}

## fn ClearSELinuxEnforce() {
##
## XXX needs much work, key from file system
##
ClearSELinuxEnforce() {
  Rc ErrExit ${EX_OSERR} "setenforce 0"
}

## @fn SetVagrantfileSyncFolderDisabled()
## XXX Vagrant v.2.2.7 fails on the sed (PROTOCOL ERROR in vboxsf file system)
##
SetVagrantfileSyncFolderDisabled() {
  grep "${HOSTNAME}.*synced_folder.*disabled: true" ${VAGRANTFILE} >/dev/null 2>&1
  if [ ${GREP_NOTFOUND} -eq $? ] ; then
    sed -i "/${HOSTNAME}.*synced_folder.*/s/\$/, disabled: true/" ${VAGRANTFILE}
    if [ $? -ne ${EX_OK} ] ; then
      ErrExit ${EX_OSFILE} "failed sed: set synced_folder disabled: true"
    fi
  fi

  return
}
 
## @fn ClearVagrantfileSyncFolderDisabled()
##
ClearVagrantfileSyncFolderDisabled() {
  sed -i "/${1:-_unknown_host_}.*synced_folder.*/s/, disabled: true//" ${VAGRANTFILE}
  if [ $? -ne ${EX_OK} ] ; then
    ErrExit ${EX_OSFILE} "failed sed: clear synced_folder disabled: true"
  fi
  return
} 

## @fn SetServices()
##
SetServices() {
  local _d
  local _on
  local _off
  local turnsvcmsg=""
  local virt_type=""

  if [ -f /.docker.env ] ; then
    Verbose " docker, skipped"
  fi
  virt_type=$(echo $(virt-what))

  for _d in ${SERVICES_D} ${SERVICES_ON} ${SERVICES_OFF}
  do
    if [ ! -d "${_d}" ] ; then
      ErrExit ${EX_CONFIG} "${_d} is not a directory"
    fi
  done

  _on=$(echo $(ls ${SERVICES_ON} 2>&1))
  _off=$(echo $(ls ${SERVICES_OFF} 2>&1))
  for _do in on off
  do
    local _sysctl_do=""
    local _sysctl_on="start enable"
    local _sysctl_off="disable stop"
    local _which=""

    case "${_do}" in
    "on")       _sysctl_do=${_sysctl_on} ; _which=${_on}  ;;
    "off")      _sysctl_do=${_sysctl_off}; _which=${_off} ;;
    esac

    local _s
    local svcs_msg=""
    for _s in ${_which}
    do
      local _c
      if [[ ${_sysctl_do} = *"No such file or directory"* ]] ; then
        continue
      fi
      if [ "${_s}" = "vboxadd" ] ; then
        if [[ "${virt}" != *virtualbox* ]] ; then
          Verbose "  ${_s} [skipped]"
          continue
        fi
      fi
      svcs_msg="${svcs_msg} ${_s}"
      for _c in ${_sysctl_do}
      do
        Rc ErrExit ${EX_OSERR} "systemctl ${_c} ${_s} >/dev/null 2>&1"
      done
    done
    Verbose "  ${_do}:  ${svcs_msg}"
  done
  return
}


## @fn UpdateRPMS()
##
UpdateRPMS() {
  local repo_fstype
  if [ -n "${SKIP_UPDATERPMS}" ] ; then
    Verbose " flag set: SKIP_UPDATERPMS "
    return
  fi

  Verbose "  cache"
  Rc ErrExit ${EX_SOFTWARE} "timeout ${YUM_TIMEOUT_BASE}  ${YUM} --disableplugin=fastestmirror clean all >/dev/null 2>&1"

  repo_fstype=$(stat -f --format="%T" $(yum repoinfo local-base | grep Repo-baseurl | sed 's/Repo-baseurl.*:.*file://'))
  if [[ ${repo_fstype} =~ nfs ]] ; then
    Verbose "  updates skipped; repos are not local."
    return
  fi
  Rc ErrExit ${EX_SOFTWARE} "timeout ${YUM_TIMEOUT_EARLY} ${YUM} --disableplugin=fastestmirror makecache >/dev/null 2>&1"
 
  Verbose "  local-update"
  Rc ErrExit ${EX_IOERR} "timeout ${YUM_TIMEOUT_UPDATE} ${YUM} --disableplugin=fastestmirror -y update"

  Verbose "  update"
  if [ -d "${COMMON_REPOS}" ] ; then
    if [ -f "${YUM_LOCALREPO_DEF}" -a -n "${LOCAL_REPO_ID}" ] ; then
      Rc ErrExit ${EX_IOERR} "timeout ${YUM_TIMEOUT_UPDATE} ${YUM} --disableplugin=fastestmirror --disablerepo=\* --enablerepo=local-base,local-base-updates,${LOCAL_REPO_ID} -y update"
    else
      Rc ErrExit ${EX_IOERR} "timeout ${YUM_TIMEOUT_UPDATE} ${YUM} --disableplugin=fastestmirror --disablerepo=\* --enablerepo=local-base,local-base-updates -y update"
    fi
  fi

  return
}

declare -x PREV_TIMESTAMP=""
## @fn TimeStamp()
##
TimeStamp() {
  local timestamp
  local emit=""

  timestamp=$(echo $(date +%Y.%m.%d\ %H:%M\ %Z))
  if [ -z "${PREV_TIMESTAMP}" ] ; then
    export PREV_TIMESTAMP=${timestamp}
    emit="now: ${timestamp}"
  else
    emit="previous: ${PREV_TIMESTAMP}, current: ${timestamp}"
  fi
  #Verbose " ${emit}"
  echo " ${emit}"
  return
}

## @fn SW()
## @brief Do something with local software: build, configure, install, verify
##
SW() {
  local dowhat=${1:-_no_verb_SW_}
  local sw_packages
  local _s
  local what=""
  local where=""
  local manifest=""
  local ARCH=${ARCH:-$(uname -m)}

  case "${dowhat}" in
  build)   what=${CFG}/${HOSTNAME}/${BUILDWHAT}                    ;;
  install) what=${INSTALLWHAT} ;                                   ;;
  config)  what=${CONFIGWHAT}  ;                                   ;;
  verify)  what=${VERIFYWHAT}  ; RPMS_MANIFEST="required.services" ;;
  *) ErrExit ${EX_SOFTWARE} "SW(): ${dowhat}"                      ;;
  esac

  [ ! -d "${what}" ] && \
    return

  # sw packages are sub-directories of ${what}
  # executable files in that directory are the steps to take to do ${what}
  # RPMS_MANIFEST contains a list of RPMS which, if present, would indicate
  # that doing ${what} is unnecessary
  sw_packages=$(echo $(ls ${what}))
  for _s in ${sw_packages}
  do
    if [[ ${_s} = ${SKIP_SW} ]] ; then
      Verbose  " "
      Verbose " ${_s}: SKIP_SW "
      continue
    fi

    case "${dowhat}" in
    build|install|config|verify)
      ### XXX if no manifest just use ${_s}
      if [ -r ${what}/${_s}/${RPMS_MANIFEST} ] ; then
        manifest=$(echo $(cat ${what}/${_s}/${RPMS_MANIFEST}))
      fi                                               ;;
    *)
      ErrExit ${EX_SOFTWARE} "SW(): ${dowhat}"         ;;
    esac

    # to verify where ${what} needs to be done, execute the ${verify} command
    # verify commands emit the string matched against the manifest list entry, if already done
    # config and verify are always done (verify=":") 
    local needTo=""
    local activePattern=""
    case "${dowhat}" in
    build)   where=${BUILDWHERE}/${_s}; verify="ls -R ${COMMON_LOCALREPO}/${ARCH}" ;;
    install) where="${what}/${_s}"; verify="rpm -q -a"                             ;;
    config)  where="${what}/${_s}"; verify=":"                                     ;;
    verify)  where="${what}/${_s}"; verify="systemctl --state=active --plain"      ;;
    *)       ErrExit ${EX_SOFTWARE} "SW(): ${dowhat}: ${_s}"                       ;;
    esac

    # walk through the manifest list, doing ${verify}
    for _m in ${manifest}
    do
      local present
      local verify_out
      local rc
      local _p
      verify_out=$(echo $(${verify}))
      _p=${activePattern:-"${_m}"}
      present=$(echo ${verify_out} | egrep "${_p}" >/dev/null 2>&1)
      rc=$?
      if (( ${GREP_FOUND} == ${rc} )) ; then
        Verbose " ${_m} "
      else
        needTo=${what}
        break;
      fi
    done

    local _msg=""
    if [ -z "${needTo}" ] ; then
      Verbose " ${_s}: [nothing needed]"
    else
      _msg=" ${_s}:  "
      sw=$(basename $_s)
      cmds=$(echo $(ls ${what}/${_s}))
      Rc ErrExit ${EX_OSFILE} "mkdir -p ${where}"
      Rc ErrExit ${EX_OSFILE} "chmod 0755 ${where}"
      local c
      for c in ${cmds}
      do
        local tstamp
        _c=$(basename ${c})
        tstamp=`date +%Y.%m.%d.%H:%M`
        export WHERE=${where}

        workdir=${where}
        out=${TMP}/${dowhat}.${sw}.${_c}.${tstamp}.out
        exe=${what}/${_s}/${c}

        if [ ! -f "${exe}" ] ; then
          continue
        fi
  
        if [ -x "${exe}" ] ; then
          local _rc
          _msg="${_msg} ${c}"

          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; bash ${exe} ${out}"
          _rc=$?
          if [ -s ${out} -a -z "${HUSH_OUTPUT}" ] ; then
              echo ' '
              echo --- ${out} ---
              cat ${out}
              echo --- ${out} ---
              echo ' '
          fi
          if [ ${EX_OK} -eq ${_rc} ] ; then
            Rc ErrExit ${EX_OSFILE} "rm -f ${out} >/dev/null 2>&1"
          else
            ErrExit ${_rc} "${exe} rc=${_rc} out=${out}"
          fi
        fi
      done
      Verbose "${_msg} "
    fi
    Verbose " "
  done
  return
}

## @fn BuildSW()
##
BuildSW(){
  local createrepo=$(which createrepo 2>&1)
  local verbose_was=""
  local d

  for d in ${LOCALREPO} ${COMMON_LOCALREPO} ${COMMON_LOCALREPO}/${ARCH}
  do
    if [ -n "${d}" ] ; then
      if [ ! -d ${d} -a ! -L ${d} ] ; then
        mkdir -p ${d}
      fi
    fi
  done

  # building sw can take time, provide additional feedback
  if [ -n "${VERBOSE}" ] ; then
    verbose_was="${VERBOSE}"
    VERBOSE="true+"
  fi

  SW build $@
  if [ ! -d "${COMMON_LOCALREPO}/repodata" -a -x "${createrepo}" ] ; then
    Verbose " createrepo COMMON_LOCALREPO:${COMMON_LOCALREPO}"
    mkdir -p /run/createrepo/cache
    ${createrepo} --workers 2 --cachedir /run/createrepo/cache ${COMMON_LOCALREPO}
  fi
  VERBOSE="${verbose_was}"
  return
}

## @fn InstallLocalSW()
##
InstallLocalSW(){
  SW install $@
  return
}

## @fn ConfigSW()
##
ConfigSW() {
  SW config $@
  return
}

## @fn VerifySW()
##
VerifySW() {
  SW verify $@
  return
}

## @fn UserVerificationJobs()
##
UserVerificationJobs() {
  local _u_verify_d
  local u
  local tstamp=`date +%Y.%m.%d.%H:%M`
  local verbose_was=""

  if [ ! -d ${USERADD} ] ; then
    ErrExit ${EX_CONFIG} "${USERADD} No such file or directory"
  fi

  if [ -n "${VERBOSE}" ] ; then
    verbose_was="${VERBOSE}"
    VERBOSE="true+"
  fi

  local users_add=$(echo $(ls ${USERADD}))

  for u in ${users_add}
  do
    if [ -L ${USERADD}/${u} -o -f ${USERADD}/${u} ] ; then
      if [ "${u}" != "README" ] ; then
        Warn ${EX_SOFTWARE} "skipped: ${USERADD}/${u} symlink/regular file"
      fi
      continue
    fi
    if [ ! -d ${USERADD}/${u} ] ; then
      ErrExit ${EX_CONFIG} "${USERADD}/${u} is not a directory"
    fi
    if [ -f ${USERADD}/${u}/Template ] ; then
      continue
    fi

    # if we ever need per-multiple-acount test jobs
    local numeric="^[0-9]+$"
    local multiple
    if [ -d ${USERADD}/${u}/multiple ] ; then
      multiple=$(echo $(basename $(ls ${USERADD}/${u}/multiple)))
    fi
    if [ -z "${multiple}" ] ; then
      multiple=1
    fi
    if ! [[ ${multiple} =~ ${numeric} ]] ; then
      ErrExit ${EX_CONFIG} "user: ${multiple}, non-numeric"
    fi

    _u_verify_d=${USERADD}/${u}/verify
    if [ ! -d ${_u_verify_d} ] ; then
      continue
    fi

    local _state=$(echo $(ls ${_u_verify_d}))
    local _n_states=$(echo ${_state} | awk '{print NF}')
    if [[ ${_n_states} != 1 ]] ; then
      ErrExit ${EX_CONFIG} "\n ${_u_verify_d} has multiple states:${_state} #:${_n_states}.\nThere must be only one state which initiates a verification job."
    fi

    # cluster is not in this state, skip
    if [ ! -f ${STATE_D}/${_state}/${HOSTNAME} ] ; then
      continue
    fi
    local _host_verify_d=${_u_verify_d}/${_state}/${HOSTNAME}
    # no directives for this host, skip
    if [ ! -d ${_host_verify_d} ] ; then
      continue
    fi

    cd ${_host_verify_d} || ErrExit ${EX_SOFTWARE} "cd ${_host_verify_d}"
    sw_list=$(echo $(ls ${_host_verify_d}))
    local opwd=$(pwd)
    _msg=" ${u}"

    for _s in ${sw_list}
    do
      _msg="${_msg}  ${_s}: "
      cd ${opwd}/${_s} || ErrExit ${EX_OSERR} "cd ${opwd}/${_s}"
      ### # executable files in this directory become the verification job
      ### # sbatch *.job

      local make_dispatched=""
      for _x in *
      do
        local exe
        local _rc
        local workdir=${opwd}/${_s}
        local script_thisdir="./"

        # if we've already run these via Makefile, don't run individually
        if [ -n "${make_dispatched}" ] ; then
          continue
        fi

        if [ ${_x} = "Makefile" ] ; then
          local make_is_executable=$(which make)
          if [ ! -x "${make_is_executable}" ] ; then
            Verbose " workdir:${workdir} found Makefile, but make is not executable, skipped"
            continue
          fi
          _x="make"
          script_thisdir="" 
          make_dispatched="true"
        else
          if [ ! -f ${_x} ] ; then
            continue
          fi
          if [ ! -x ${_x} ] ; then
            continue
          fi
        fi
        out=${TMP}/userverify.${_s}.${_x}.${tstamp}.out
        _msg="${_msg} ${_x}"

        if [ "${u}" = "root" ] ; then
          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; bash ${_x} ${out} "
          _rc=$?
        else
          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; runuser -u ${u} -- bash -c \"${script_thisdir}${_x} > ${out}\" "
          _rc=$?
        fi

        if [ \( ${EX_OK} -ne ${_rc} \) -o \( -s "${out}" -a -z "${HUSH_OUTPUT}" \) ] ; then
          echo ' '
          echo --- ${out} ---
          cat ${out}
          echo --- ${out} ---
          echo ' '
        fi
        if [ ${EX_OK} -eq ${_rc} ] ; then
          Rc ErrExit ${EX_OSFILE} "echo '[DISABLED]' rm -f ${out} >/dev/null 2>&1"
        else
          ClearNodeState "${STATE_PROVISIONED}"
          MarkNodeState "${STATE_RUNNING}"
          ErrExit ${_rc} "UserVerificationJobs(${_x}) failed, rc=${_rc}"
        fi
      done
      Verbose " ${_msg}"
    done
    cd ${opwd} || ErrExit ${EX_OSERR} "cd ${opwd}"
  done
  VERBOSE="${verbose_was}"
  return
}

## ----  pre-main() processing ----

echo -n "Loading:"
for _l in ${SH_ENV} ${SH_HEADERS} ${SH_LIBS}
do
  _found_one=""
  for _sw in env inc lib
  do
    _f=${PROVISION_SRC_D}/${_sw}/${_l}
    if [ -r "${_f}" ] ; then
      _found_one=${_f}
      echo -n " ${_sw}/${_l}"
      source ${_f}
    fi
  done
  if [ -z "${_found_one}" ] ; then
    echo -e "$(basename $0): cannot find ${_l}"
    exit ${EX_SOFTWARE}
  fi
done
echo ''

## ----  pre-main() processing ----

main() {
  local dowhat="$*"
  if [ 0 -eq $# ] ; then
    dowhat=${DEFAULT_ORDER_OF_OPERATIONS}
  fi

  Trap

  local _m
  local _last=$(echo ${dowhat} | awk '{print $NF}')
  # _first or _second because SetFlags is first, but VERBOSE hasn't yet been set
  local _first=$(echo ${dowhat} | awk '{print $1}')
  local _second=$(echo ${dowhat} | awk '{print $2}')
  for _m in ${dowhat}
  do
    local separator=""
    if ! [[ ${_m} = ${_first} || ${_m} = ${_second} || ${_m} = ${_last} ]] ; then
      # if running manually, then our name is "provision", otherwise it is a dynamic name "vagrant-shell-..."
      if [[ ${IAM} =~ provision ]] ; then 
        separator=""
      fi
    fi
    Verbose "${_m} "
    ${_m}
    Verbose "${separator}"
  done
  if [ -z "${TIMESTAMP}" ] ; then
    Verbose "  "
  fi
  exit ${EX_OK}
}

Usage() {
  sed -n ': << /_USAGE_$/,/_USAGE_$/p' < ${IAMFULL} | \
    grep -v '_USAGE_$' | \
    sed "s/^#//"
  echo Try typing: \"${IAMFULL} Usage\"
  exit ${EX_USAGE}
}

main $*
ErrExit ${EX_SOFTWARE} "FAULTHROUGH: main"
exit ${EX_SOFTWARE}

# UNREACHED
: << _USAGE_
#
# provision - base sculpting of a generic OS image installation into a cluster node structure
# This is usually invoked by a builder mechanism, such as vagrant.
# Any arguments are interpreted as function calls which replace the DEFAULT_ORDER_OF_OPERATIONS.
# 
_USAGE_

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
