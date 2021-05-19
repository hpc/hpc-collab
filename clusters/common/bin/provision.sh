#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/provision.sh

## This file contains the main driver for the provisioning functions and libraries.

HOSTNAME=$(hostname -s)
CLUSTERNAME=${HOSTNAME:0:2}
VC=${VC:-${CLUSTERNAME}}
BASEDIR=${VC:-vagrant}

isvirt=$(systemd-detect-virt)
rc=$?

if [ -n "${isvirt}" -a -n "${MODE}" -a "${MODE}" = "host" ] ; then
  # @todo XXX need a better heuristic
  # NESTED_VIRT_COEF=10 is based on measurements of virtualbox/kvm/ProxMox/2.67Ghz Xeon 5650
  declare -x NESTED_VIRT_COEF=10
fi

if [ "${isvirt}" != "none" ] ; then
  # running on VM, add users' accounts to all nodes, on one of them (Features=controller),
  # add slurm user accounts and associations
  # assume 
  declare -x MODE=${MODE}:-"cluster"
  
  declare -x ANCHOR=/${BASEDIR}/common/provision
  declare -x BASEDIR=$(realpath ${ANCHOR}/..)
  declare -x PROVISION_SRC_D=/${BASEDIR}/cfg/provision

  declare -x PROVISION_SRC_LIB_D=${PROVISION_SRC_D}/lib
  declare -x PROVISION_SRC_INC_D=${PROVISION_SRC_D}/inc
  declare -x PROVISION_SRC_ENV_D=${PROVISION_SRC_D}/env
  declare -x PROVISION_SRC_FLAG_D=${PROVISION_SRC_D}/flag
else
  declare -x MODE=${MODE}:-"host"

  ## the invocation directory is expected to be the clusters/${VC} directory
  ## % pwd
  ## <git-repo>/clusters/vc
  ## % env VC=vc ../../clusters/common/bin/addusers.sh
  declare -x ANCHOR=../common
fi

set -o nounset
declare -x LOADER_SHLOAD=$(realpath ${ANCHOR}/loader/shload.sh)

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LOADER_SHLOAD} -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 99
fi
source ${LOADER_SHLOAD}
declare -x DEBUG=${DEBUG:-""}

## The following cannot be in a sub-function in order for source <___> to have global scope, ex. EX_OK, etc.
declare -x ANCHOR=${ANCHOR:-""}

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
    if [ -d /${BASEDIR} ] ; then
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

# debugging note: each of these routines must be able to be called in a state where the node is already
# provisioned or partially provisioned, allowing for it to be run or rerun manually.

declare -x CORE_ORDER_OF_OPERATIONS="SetFlags TimeStamp TimeSinc VerifyEnv SetupSecondDisk CopyHomeVagrant       \
                                     CopyCommon OverlayRootFS AppendFilesRootFS CreateNFSMountPoints             \
                                     InstallEarlyRPMS ConfigureCentOSRepos WaitForPrerequisites ConfigureDBRepos \
                                     InstallRPMS InstallFlaggedRPMS BuildSW InstallLocalSW ConfigSW SetServices  \
                                     UserAdd VerifySW UpdateRPMS MarkNodeProvisioned UserVerificationJobs        "

declare -x DEBUG_DEFAULT_ORDER_OF_OPERATIONS="DebugNote VerbosePWD ClearSELinuxEnforce ${CORE_ORDER_OF_OPERATIONS}"


declare -x NORMAL_ORDER_OF_OPERATIONS="${CORE_ORDER_OF_OPERATIONS} UnmountProvisioningFS TidyDetritus TimeStamp"

declare -a REPO_DISK_LIST=( '/dev/vdb' '/dev/sdb' )
declare -x REPO_DISK=""
declare -x REPO_PART=""
declare -x REPO_PART_NO=1

## yes, there's a bash one-liner to do this, but no, this may be more readable
if [ -n "${DEBUG}" ] ; then
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${DEBUG_DEFAULT_ORDER_OF_OPERATIONS}
else
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${NORMAL_ORDER_OF_OPERATIONS}
fi

## @fn order()
##
OrderNodeList() {
  local n
  local i
  local ordered=""
  local numeric="[0-9]+"
  local n_nodes
  local nodelist=($@)

  # walk through the given node list
  # if bootorder <  i, prepend node to ordered list
  # if bootorder >= i, append node to ordered list
  # XXX @future if bootorder == i, put in parallelizable list, don't increment index
  n_nodes=$#
  i=1
  for i in $(seq 1 ${n_nodes})
  do
    n=$1
    local cl=${n:0:2}
    local nodes_i=$(ls /${cl}/cfg/${cl}*/attributes/bootorder/${i})
    local nodepath
    for nodepath in ${nodes_i}
    do
      local d=$(dirname ${nodepath})
      local r=$(realpath ${d}/../..)
      local n=$(basename ${r})
      if [[ ${ordered} = *${n}* ]] ; then
        continue
      fi
      ordered[$i]="${n}"
    done
    shift
  done
  echo ${ordered[@]}
  return
}

## @fn WaitForPrerequisites()
##
WaitForPrerequisites() {
  local nodes
  local retries
  local nodesOrdered=""

  if [ ! -d "${REQUIREMENTS}" ] ; then
    return
  fi

  nodes=$(echo $(ls ${REQUIREMENTS}))
  nodesOrdered=($(OrderNodeList ${nodes}))

  for _n in ${nodesOrdered[@]}
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
      if [ ${rc} -eq 0 ] ; then
        Rc ErrExit ${EX_OSFILE} "rm ${out}"
      else
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
  local os_version=${OS_VERSION:-""}

  for f in /etc/os-release-upstream /etc/os-release  /etc/system-release
  do
    if [ ! -r ${f} ] ; then
      continue
    fi
    if [ -n "${os_version}" ] ; then
      echo "${os_version}"
      return
    fi

    local v
    v=$(grep -E '^ID=' ${f} | sed 's/ID=//' | sed 's/"//g')
    case "${v}" in
      rhel|"Red Hat Enterprise Linux"*|RHEL|centos|CentOS) echo "rhel" ; export OS_VERSION="${v}"; return  ;;
      sles|"SUSE Linux Enterprise Server"*|SLES)           echo "sles" ; export OS_VERSION="${v}"; return  ;;
      *) continue ;;
    esac
  done
  return
}


## Required commands for a given environment @see VerifyEnv()
declare -A RequiredCommands
# @todo build this via introspection of ourselves
# [base] linux-distribution independent required commands
RequiredCommands[base]="awk base64 basename cat dirname du echo env findmnt fmt grep head hostname ifconfig ip \
                        logger ls lsof mkdir pgrep pkill poweroff printf ps pwd rm rpm su sed setsid stat      \
                        strings stty sum tail tar test timeout"
# [cray] Cray-specific required commands
RequiredCommands[cray]=""
# [rhel] RHEL or RHEL-alike (TOSS, CentOS, &c) required commands
RequiredCommands[rhel]=""
# [sles] SuSe required commands
RequiredCommands[sles]=""
# [slurm] Slurm dependencies - all distributions
RequiredCommands[slurm]="sacct sacctmgr scontrol sdiag sinfo sprio squeue sshare"

declare -x CREATEREPO=""
declare -x REPOSYNC=""
declare -x RSYNC=""
declare -x WGET=""
declare -x YUM=""

declare -x CREATEREPO_CACHE=/run/createrepo/cache

declare -x ETCFSTAB=/etc/fstab
declare -x ETCEXPORTS=/etc/exports
declare -x MOUNTINFO=/proc/self/mountinfo
declare -x MEMINFO=/proc/meminfo
declare -x CPUINFO=/proc/cpuinfo
declare -x JUMBOFRAMES=${JUMBOFRAMES:-""}

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

  if [ -n "${JUMBOFRAMES}" ] ; then
    ## host-only private network tuning
    ifconfig eth1 mtu 9000
  fi

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
  Rc ErrExit ${EX_OSFILE} "mount -o remount,sync,relatime /"
  sync
  MarkNodeState "${STATE_PROVISIONED}"
  sync
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

## @fn ConfigureCentOSRepos()
##
ConfigureCentOSRepos() {
  local repos_size
  local numeric="^[0-9]+$"
  local _ingested_tarball=""
  local _ingested_tarball_flagfile="${COMMON}/repos/._ingested_tarball"
  local _have_repos=""
  local repo_is_local=""
  local n_workers=$(ls /${CLUSTERNAME}/cfg/${HOSTNAME}/attributes/procs/)
  local _disable_repo=""

  export CREATEREPO=$(which createrepo 2>&1)
  export REPOSYNC=$(which reposync 2>&1)
  export RSYNC=$(which rsync 2>&1)
  export WGET=$(which wget 2>&1)
  export RPM_CMD=$(which rpm 2>&1)
  export YUM=$(which yum 2>&1)
  export YUM_CFG_MGR=$(which yum-config-manager 2>&1)

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
  local _root_fsid=$(stat -f --format "%i" /)
  local _repos_fsid=$(stat -f --format "%i" ${COMMON}/repos)
  local _repos_fstype=$(stat -f --format "%T" ${COMMON}/repos)

  if [ "${_repos_fsid}" != "${_root_fsid}" -a "${_repos_fstype}" != "nfs" ] ; then
    repo_is_local="${COMMON}/repos ${_repos_fstype} ${_repos_fsid}"
  fi 

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

  for r in base updates
  do
    Rc ErrExit ${EX_OSERR} "${YUM_CFG_MGR} --enable ${r}"
  done

  # only copy the repos area into this VM if we appear to be the one with repo-related tools installed
  ## XXX @future key on actual per-host attribute, ex. "repohost"
  [ -z "${repo_is_local}" ] && return
  [ -z "${REPO_MOUNT}" ]    && return
  [ ! -b "${REPO_DISK}" ]   && return 
  [ ! -b "${REPO_PART}" ]   && return 

  Rc ErrExit ${EX_OSERR} "mkdir -p ${REPO_MOUNT} 2>&1"
  Rc ErrExit ${EX_OSERR} "findmnt -n -k -l ${REPO_MOUNT} >/dev/null || mount -t xfs ${REPO_PART} ${REPO_MOUNT} 2>&1"
  Rc ErrExit ${EX_OSERR} "mkdir -p ${CREATEREPO_CACHE} 2>&1"

  houses_storage="fs$"
  if ! [[ ${HOSTNAME} =~ ${houses_storage} ]] ; then
    Verbose " HOSTNAME:${HOSTNAME} does not appear to house the repository directly, would skip repo update"
    ## return
  fi

  # manually peek into the repo hierarchy so that we don't need to call the expensive & slow yum if it will fail
  local _enabled=""
  local repo_dir=${REPO_MOUNT}/centos/7/os/x86_64/repodata
  if [ -d "${repo_dir}" -a -f "${repo_dir}/repomd.xml" ] ; then
    _disable_repo="--disablerepo=epel,mariadb-main,mariadb-es-main,mariadb-tools"
    _enabled=$(echo $(timeout ${YUM_TIMEOUT_EARLY} ${YUM} ${_disable_repo} repoinfo local-base | \
                          grep 'Repo-status' | sed 's/Repo-status.*://'))
  fi
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
      for r in $(grep baseurl ${YUM_REPOS_D}/${YUM_CENTOS_REPO_LOCAL} | sed 's/^#.*//' | sed 's/baseurl=file:\/\///')
      do
        if [ ! -d "${r}/repodata" -a ! -f "${r}/repodata/repomd.xml" ] ; then
          local workers="--workers ${n_workers}"
          local cache="--cachedir ${CREATEREPO_CACHE}"
          Rc ErrExit ${EX_CONFIG} "export basearch=${ARCH} releasever=${YUM_CENTOS_RELEASEVER} ; ${CREATEREPO} ${workers} ${cache} ${r}"
        fi
        Rc ErrExit ${EX_OSERR} "${YUM_CFG_MGR} --enable ${r}"
      done
    fi

    if [ -r ${YUM_REPOS_D}/${YUM_CENTOS_REPO_REMOTE} ] ; then
      Verbose " - ${YUM_CENTOS_REPO_REMOTE} "
      Rc ErrExit ${EX_OSERR} "${YUM_CFG_MGR} --disable base"
      Rc ErrExit ${EX_OSERR} "${YUM_CFG_MGR} --disable updates"
    fi
    if [ -d ${VC_COMMON}/repos ] ; then
      size=$(du -x -s -m ${VC_COMMON}/repos | awk 'BEGIN {total=0} {total += $1} END {print total}')

      if [ "${size}" -ne 0 ] ; then
        Verbose "   ${VC_COMMON}/repos => ${COMMON}/repos ${size}Mb "
        Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${VC_COMMON} repos | \
                              (cd ${COMMON}; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
      fi
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
          set +o nounset
          local how_many_repo=${#CENTOS_RSYNC_REPO_URL[@]}
          local rand_repo=$(( ( $RANDOM % ${how_many_repo} ) + 1 ))
          repo_url=${CENTOS_RSYNC_REPO_URL[${rand_repo}]}
          set -o nounset
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
        timeout ${RSYNC_TIMEOUT_DRYRUN} ${RSYNC} --dry-run -4 -az --delete --exclude='repo*' ${repo_url}/${suffix}/ ${d} >/dev/null 2>&1
        rc=$?
        if [ "${repo_url}" != ${DEFAULT_PREFERRED_REPO} ] ; then
          if [ ${rc} -ne ${EX_OK} ] ; then
            repo_url=${DEFAULT_PREFERRED_REPO}
          fi
        # XXX else pick another repo
        fi
        (( ++retries ))
        _timeout=$(expr ${_timeout} \* retries)
        timeout ${_timeout} ${RSYNC }-4 -az --delete --exclude='repo*' --exclude='._*' ${repo_url}/${suffix}/ ${d}/ >/dev/null 2>&1
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
    if [ ! -d "${d}/repodata" -a ! -f "${d}/repodata/repomd.xml" ] ; then
      local workers="--workers ${n_workers}"
      local cache="--cachedir ${CREATEREPO_CACHE}"
      Rc ErrExit ${EX_OSERR} "${CREATEREPO} --update ${workers} ${cache} ${d}"
    fi
  done
  return
}

##@fn ConfigureDBMariaEnterpriseRepo()
##
ConfigureDBMariaEnterpriseRepo() {
  local mariadb_repo_conf=mariadb-enterprise.repo
  local mariadb_local_repo_conf=mariadb-enterprise-local.repo
  local mariadb_repo_conf_path=${YUM_REPOS_D}/${mariadb_repo_conf}
  local mariadb_local_repo_conf_path=${YUM_REPOS_D}/${mariadb_local_repo_conf}
  local xfr_d=${XFR}/${WHICH_DB}
  local _enabled=""

  # don't call the slow and expensive yum repoinfo if the directory hierarchy is not present
  local repo_dir=${COMMON}/${REPOS}/${WHICH_DB}/mariadb-es-main
  if [ -d "${repo_dir}" -a -f "${repo_dir}/repomd.xml" ] ; then
    _enabled=$(egrep '/^enabled[[:space:]]*=[[:space:]]*1/' ${mariadb_local_repo_conf_path})
    #_enabled=$(echo $(timeout ${YUM_TIMEOUT_EARLY} ${YUM} --disablerepo=epel repoinfo mariadb-es-main | \
    #                        grep 'Repo-status' | sed 's/Repo-status.*://'))
  fi
  if [[ ${_enabled} =~ *enabled* ]] ; then
    return
  fi

  # we do this download on the node itself to honor the rules of the commercial mariadb-enterprise
  # users must register with mariadb.com and obtain the download_token themselves

  dl_url="https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup"
  dl_token_file=${xfr_d}/download_token
  
  if [ ! -f ${xfr_d}/mariadb_es_repo_setup ] ; then
    Verbose "  wget: mariadb_es_repo_setup"
    Rc ErrExit ${EX_OSERR} "${WGET} -4 ${dl_url} -P ${xfr_d}"
    Rc ErrExit ${EX_OSFILE} "chmod +x ${xfr_d}/mariadb_es_repo_setup"
  fi

  # the following is necessary to comply with the mariadb (the company) rules regarding downloads, and
  # controlling access to the download token.
  if [ ! -f ${dl_token_file} ] ; then
    ErrExit ${EX_CONFIG} "dl_token_file:${dl_token_file} missing. Obtain one from: MariaDB.com.\n  (https://mariadb.com/downloads/#mariadb_platform-enterprise_server)"
  fi
  if [ ! -s ${dl_token_file} ] ; then
    ErrExit ${EX_CONFIG} "dl_token_file:${dl_token_file} empty"
  fi
  export dl_token=$(cat ${dl_token_file})

  token_is_valid=$(echo $(wget https://dlm.mariadb.com/repo/${dl_token}/ 2>&1))
  if [[ "${token_is_valid}" = *"404: Not Found"* ]] ; then
    ErrExit ${EX_CONFIG} "MariaDB Enterprise download token may not be valid; received '404: Not Found'\n  Consider changing the WHICH_DB configuration flag to the default: 'mariadb-community'\n  The flag is clusters${PROVISION_SRC_D}/flag/WHICH_DB"
  fi

  Verbose "  exec: mariadb_es_repo_setup"
  Rc ErrExit ${EX_SOFTWARE} "bash ${xfr_d}/mariadb_es_repo_setup --token=${dl_token} > ${YUM_REPOS_D}/${WHICH_DB}.repo"

  if [ -f ${xfr_d}/MariaDB-Enterprise-GPG-KEY ] ; then
    mariadbenterprise_url=$(egrep 'gpgkey =.*Enterprise' ${mariadb_repo_conf_path} | sort | uniq | \
                              sed 's/gpgkey = //')
    if [ -z "${mariadbenterprise_url}" ] ; then
      ErrExit "  GPG URL is empty (from ${mariadb_repo_conf_path})"
    fi
    Rc ErrExit ${EX_IOERR} "${WGET} -4 -P ${xfr_d} ${mariadbenterprise_url}"
  fi
  Verbose "   MariaDB-Enterprise-GPG-KEY"
  local rpm=$(which rpm)
  Rc ErrExit ${EX_SOFTWARE} "${rpm} --import ${xfr_d}/MariaDB-Enterprise-GPG-KEY"

  local repo_is_local=""
  if [ "${_repos_fsid}" != "${_root_fsid}" -a "${_repos_fstype}" != "nfs" ] ; then
    repo_is_local="${COMMON}/repos ${_repos_fstype} ${_repos_fsid}"
  fi 

  # if repo is local (vcfs), reposync, else minimally verify that it appears in good state
  if [ -n "${repo_is_local}" ] ; then
    Verbose "  reposync"
    for r in mariadb-es-main mariadb-tools
    do
      Verbose "   ${r}"
      Rc ErrExit ${EX_SOFTWARE} "timeout ${YUM_TIMEOUT_UPDATE} ${REPOSYNC} --gpgcheck -l --repoid=${r} --download_path=${repo_root}"
    done
  else
    for r in mariadb-es-main mariadb-tools
    do
      Verbose "   ${r}"
      if [ ! -d ${repo_root}/${r}/repodata -o ! -f ${repo_root}/${r}/repodata/repomd.xml ] ; then
        ErrExit ${EX_SOFTWARE} "Repo: ${r} does not appear to be valid, no repodata or repomd.xml. Was the download token valid?"
      fi
    done
    Verbose "  reposync (skipped, repository is not local)"
  fi

  local disabled_repo_list=$(echo $(${YUM} repolist -v disabled | grep Repo-id | sed -e 's/Repo-id[[:space:]]*: //'))
  for r in mariadb-es-main mariadb-tools
  do
    Verbose "  ${r}"
    repo_dir=${repo_root}/${r}
    if [ ! -d ${repo_dir} ] ; then
      ErrExit ${EX_OSFILE} "  repo_dir:${repo_dir} does not exist"
    fi
    Verbose "   createrepo"
    if [ -f ${mariadb_repo_conf_path} ] ; then 
      Verbose " - ${mariadb_repo_conf} ${r}"
      Rc ErrExit ${EX_OSFILE} "sed -i -e '/^enabled = 1/s/= 1/= 0/' ${mariadb_repo_conf_path} ;"
    fi
    if [ ! -f ${mariadb_local_repo_conf_path} ] ; then
      ErrExit ${EX_CONFIG} "mariadb_local_repo_conf_path:${mariadb_local_repo_conf_path} missing from this node's configuration"
    fi

    local rdir="/${r/local-/}"
    local localrepo=local-$(basename ${rdir})
    local repo=${localrepo//[[a-zA-Z_]]* /local-/}
    if [[ ${disabled_repo_list} == *${repo}* ]] ; then 
      Rc ErrExit ${EX_OSFILE} "sed -i -e '/^enabled=0/s/=0/=1/' ${mariadb_local_repo_conf_path} ;"
      Verbose " + ${mariadb_local_repo_conf} ${r}"
    fi
    if [ ! -d "${r}/repodata" -a ! -f "${r}/repodata/repomd.xml" ] ; then
      local workers="--workers ${n_workers}"
      local cache="--cachedir ${CREATEREPO_CACHE}"
      local update="--update"
      Rc ErrExit ${EX_CONFIG} "${CREATEREPO} ${update} ${workers} ${cache} ${repo_dir}/${ARCH}"
    fi
  done
  return
}

##@fn ConfigureDBMariaCommunityRepo()
##
ConfigureDBMariaCommunityRepo() {
  local mariadb_repo_conf=mariadb.repo
  local mariadb_local_repo_conf=mariadb-local.repo
  local mariadb_repo_conf_path=${YUM_REPOS_D}/${mariadb_repo_conf}
  local mariadb_local_repo_conf_path=${YUM_REPOS_D}/${mariadb_local_repo_conf}
  local _enabled=""
  local xfr_d=${XFR}/${WHICH_DB}
  local repo_root=${repo_d}/${WHICH_DB}

  for _f in url repo_setup
  do
    if [ ! -s ${XFR}/WHICH_DB/${_f} ] ; then
      ErrExit ${EX_SOFTWARE} "${_f}:${!_f} is empty or missing"
    fi
  done

  ## peek into  mariadb local repo configuration stanza rather than use repoinfo because
  ## yum-utils have the time-consuming habit of reaching out to the repository and waiting
  ## for a network timeout, whether or not the repository is enabled.
  _enabled=$(egrep '/^enabled[[:space:]]*=[[:space:]]*1/' ${mariadb_local_repo_conf_path})
  #_enabled=$(echo $(timeout ${YUM_TIMEOUT_EARLY} ${YUM} --disablerepo=epel repoinfo mariadb-main | \
  #                              grep 'Repo-status' | sed 's/Repo-status.*://'))
  if [[ ${_enabled} =~ *enabled* ]] ; then
    return
  fi

  ## Mariadb provides an initial script ("repo_setup") which sets up the in-node repositories

  local URL=$(cat ${XFR}/WHICH_DB/url)
  local SETUP=$(cat ${XFR}/WHICH_DB/repo_setup)
  local setup=$(basename ${SETUP})
  local target_d=${xfr_d}
  local target=${target_d}/${setup}
  local target_repo_file=${YUM_REPOS_D}/${WHICH_DB/-community/}.repo

  ## some queries, ie. repolist, remain host-local
  ## verify that the remote mariadb repository is disabled
  local disabled_repo_list=$(echo $(${YUM} repolist -v disabled | grep Repo-id | sed -e 's/Repo-id[[:space:]]*: //'))
  if [ "${target_repo_file}" != "${mariadb_repo_conf_path}" ] ; then
    ErrExit ${EX_SOFTWARE} "target_repo_file:${target_repo_file} != mariadb_repo_conf_path:${mariadb_repo_conf_path}"
  fi

  if [ ! -s ${mariadb_repo_conf_path} ] ; then
    if [ ! -d ${target_d} ] ; then
      ErrExit ${EX_SOFTWARE} "target_d:${target_d} not a directory"
    fi

    if [ ! -f ${target} ] ; then
      Rc ErrExit ${EX_OSERR} "${WGET} -4 -P ${target_d} ${URL}/${SETUP}"
      if [ ! -s ${target} ] ; then
        ErrExit ${EX_SOFTWARE} "target:${target} is empty or missing"
      fi
    fi
    if [ ! -x ${target} ] ; then
      Rc ErrExit ${EX_OSFILE} "chmod +x ${target}"
    fi

    Rc ErrExit ${EX_SOFTWARE} "bash ${target}"
  fi
 
  ## as above:
  ## _enabled=$(echo $(timeout ${YUM_TIMEOUT_EARLY} ${YUM} --disablerepo=epel repoinfo mariadb-main | \
  ##                          grep 'Repo-status' | sed 's/Repo-status.*://'))
  _enabled=$(egrep '/^enabled[[:space:]]*=[[:space:]]*1/' ${mariadb_local_repo_conf_path})
  if [[ ${_enabled} =~ *enabled* ]] ; then
    return
  fi

  local _root_fsid=$(stat -f --format "%i" /)
  local _repos_fsid=$(stat -f --format "%i" ${COMMON}/repos)
  local _repos_fstype=$(stat -f --format "%T" ${COMMON}/repos)

  if [ "${_repos_fsid}" != "${_root_fsid}" -a "${_repos_fstype}" != "nfs" ] ; then
    repo_is_local="${COMMON}/repos ${_repos_fstype} ${_repos_fsid}"
  fi 

  ## external Makefile may remove the ${repo_root}/.copied-to-xfr flag file
#  for r in mariadb-main mariadb-tools
  for r in mariadb-main
  do
    ## if local cached RPMs are available, use them, fall back to a full reposync
    Verbose "    ${r}"
    repo_dir=${repo_root}/${r}
    if [ -n "${repo_is_local}" ] ; then
      Verbose "     reposync"
      if [ ! -f ${XFR}/WHICH_DB/.copied-to-xfr ] ; then
        REPOSYNC_TIMEOUT_COEFFICIENT=${REPOSYNC_TIMEOUT_COEFFICIENT:-4}
        local t=$(expr ${YUM_TIMEOUT_UPDATE} \* ${REPOSYNC_TIMEOUT_COEFFICIENT})
        local args="--gpgcheck -l --newest-only"
        Rc ErrExit ${EX_SOFTWARE} "timeout ${t} ${REPOSYNC} ${args} --repoid=${r} --download_path=${repo_root}"
      else
        Rc ErrExit ${EX_OSFILE} "mkdir -p ${repo_dir}"
        Rc ErrExit ${EX_OSFILE} "cp -pr ${xfr_d}/${WHICH_DB}/${r} ${repo_root}"
      fi
    fi

    ## once the reposync succeeds, keep a local copy for quicker reprovisioning 
    Rc ErrExit ${EX_IOERR} "mkdir -p ${xfr_d}/${WHICH_DB}/${r}"
    Rc ErrExit ${EX_IOERR} "cp -pr ${repo_dir}/rpms ${xfr_d}/${WHICH_DB}/${r}"
    Rc ErrExit ${EX_IOERR} "date > ${XFR}/WHICH_DB/.copied-to-xfr "
    Verbose "     createrepo"
    Verbose "   - ${mariadb_repo_conf} ${r}"
    Rc ErrExit ${EX_OSFILE} "sed -i -e '/^enabled = 1/s/= 1/= 0/' ${mariadb_repo_conf_path} ;"
    if [ ! -f ${mariadb_local_repo_conf_path} ] ; then
      ErrExit ${EX_CONFIG} "mariadb_local_repo_conf_path:${mariadb_local_repo_conf_path} missing from this node's configuration"
    fi

    local rdir="/${r/local-/}"
    local localrepo=local-$(basename ${rdir})
    local repo=${localrepo//[[a-zA-Z_]]* /local-/}
    if [[ ${disabled_repo_list} == *${repo}* ]] ; then 
      Rc ErrExit ${EX_OSFILE} "sed -i -e '/^enabled = 0/s/ = 0/ = 1/' ${mariadb_local_repo_conf_path} ;"
      Verbose "   + ${mariadb_local_repo_conf} ${r}"
    fi

    if [ ! -d "${repo_dir}/repodata" -a ! -f "${repo_dir}/repodata/repomd.xml" ] ; then
      local workers="--workers ${n_workers}"
      local cache="--cachedir ${CREATEREPO_CACHE}"
      local update="--update"
      Verbose "     createrepo (update)"
      Rc ErrExit ${EX_CONFIG} "${CREATEREPO} ${update} ${workers} ${cache} ${repo_dir}"
    fi
  done
  return
}


##@fn ConfigureDBCommunityMysqlRepo()
##
ConfigureDBCommunityMysqlRepo() {
  local communitymysql_local_repo_conf=community-mysql-local.repo
  local communitymysql_repo_conf_path=${YUM_REPOS_D}/${communitymysql_local_repo_conf}
  local communitymysql_local_repo_conf_path=${YUM_REPOS_D}/${communitymysql_local_repo_conf}

  # configure community-mysql repo
  #  1. collect GPG key and import it
  #  2. collect RPMS and populate local repo copy
  #  3. local createrepo
  local rpms_d=${RPM}/flagged/WHICH_DB/${WHICH_DB}/add
  local target_d=${XFR}/${WHICH_DB}/RPMS

  local mysql_community_primer_url="https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm"
  local primer_mysql_rpm=mysql80-community-release-el7-3.noarch.rpm
  local need_primer_rpm=$(rpm -a -q | grep -i mysql80-community-release)

  if [ -z "${need_primer_rpm}" ] ; then
    local target=${target_d}/${primer_mysql_rpm}

    if [ ! -d ${target_d} ] ; then
      Rc ErrExit ${EX_CONFIG} "mkdir -p ${target_d}"
    fi
    if [ ! -f ${target} ] ; then
      Rc ErrExit ${EX_IOERR} "${WGET} -P ${target_d} -4 ${mysql_community_primer_url}/${primer_mysql_rpm}"
    fi
    if [ ! -f ${target} ] ; then
      ErrExit ${EX_CONFIG} "${target} missing"
    fi
    Rc ErrExit ${EX_SOFTWARE} "${YUM} --disablerepo=\* --disableplugin=fastestmirror -y localinstall ${target}"
  fi

  repo_dir=${repo_root}/mysql80-community

  local _root_fsid=$(stat -f --format "%i" /)
  local _repos_fsid=$(stat -f --format "%i" ${COMMON}/repos)
  local _repos_fstype=$(stat -f --format "%T" ${COMMON}/repos)

  if [ "${_repos_fsid}" != "${_root_fsid}" -a "${_repos_fstype}" != "nfs" ] ; then
    repo_is_local="${COMMON}/repos ${_repos_fstype} ${_repos_fsid}"
  fi 

  if [ -n "${repo_is_local}" ] ; then
    Rc ErrExit ${EX_SOFTWARE} "mkdir -p ${repo_dir}"
    if [ -z "${repo_root}" ] ; then
      ErrExit ${EX_SOFTWARE} "repo_root:${repo_root}"
    fi
    Rc ErrExit ${EX_SOFTWARE} "mkdir -p ${repo_root}"

    if [ ! -d ${rpms_d} ] ; then
      ErrExit ${EX_CONFIG} "rpm repo is local, rpms_d:${rpms_d} is not a directory"
    fi

    local mysql_pubkey_file=${XFR}/${WHICH_DB}/RPM-GPG-KEY-mysql
    if [ ! -f ${mysql_pubkey_file} ] ; then
      Warn ${EX_CONFIG} "GPG key file: $(basename ${mysql_pubkey_file}) missing, proceeding without it"
    else
      if [ ! -s ${mysql_pubkey_file} ] ; then
        Warn ${EX_CONFIG} "GPG key file: empty, proceeding without it"
      else
        Rc ErrExit ${EX_SOFTWARE} "gpg --import ${mysql_pubkey_file}"
        Rc ErrExit ${EX_SOFTWARE} "rpm --import ${mysql_pubkey_file}"
      fi
    fi

    local rpms_add=$(ls ${rpms_d}/*.rpm 2>/dev/null)
    if [ -n "${rpms_add}" ] ; then
      for r in ${rpms_add}
      do
        if [ -s "${r}" ] ; then
          Rc ErrExit ${EX_SOFTWARE} "cp ${rpms_add} ${repo_root}/mysql80-community"
        fi
      done
    else
      if [ -n "${REPOSYNC_EMPTY_DBREPO}" ] ; then
        Rc Warn ${EX_CONFIG} "rpms_d:${rpms_d} empty"
        Verbose "   reposync"
        GPGCHECK="--gpgcheck "
        Rc ErrExit ${EX_SOFTWARE} "${REPOSYNC} ${GPGCHECK} -l --repoid=${r} --newest-only --download_path=${repo_root}"
      else
        Rc ErrExit ${EX_CONFIG} "  rpms_d:${rpms_d}/ empty,\n   no RPMS found\n"
      fi
    fi
  fi

  if [ ! -f "${communitymysql_local_repo_conf_path}" ] ; then
    Rc ErrExit ${EX_CONFIG} "communitymysql_local_repo_conf_path:${communitymysql_local_repo_conf_path}"
  fi

  _enabled=$(egrep '/^enabled[[:space:]]*=[[:space:]]*1/' ${communitymysql_local_repo_conf_path})
  if [[ ${_enabled} =~ *enabled* ]] ; then
    Verbose " + ${communitymysql_local_repo_conf} mysql80-community (already enabled)"
    return
  fi
  Verbose " + ${communitymysql_local_repo_conf} mysql80-community"
  Rc ErrExit ${EX_OSERR} "yum-config-manager --setopt=local-comunity-mysql.enabled=1 --save"

  if [ ! -d "${r}/repodata" -a ! -f "${r}/repodata/repomd.xml" ] ; then
    local workers="--workers ${n_workers}"
    local cache="--cachedir ${CREATEREPO_CACHE}"
    local update="--update"

    Rc ErrExit ${EX_CONFIG} "${CREATEREPO} ${update} ${workers} ${cache} ${repo_dir}"
  fi
  return
}


##@fn ConfigureDBRepos()
## @brief if repos aren't configured, do so.  if repo is to be loaded locally, also reposync
## @todo break out into per-DB functions, possibly in an external module
##
##
ConfigureDBRepos() {
  local repo_d=""
  local repo_is_local=""
  local n_workers=$(ls /${CLUSTERNAME}/cfg/${HOSTNAME}/attributes/procs/)

  export CREATEREPO=$(which createrepo 2>&1)
  export REPOSYNC=$(which reposync 2>&1)
  export RSYNC=$(which rsync 2>&1)
  export WGET=$(which wget 2>&1)
  export RPM_CMD=$(which rpm 2>&1)
  export YUM=$(which yum 2>&1)

  # this isn't a check in RequiredCommands because we need to install early RPMs first
  for _x in CREATEREPO REPOSYNC RPM WGET YUM
  do
    if [ ! -x "${!_x}" ] ; then
      ErrExit ${EX_CONFIG} "${_x}:${!_x}"
    fi
  done

  if [ -z "${CREATEREPO_CACHE}" ] ; then
    ErrExit ${EX_SOFTWARE} "CREATEREPO_CACHE: empty"
  fi
  if [ ! -d ${CREATEREPO_CACHE} ] ; then
    Rc ErrExit ${EX_OSFILE} "mkdir -p ${CREATEREPO_CACHE}  2>&1"
  fi

  # configure per-db repository
  repo_d=$(findmnt -n -k -l --output TARGET ${COMMON}/repos | sort | uniq)
  if [ -z "${repo_d}" ] ; then
    repo_d=${COMMON}/repos
  fi
  if [ ! -d "${repo_d}" ] ; then
    ErrExit ${EX_CONFIG} "repo_d:${repo_d} not a directory"
  fi

  #if ${COMMON}/repos is not a mount point, is on a different device from root and isn't NFS,
  #then point a symlink at the location of the actual repositories from COMMON/repos -> repo_d
  local repos_fstype=$(stat -f --format="%T" ${COMMON}/repos)
  local repos_fsid=$(stat -f --format="%i" ${COMMON}/repos)
  local root_fsid=$(stat -f --format="%i" /)
  local repos_ismnt=$(findmnt -n -k --output TARGET ${COMMON}/repos)
  local repos_source=$(findmnt -n -k --output SOURCE ${COMMON}/repos)
  local yum_action=enable

  if [ -n "${repos_ismnt}" -a "${repos_fstype}" = "xfs" -a -b "${repos_source}" ] ; then
    yum_action=disable
  fi

  if [ -z "${repos_ismnt}" -a "${repos_fsid}" != "${root_fsid}" -a "${repos_fstype}" != "nfs" ] ; then
    if [ "${repo_d}" != "${COMMON}/repos" ] ; then
      Rc ErrExit ${EX_SOFTWARE} "ln -s -f ${repo_d} ${COMMON}/repos"
    fi
  fi

  repo_root=${repo_d}/${WHICH_DB}
  Verbose " ${WHICH_DB}"
  repo_is_local=$(egrep "${COMMON}/repos.* xfs" ${ETCFSTAB})

  # yum will attempt to validate and update cache data for all repositories, whether enabled or not
  # disable or move inactive ones aside
  local _rlist="local-mariadb-main local-mariadb-tools local-mariadb-es-main  \
                  mariadb-es-main mariadb-main mariadb-tools                  \
                  mysql80-community"

  for r in ${_rlist}
  do
    Rc ErrExit ${EX_OSERR} "yum-config-manager --${yum_action} ${r}"
  done

  case "${WHICH_DB}" in
    mariadb-enterprise)
      ## @todo XXX subfunction which deselects all but WHICH_DB repositories
      Verbose " - mariadb-community community-mysql"
      for o in mariadb-community-local mysql-community mysql-community-source
      do
        local f
        f=${YUM_REPOS_D}/${o}.repo
        if [ -f ${f} ] ; then
          Rc ErrExit ${EX_OSERR} "mv ${f} ${f}~"
        fi
      done
      Verbose "   ConfigureDBMariaEnterpriseRepo"
      ConfigureDBMariaEnterpriseRepo
      ;;
    mariadb-community)
      Verbose " - mariadb-enterprise community-mysql"
      local o
      for o in mariadb-enterprise-local mysql-community mysql-community-source
      do
        local f
        f=${YUM_REPOS_D}/${o}.repo
        if [ -f ${f} ] ; then
          Rc ErrExit ${EX_OSERR} "mv ${f} ${f}~"
        fi
      done
      Verbose "   ConfigureDBMariaCommunityRepo"
      ConfigureDBMariaCommunityRepo
      ;;
    community-mysql)
      Verbose " - mariadb-enterprise mariadb-community"
      local o
      for o in mariadb-enterprise-local mariadb-local
      do
        local f
        f=${YUM_REPOS_D}/${o}.repo
        if [ -f ${f} ] ; then
          Rc ErrExit ${EX_OSERR} "mv ${f} ${f}~"
        fi
      done
      Verbose "   ConfigureDBCommunityMysqlRepo"
      ConfigureDBCommunityMysqlRepo
      ;;
    *)
      ErrExit ${EX_CONFIG} "which_db:${WHICH_DB} unimplemented?"
      ;;
  esac
  if [ -z "${SKIP_YUMDOWNLOAD}" ] ; then
    Verbose "   yum update"
    Rc ErrExit ${EX_OSERR} "${YUM} -y update"
  fi
  if [ -n "${DEBUG}" ] ; then
    Verbose " Repository List:"
    ${YUM} repolist
  fi
  return
}

## @fn CopyCommon()
##
CopyCommon() {
  local size
  local from=/${CLUSTERNAME}/common
  local to=/home${from}
  local skip=""
  local to_fstype=""

  if [ -L "${VC}" ] ; then
    ErrExit ${EX_OSFILE} "${VC}: symlink"
  fi
  if [ -L "${to}" ] ; then
    Verbose "  to:${to}: symlink, skipped"
    skip="true-symlink"
  fi
  if [ -d "${to}" -o -L "${to}" ] ; then
    to_fstype=$(stat -f --format "%T" ${to})
  fi
  if [ "${to_fstype}" = "nfs" ] ; then
    skip="true-nfs-to"
  fi
  if [ -z "${skip}" ] ; then
    size=$(du -x -s -m ${from} --exclude=repos\* | awk 'BEGIN {total=0} {total += $1} END {print total}')
    Verbose " ${size}Mb  ${from} => ${to}"

    Rc ErrExit ${EX_OSFILE} "mkdir -p ${to}"
    Rc ErrExit ${EX_SOFTWARE} "tar -cf - -C ${from} . | \
                              (cd ${to}; tar ${TAR_LONG_ARGS} -${TAR_DEBUG_ARGS}${TAR_ARGS}f -)"
  fi
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

  Rc ErrExit ${EX_OSFILE} "mkdir -p ${REPO_MOUNT}"

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

  already_msg=""
  partition_exists=$(parted -s ${REPO_DISK} "print" 2>&1 | grep xfs)
  exists_rc=$?
  mounted=""
  if [ "${exists_rc}" -ne 0 ] ; then
    partition_exists=""
    mounted=$(findmnt -n -k -l --output TARGET ${REPO_MOUNT} | sort | uniq)
  else
    if [ -z "${partition_exists}" -a -n "${mounted}" ] ; then
      Warn ${EX_OSERR} "${REPO_MOUNT} is mounted, but partition does not appear to exist anymore."
      Rc ErrExit ${EX_OSERR} "umount -f ${REPO_MOUNT}"
      mounted=$(findmnt -n -k -l --output TARGET ${REPO_MOUNT} | sort | uniq)
    fi
  fi
  if [ -z "${mounted}" -a \( ! -b "${REPO_PART}" -o -z "${partition_exists}" \) ] ; then
    Rc ErrExit ${EX_CONFIG} "parted -s ${REPO_DISK} --align opt mklabel gpt 2>&1 </dev/null   ;"
    # end=100% sets the end to the maximum partition size as defined by the virtualization provider, often 2Tb 
    Rc ErrExit ${EX_CONFIG} "parted -s ${REPO_DISK} mkpart primary 2048s 100% 2>&1 </dev/null ;"
  fi
  if [ -z "${partition_exists}" ] ; then
    Rc ErrExit ${EX_CONFIG} "mkfs.xfs -f -L repos ${REPO_PART} 2>&1"
  else
    already_msg="(already exists"
    # The following forces any outstanding log writes to be sync'd and is the recommended guidance
    # to make a dirty XFS file system clean.
    Rc ErrExit ${EX_CONFIG} "findmnt -n -k -l ${REPO_MOUNT} || mount -t xfs ${REPO_PART} ${REPO_MOUNT}"
    still_in_use=$(lsof | grep -i cwd | awk '{print $9}' | grep '/' | sort | uniq | egrep "^${REPO_MOUNT}")
    if [ -z  "${still_in_use}" ] ; then
      Rc ErrExit ${EX_CONFIG} "umount -f ${REPO_PART}"
    fi
  fi

  mounted=$(findmnt -n -k -l --output TARGET ${REPO_MOUNT} | sort | uniq)
  rc=$?
  if [ "${mounted}" = "${REPO_MOUNT}" ] ; then
    if [ -z "${already_msg}" ] ; then
      already_msg="(already mounted"
    else
      already_msg="${already_msg}, mounted"
    fi
  fi
  if [ -n "${already_msg}" ] ; then
    already_msg="${already_msg})"
  fi
  in_fstab=$(findmnt -n -l -s ${REPO_PART} | sort | uniq)
  if [ -n "${in_fstab}" ] ; then
    echo "${REPO_PART}  ${REPO_MOUNT}  xfs rw,defaults,noatime,async,nobarrier 0 0" >> ${ETCFSTAB}
  fi

  mounted=$(findmnt -n -k -l ${REPO_MOUNT} | sort | uniq)
  if [ -z "${mounted}" ] ; then
    Rc ErrExit ${EX_SOFTWARE} "mount -t xfs -o rw,defaults,noatime,async,nobarrier ${REPO_PART} ${REPO_MOUNT}"
  fi
  Verbose " ${REPO_PART} ${REPO_MOUNT} ${already_msg}"
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
    Rc ErrExit ${EX_SOFTWARE} "cd /; sync; umount -f ${VC}; rmdir ${VC}; ln -s ${HOMEVAGRANT}"
  fi
  return
}

## @fn TidyDetritus()
## @brief remove installation artifacts, leave a convenience link in /${BASEDIR}
##
TidyDetritus() {
  for d in bin env flag inc lib loader
  do
    if [ -d /common/provision/${d} ] ; then
      Rc ErrExit ${EX_OSFILE} "rmdir /common/provision/${d}"
    fi
  done
  if [ -d "/${CLUSTERNAME}" -a ! -L /${CLUSTERNAME} ] ; then
    Rc Warn ${EX_OSFILE} "rmdir /${CLUSTERNAME}"
  fi
  if [ ! -L "/${CLUSTERNAME}" ] ; then
    if [ ! -d "/${CLUSTERNAME}" ] ; then
      if [ -d "/home/${CLUSTERNAME}" ] ; then
        Rc ErrExit ${EX_OSFILE} "ln -s -f /home/${CLUSTERNAME} /${CLUSTERNAME}"
      fi
    fi
  fi
  return
}


## @fn UnmountProvisioningFS()
##
UnmountProvisioningFS() {
  nfs_server=$(awk '/virtual-cluster-net/ {print $2}' /etc/networks | sed 's/0$/1/')

  if [ -n "${PREVENT_SLASHVAGRANT_MOUNT}" ] ; then
    local opwd=$(pwd)
    cd /
    # 32 = (u)mount failed
    # only touch the flagfile if we haven't unmounted /${BASEDIR} ("/vagrant")
    # XXX findmnt, provided its dependencies aren't a twisty little maze
    awk '{print $5}' < ${MOUNTINFO} | egrep -s "${VC}|${BASEDIR}" >/dev/null 2>&1
    rc=$?

    fstype=$(stat -f --format "%T" ${BASEDIR})
    if [ ${rc} -eq ${GREP_FOUND} ] ; then
      for c in 4.sync-NTP tee
      do
        for s in HUP TERM KILL
        do
          pgrep -u root --signal ${s} ${c} >/dev/null 2>&1
          rc=$?
          # 1 = no processes signalled or matched
          if [ "${rc}" -eq "1" ] ; then
            break
          fi
          sleep 0.5
        done
        pkill -u root ${c} >/dev/null 2>&1
        sleep 0.5
      done

      still_in_use=$(lsof | grep -i cwd | awk '{print $9}' | grep '/' | sort | uniq | egrep "^/${BASEDIR}")
      needs_umount=$(findmnt -m | egrep "${nfs_server}|vboxsf" | awk '{print $1}' | sort -r)
      if [ -n "${still_in_use}" ] ; then
        Verbose " /${BASEDIR} is still in use. (${still_in_use})"
        Verbose " umount skipped."
      else
        any_failed_unmounts=""
        for m in ${needs_umount}
        do
          Rc ErrExit ${EX_OSFILE} "sync"
          Rc Warn ${EX_OSFILE} "umount -f ${m} >/dev/null 2>&1"
          rc=$? 
          if [ ${rc} -ne ${EX_OK} ] ; then
            any_failed_unmounts="${any_failed_unmounts} ${m}"
          fi
          if [ -z "${any_failed_unmounts}" ] ; then
            if [ "${fstype}" != "nfs" -a "${fstype}" != "vboxsf" -a -n "${flagfile}" ] ; then 
              Rc ErrExit ${EX_OSFILE} "cd ${VC}; touch ${flagfile}; chmod 0 ${flagfile}"
            fi
          fi
        done
        if [ -z "${any_failed_unmounts}" ] ; then
          for m in ${needs_umount}
          do
            fstype=$(stat -f --format "%T" ${m} 2>/dev/null)
            if [ ! -d "${m}" -o -L "${m}" -o \( "${fstype}" != "nfs" -a "${fstype}" != "vboxsf" \) ] ; then 
              continue
            fi
            Rc ErrExit ${EX_OSFILE} "umount -f ${m} >/dev/null 2>&1"
          done
          for m in ${needs_umount}
          do
            if [ -d "${m}" -a ! -L "${m}" ] ; then
              Rc ErrExit ${EX_OSFILE} "rmdir /${m}"
            fi
          done
        fi
      fi
    else
      if [ "${fstype}" != "nfs" -a "${fstype}" != "vboxsf" -a -n "${flagfile}" ] ; then 
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
  if [ ! -L "/vagrant" ] ; then
    if [ ! -d "/vagrant" ] ; then
      Rc ErrExit ${EX_OSFILE} "ln -s -f ${HOMEVAGRANT} /vagrant"
    fi
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
      sync
      umount -f ${m} >/dev/null 2>&1
    fi
  done

  local mem=$(expr $(grep -i MemTotal ${MEMINFO} | awk '{print $2}') / 1024)
  local procs=$(grep -i processor ${CPUINFO} | wc -l)
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
  local anynfs

  anynfs=$(grep nfs ${ETCFSTAB})
  if [ -n "${anynfs}" ] ; then
    Verbose "  fstab:"
  fi
  while read _dev _mnt _fstyp _options _check _dump
  do
    if [[ ${_dev} =~ ^# ]] ; then
      continue
    fi
    if [[ ${_fstyp} =~ nfs ]] ; then
      if [ ! -d ${_mnt} -a ! -L ${_mnt} ] ; then
        Verbose "    ${_mnt}"
        Rc ErrExit ${EX_OSFILE} "mkdir -p ${_mnt}"
      fi
    fi
  done < ${ETCFSTAB}

  if [ -s ${ETCEXPORTS} -a -r ${ETCEXPORTS} ] ; then
    Verbose "  exports:"
    while read _mnt _args
    do
      if [[ ${_mnt} =~ ^# ]] ; then
        continue
      fi
      if [ ! -d ${_mnt} ] ; then
          Verbose "    ${_mnt}"
          Rc ErrExit ${EX_OSFILE} "mkdir -p ${_mnt}"
      fi
    done < ${ETCEXPORTS}
  fi
  return
}

## @fn InstallRPMS()
##
InstallRPMS() {
  local early=${1:-"_not_early_rpms_"}
  local which=${1:-""}
  local timeout
  local rpms_add=""
  local rpms_rm=""
  local _rpms_add
  local _r
  local _disable_repo=""
  local _need_clean=""
  local rpms_manifest="${RPM}/${which}/RPMS.Manifest"
  local manifest_src_d=${XFR}/repos/centos/7/os/${ARCH}/Packages
  local manifest_list=""

  case "${which}" in
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
    	    timeout=${YUM_TIMEOUT_EARLY}
          if [ -n "${YUM_LOCALREPO_DEF}" -a -n "${LOCAL_REPO_ID}" -a -f "${YUM_LOCALREPO_DEF}" ] ; then
            ## if all of the early RPMS have no dependencies, this could be:
            ## _disable_repo=" --disablerepo=\* "
            ## but that may change based on however the upstream-supplied RPMs are built
            _disable_repo=" --disablerepo=${LOCAL_REPO_ID} "
          fi
	    ;;

  local)
    	timeout=${YUM_TIMEOUT_BASE}
	    ;;

  flagged)
    ## collect flags
      local f

  	  timeout=${YUM_TIMEOUT_INSTALL}
      if [ ! -d ${RPM}/${which} ] ; then
        return
      fi

      flag_d=$(echo $(find ${RPM}/${which} -maxdepth 1 -type d))
      for f in ${flag_d[@]}
      do
        local _f=$(basename ${f})
        if [ "${_f}" = "." ] ; then
          continue
        fi
        if [ "${_f}" = "${which}" ] ; then
          continue
        fi
        if [ -z "${!_f}" ] ; then
          continue
        fi

        local _flag=$(basename ${!_f})
        local _d=${f}/${_flag}
        local rpms_rmdir=""

        if [ -d ${_d}/add ] ; then
          rpms_manifest=${d}/add/RPMS.Manifest
          if [ -s ${rpms_manifest} ] ; then
            manifest_list=$(echo $(cat ${rpms_manifest}))
            rpms_add="${manifest_list}"
          else
            rpms_add=$(echo $(ls ${_d}/add))
          fi
        fi
        rpms_rmdir=${_d}/rm
        if [ -d ${rpms_rmdir} ] ; then
          rpms_rm=$(echo $(cd ${rpms_rmdir}; ls))
        fi
      done
      if [ -z "${rpms_add}" -a -z "${rpms_rm}" ] ; then
        return
      fi
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
    Rc ErrExit ${EX_SOFTWARE} "${YUM} -y clean metadata"
  fi
  ## do removes first in case they are being removed due to installation conflicts
  if [ -n "${rpms_rm}" ] ; then
    Rc Warn ${EX_IOERR} \
      "timeout ${timeout} ${YUM} ${_disable_repo} --disableplugin=fastestmirror -y remove ${rpms_rm}"
  fi

  ## collect list of rpms, if it isn't set already
  ## This list may either be a manifest, string subset of rpm names, or actual rpms
  ## If it appears to be an actual RPM, we will attempt to localinstall it rather than reach out to a remote repo

  if [ -s "${rpms_manifest}" ] ; then
    manifest_list=$(echo $(cat ${rpms_manifest}))
    rpms_add=""
    local r
    if [ ! -d "${manifest_src_d}" ] ; then
      ErrExit ${EX_CONFIG} "manifest_src_d:${manifest_src_d} not a directory"
    fi
    for r in ${manifest_list}
    do
      local _r
      _r=$(echo ${manifest_src_d}/${r}*.rpm)
      if [ -f "${_r}" ] ; then
        rpms_add="${rpms_add} ${_r}"
      fi
    done
  fi

  if [ -n "${manifest_list}" ] ; then
    if [ ! -d ${manifest_src_d} ] ; then
      ErrExit ${EX_CONFIG} "RPMS.Manifest specified; manifest_src_d:${manifest_src_d} not a directory"
    fi

    Verbose "  Manifest source: ${manifest_src_d}"
  fi

  if [ -z "${rpms_add}" ] ; then
    rpms_add=$(echo $(ls ${RPM}/${which} | egrep -v 'README|RPMS.Manifest'))
  fi
  # _rpms_add, _rpms_localinstall used to construct msg and cmd
  _rpms_add=""
  _rpms_localinstall=""
  _rpms_msg=""
  for _r in ${rpms_add}
  do
    local nm=${_r//-[0-9].*/}
    _rpms_msg="${_rpms_msg} $(basename ${nm})"
    # if this appears to be an actual RPM, then do a localinstall
    if [[ ${_r} = *.rpm ]] ; then
      _rpms_localinstall="${_rpms_localinstall} ${_r}"
      #_rpms_localinstall="${_rpms_localinstall} ./${_r}"
      #XXX _rpms_localinstall="${_rpms_localinstall} \"./${_r}\"" -- if RPM contains a shell meaningful character like parentheses in perl rpms
    else
      _rpms_add="${_rpms_add} ${_r}"
    fi
  done

  Verbose " ${_rpms_msg}"

  rpms_add=${_rpms_add}
  localinstall_add=${_rpms_localinstall}
  ## Attempt to do a bulk installation.
  ## @todo If that fails, proceed with each one singly to capture the failure.
  if [ -n "${localinstall_add}" ] ; then
    export _d=${RPM}/${which}
    if [ -n "${manifest_list}" ] ; then
      _d=${manifest_src_d}
    fi

    Rc Warn ${EX_IOERR} "cd ${_d}; \
       timeout ${timeout} ${YUM} ${_disable_repo} --disableplugin=fastestmirror -y localinstall ${localinstall_add}"
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
      Rc ErrExit ${EX_SOFTWARE} "${YUM} -y clean metadata && ${YUM} -y upgrade"
    fi
    if [ -x $(which yumdownloader) ] ; then
      Rc ErrExit ${EX_IOERR} "timeout ${timeout} yumdownloader --resolve --destdir=${RPM}/${which} --archlist=${ARCH} \"${r}\" ; "
    else
      ## change the downloaddir to the local repo (${COMMON}/repos) rather than remain in the configuration tree
      Rc ErrExit ${EX_IOERR} "timeout ${timeout} ${YUM} ${_disable_repo} --downloadonly --downloaddir=${RPM}/${which} --disableplugin=fastestmirror install \"${r}\" ; "
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
      if [ -z "${_disable_repo}" -a -f "${YUM_LOCALREPO_DEF}" -a -n "${LOCAL_REPO_ID}" ] ; then
        _which_repos="--disablerepo=\* --enablerepo=local-base,local-updates,${LOCAL_REPO_ID}"
        #_which_repos="--enablerepo=local-base,local-updates,${LOCAL_REPO_ID}"
      else
        _which_repos="--disablerepo=\* --enablerepo=local-base,local-updates"
        #_which_repos="--enablerepo=local-base,local-updates"
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

## @fn BaselineYumRepos
##
BaselineYumRepos() {
  ## reset all repos to disabled, except for CentOS base and updates, so that early RPMS may be installed
  ## don't use yum-config-manager as yum utilities are susceptible to breakage if repos are inconsistent
  local repolist=$(ls ${YUM_REPOS_D}/*.repo | egrep -v 'CentOS-Base.repo')
  local msg="   -"
  for repofile in ${repolist}
  do
    msg="${msg} $(basename ${repofile})"
    Rc ErrExit ${EX_SOFTWARE} "sed -i -e '/^enabled[[:space:]]*=[[:space:]]*1/s/1/0/' ${repofile} ;"
  done
  Verbose "${msg}"
  return
}

## @fn InstallEarlyRPMS()
##
InstallEarlyRPMS() {
  Verbose "  BaselineYumRepos"
  BaselineYumRepos
  InstallRPMS early $@
  return
}

## @fn InstallFlaggedRPMS()
##
InstallFlaggedRPMS() {
  InstallRPMS flagged $@
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
    # AddUserAccount() is in lib/useradd.sh 
    AddUserAccount ${USERADD}/${u}
  done  # u in ${users_add}

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
  rc=$?
  if [ ${GREP_NOTFOUND} -eq ${rc} ] ; then
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
        if [[ "${virt_type}" != *virtualbox* ]] ; then
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

  repo_fstype=$(stat -f --format="%T" $(${YUM} repoinfo local-base | grep Repo-baseurl | sed 's/Repo-baseurl.*:.*file://'))
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
      Rc ErrExit ${EX_IOERR} "timeout ${YUM_TIMEOUT_UPDATE} ${YUM} --disableplugin=fastestmirror --disablerepo=\* --enablerepo=local-base,local-updates,${LOCAL_REPO_ID} -y update"
    else
      Rc ErrExit ${EX_IOERR} "timeout ${YUM_TIMEOUT_UPDATE} ${YUM} --disableplugin=fastestmirror --disablerepo=\* --enablerepo=local-base,local-updates -y update"
    fi
  fi

  return
}

## @fn TimeSinc()
##  Adjust TIMEOUTs based upon SINC
##
TimeSinc() {
  local Znumeric="[1-9]"
  local Z0numeric="[0-9]"
  local _v=""

  for _v in SINC NESTED_VIRT_COEF
  do
    if [[ ! ${!_v} = ${Znumeric} ]] ; then
      ErrExit ${EX_CONFIG} "  ${_v}:${!v} is not: ${Znumeric}"
    fi
  done

  export DEFAULT_TIMEOUT=$(expr ${SINC} \* ${NESTED_VIRT_COEF})
  export YUM_TIMEOUT_BASE=$(expr 20 \* ${SINC} \* ${NESTED_VIRT_COEF})
  export YUM_TIMEOUT_EARLY=$(expr ${YUM_TIMEOUT_BASE} \* 12)
  export YUM_TIMEOUT_INSTALL=$(expr ${YUM_TIMEOUT_BASE} \* 24)
  export YUM_TIMEOUT_UPDATE=$(expr ${YUM_TIMEOUT_BASE}  \* 56)
  export RSYNC_TIMEOUT_DRYRUN=$(expr ${YUM_TIMEOUT_BASE} / 2)
  export RSYNC_TIMEOUT=$(expr ${YUM_TIMEOUT_BASE} \* 2)
  export TIMEOUT=${DEFAULT_TIMEOUT}

  if [ "${NESTED_VIRT_COEF}" -gt 1 ] ; then
    Verbose " NESTED_VIRT_COEF:${NESTED_VIRT_COEF} > 1, timeouts increased"
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
  local stop_flag=".stop"

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
    build)   where=${BUILDWHERE}/${_s}; verify="ls -R ${COMMON_LOCALREPO}"         ;;
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
      if [ -f ${what}/${_s}/${stop_flag} ] ; then
        ErrExit ${EX_SOFTWARE} "${what}/${_s}/${stop_flag} present"
      fi
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

          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; bash -u ${exe} ${out}"
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
  local ARCH=$(uname -m)

  for d in ${LOCALREPO} ${COMMON_LOCALREPO}
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

  if [ ! -d "${COMMON_LOCALREPO}/${ARCH}/repodata" -o ! -f "${COMMON_LOCALREPO}/${ARCH}/repodata/repomd.xml" ] ; then
    if [ -x "${CREATEREPO}" ] ; then
      Verbose " ${CREATEREPO} COMMON_LOCALREPO:${COMMON_LOCALREPO}"
      Rc ErrExit ${EX_OSFILE} "mkdir -p /run/createrepo/cache"
      local n_workers=$(ls /${CLUSTERNAME}/cfg/${HOSTNAME}/attributes/procs/)
      local workers="--workers ${n_workers}"
      local cache="--cachedir /run/createrepo/cache"
      Rc ErrExit ${EX_OSERR} "${CREATEREPO} ${workers} ${cache} ${COMMON_LOCALREPO}/${ARCH}"
    fi
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
    local multiple=""
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
          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; bash -u ${_x} ${out} "
          _rc=$?
        else
          Rc Warn ${EX_SOFTWARE} "cd ${workdir}; runuser -u ${u} -- bash -u -c \"${script_thisdir}${_x} > ${out}\" "
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
          Rc ErrExit ${EX_OSFILE} "rm -f ${out} >/dev/null 2>&1"
        else
          ClearNodeState "${STATE_PROVISIONED}"
          ClearNodeState "${STATE_NONEXISTENT}"
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
  Verbose "  "
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
