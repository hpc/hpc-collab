#!/bin/bash

## $Header: $
## Source: https://git.lanl.gov/hpc/wlm/blob/master/scripts-n-stuff/stash_jobscripts.sh
## @file stash_jobscripts.sh
## @author LANL/HPC/ENV/WLM/sts Steven Senator sts@lanl.gov

## @page Copyright
## <h2>© 2019. Triad National Security, LLC. All rights reserved.</h2>
## &nbsp;
## <p>This program was produced under U.S. Government contract 89233218CNA000001
## for Los Alamos National Laboratory (LANL), which is operated by Triad National Security, LLC
## for the U.S. Department of Energy/National Nuclear Security Administration.</p>
## <p>All rights in the program are reserved by Triad National Security, LLC, and the
## U.S. Department of Energy/National Nuclear Security Administration. The US federal Government
## is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable
## worldwide license in this material to reproduce, prepare derivative works, distribute copies
## to the public, perform publicly and display publicly, and to permit others to do so.</p>
## <p>The public may copy and use this information without charge, provided that this Notice
## and any statement of authorship are reproduced on all copies. Neither the Government
## nor Triad National Security, LLC makes any warranty, express or implied, or assumes any
## liability or responsibility for the use of this information.</p>
## <p>This program has been approved for release from LANS by LA-CC Number 10-066, being part of
## the HPC Operational Suite.</p>
## &nbsp;
##

declare -x RETRY_LIMIT="7"
declare -x ERREXIT_PRINT_CALL_STACK=${ERREXIT_PRINT_CALL_STACK:-"true"}

# see ParseArgs(): -D = debug, -j record existing jobs, -m monitor jobs
declare -x DEFAULT_DEBUG_ARGS="-D -j -m"
declare -x DEFAULT_NODEBUG_ARGS="-j -m"
declare -x DEFAULT_ARGS=${DEFAULT_NODEBUG_ARGS}

declare -x PG_DEPTH_LIMIT=${RETRY_LIMIT}
declare -x PG_DEPTH=${PG_DEPTH:-"0"}
# set the process group id if it is unset
declare -x PGID=${PGID:-$(($(ps -o pgid= -p "$$")))}

declare -x LOG_TO_STDERR=${LOG_TO_STDERR:-""}
declare -x TRAP_NOISY=${TRAP_NOISY:-"true"}
declare -x DEBUG=${DEBUG:-"true"}

declare -x LOCAL_PATH=":/usr/local/sbin:/usr/local/bin"
declare -x CRAY_PATH=""

# As the contents of a script may include sensitive data, the contents of this variable are included in each record
# so that it is clear to the consumer that an appropriate security review must be done
declare -x SENSITIVITY_NOTICE=${SENSITIVITY_NOTICE:-"Notice: These contents are not cleared for release. Content review is required."}

# How we store the job script, a function name to invoke
RECORD="Log"

## see Log(), setebug, VerifyEnv
declare -x DEFAULT_OUTPUT_PROTOCOL=${DEFAULT_OUTPUT_PROTOCOL:-"syslog-remote"}
declare -x DEFAULT_CRAY_OUTPUT_PROTOCOL=${DEFAULT_CRAY_OUTPUT_PROTOCOL:-"syslog"}

# see TidyUp()
declare -x LEAVE_BREADCRUMB_PROCS=${LEAVE_BREADCRUMB_PROCS:-"parent_signals_all"}

## local, this is interpreted as a parameter @see TidyUp() so must be no spaces in the value
declare -x TIDYUP_FORCE="ignore_LEAVE_BREADCRUMBS"
declare -x TIDYUP_LOCK=""

## Exit codes and their names
declare -x ORIGPWD=""

## @see Authoritative exit codes: <tt>/usr/include/sysexits.h</tt>
## @see Signals [Linux-specific]: <tt>/usr/include/bits/signum.h</tt>
## @see Errno's [Linux/ASM-specific]<tt>/usr/include/asm-generic/errno.h</tt>
## @see tldp.org et. al. for SIGBASE

declare -A ExitCodeNames
## The operation worked.
declare -x EXIT_OK=0
declare -x EX_OK=${EXIT_OK}
## the first error code in the common list of sysexits
declare -x EX__BASE=64
## The command was used incorrectly.
declare -x EX_USAGE=64
## The input data was incorrect.
declare -x EX_DATAERR=65
## An input file did not exist or was unreadable.
declare -x EX_NOINPUT=66
## The user specified did not exist.
declare -x EX_NOUSER=67
## The host specified did not exist.
declare -x EX_NOHOST=68
## A service is unavailable.
declare -x EX_UNAVAILABLE=69
## An internal software error has been detected.
declare -x EX_SOFTWARE=70
## An operating system error has been detected.
declare -x EX_OSERR=71
## Some system file does not exist or may not be accessed.
declare -x EX_OSFILE=72
## An output file cannot be created.
declare -x EX_CANTCREAT=73
## An error occurred while doing I/O.
declare -x EX_IOERR=74
## A temporary failure occurred. Reattempts may succeed.
declare -x EX_TEMPFAIL=75
## The remote system connection setup failed.
declare -x EX_PROTOCOL=76
## The user does not have authority to perform an action.
declare -x EX_NOPERM=77
## A configuration is missing or incorrect.
declare -x EX_CONFIG=78
## Maximum error code (not really)
declare -x EX__MAX=78
## Already mounted, already connected, already done
declare -x EX_ALREADY=114
## fatal signal exit = EX_SIGBASE+&lt;signal-number&gt;
declare -x EX_SIGBASE=128

## User (SysAdmin) courtesy: to emit the name of the exit code
declare -A ExitCodeNames
ExitCodeNames[${EXIT_OK}]='EXIT_OK'
ExitCodeNames[${EX_USAGE}]='EXIT_OK'
ExitCodeNames[${EX_DATAERR}]='EX_DATAERR'
ExitCodeNames[${EX_NOINPUT}]='EX_NOINPUT'
ExitCodeNames[${EX_NOUSER}]='EX_NOUSER'
ExitCodeNames[${EX_NOHOST}]='EX_NOHOST'
ExitCodeNames[${EX_UNAVAILABLE}]='EX_UNAVAILABLE'
ExitCodeNames[${EX_SOFTWARE}]='EX_SOFTWARE'
ExitCodeNames[${EX_OSERR}]='EX_OSERR'
ExitCodeNames[${EX_OSFILE}]='EX_OSFILE'
ExitCodeNames[${EX_CANTCREAT}]='EX_CANTCREAT'
ExitCodeNames[${EX_IOERR}]='EX_IOERR'
ExitCodeNames[${EX_TEMPFAIL}]='EX_TEMPFAIL'
ExitCodeNames[${EX_PROTOCOL}]='EX_PROTOCOL'
ExitCodeNames[${EX_NOPERM}]='EX_NOPERM'
ExitCodeNames[${EX_CONFIG}]='EX_CONFIG'
#ExitCodeNames[${EX__MAX}]='EX__MAX' = EX_CONFIG
ExitCodeNames[${EX_ALREADY}]='EX_ALREADY'
ExitCodeNames[${EX_SIGBASE}]='EX_SIGBASE'

declare -x SHOW_CONFIG=""

declare -x HOSTNAME=$(hostname -s)
declare -x IAM=$(basename $0 .sh)
declare -x IAMFULL=${0}
declare -x STATESAVELOC=""
declare -x LOCK_SUFFIX=/.${IAM}.lock

# see Log()
# Note: actual limit varies between 4096 and ~8050 [syslog] (depends upon OUTPUT_PROTOCOL and syslog configuration)
declare -x MAX_RELIABLE_MSGSIZE=4096
declare -x LOG_MSGSIZE=3584

## @fn printCallStack(void)
## prints the bash function call stack. It is not re-entrant.
## It must not call other functions that could then call ErrExit() or itself.
## @note Much of this function is clipped from various bash shell debugging sites.
## This function is separable, was not authored by a Triad or LANL employee and
## is not copyrightten Triad nor by Los Alamos National Lab.
## @param ORIGPWD
## \callergraph
##
printCallStack() {

    # This may miss the bottom-most func, if it was called via eval
     local i=0
     local stackframes=${#BASH_LINENO[@]}
     # stackframes-2 skips main
     for (( i=stackframes-2 ; i>=0; i--))
     do
        echo -n "${BASH_SOURCE[i+1]}: ${BASH_LINENO[i]}, ${FUNCNAME[i+1]}(): "
        head -${BASH_LINENO[i]} < ${ORIGPWD}/${BASH_SOURCE[i+1]} | tail -1
     done
     return
}

## @fn Trap()
## declares an exit and interrupt trap, calls TidyUp with its arguments
## @param fileName
## @param TRAP_NOISY
## @param DEBUG
## @todo return (SIGBASE + &lt;signal number&gt;) when != EX_OK
## @return void
## \callgraph
## \callergraph
##
Trap() {
  local trap_cmd=""
  local notdebug_sigs="HUP TERM CHLD"
  local debug_sigs="HUP INT QUIT ILL BUS ABRT TERM STKFLT CHLD"
  local sigs=""
  local args=$@

  sigs=${debug_sigs}
  [ -z "${DEBUG}" ]  && sigs=${notdebug_sigs}

  if [ -n "${TRAP_NOISY}" ] ; then
    trap "echo -n \"[Trap()]: TidyUp ${args}\"; TidyUp ${args}; exit" EXIT ${sigs}
  else
    trap "TidyUp ${args}; exit" EXIT ${sigs}
  fi
  return
}

## @fn LogChunks()
##  Drop in replacement for logger command, but chunks the message into no larger than
##  LOG_MSGSIZE chunks, adding in header and footer information for reassembly
##
LogChunks() {
  local loggerArgs=""
  local tag_base

  while ! [[ ${1} = -- ]] ; do
    case "${1}" in
    "-S")
        shift
        local sz=${1}
        if ! [[ "${sz}" =~ [0-9]+$ ]] ; then
          printf "non-numeric log message size: ${1}\n"
          exit ${EX_SOFTWARE}
        fi
        loggerArgs="-S ${sz}"
        ;;
    "-t")
        shift
        tag_base="${1}"
        ;;
     *)
        printf "unknown option: $1"
        exit ${EX_SOFTWARE}
        ;;
    esac
    shift
  done
  shift

  local remainder_sz=0
  local chunk_begin=0
  local seqno=0

  msg="$@"
  msg_sz=${#msg}
  remainder_sz=${msg_sz}
  chunk_begin=0
  (( seqno=0 ))

  while (( ${remainder_sz} > 0 )) ; do
     local chunk=""
     local chunk_end=0
     local length=0

    if (( ${remainder_sz} < ${LOG_MSGSIZE} )) ; then
      (( length=${remainder_sz} ))
    else
      (( length=${LOG_MSGSIZE} ))
    fi

    (( chunk_end=${chunk_begin} + ${length} ))
    chunk="${msg:${chunk_begin}:${chunk_end}}"
    tag="${tag_base}${seqno}]"
    logger -t "${tag}" ${loggerArgs} -- "${chunk}"
    (( seqno++ ))
    (( chunk_begin=${chunk_end} ))
    (( remainder_sz=${remainder_sz} - ${length} ))
    if (( ${remainder_sz} < 0 )) ; then
      (( remainder_sz=0 ))
    fi
  done
  return
}

## @fn Log()
## emit a message to to stderr & syslog
## @param ErrorMessage
## @param BASHPID
## @param IAM
## @param LOG_TO_STDERR
## @param LOG_MSGSIZE
## @return void
## \callgraph
## \callergraph
##
Log() {
  local pgid=$(($(ps -o pgid= -p "$$")))
  local tag="${IAM}[${HOSTNAME%%-master},${pgid},${BASHPID},"
  local loggerArgs=""
  local flush=${1}
  local suffix="-- $@"
  local JOBID=""

  if [[ ${1} =~ JOBID= ]] ; then
    tag="${IAM}[${HOSTNAME}:${1#JOBID=}:"
  fi

  [ -n "${LOG_TO_STDERR}" ] && loggerArgs="${loggerArgs} -s "

  if [[ ${OUTPUT_PROTOCOL} == syslog ]] ; then
      LogChunks -t "${tag}" -S ${LOG_MSGSIZE} ${loggerArgs} ${suffix}

  elif [[ ${OUTPUT_PROTOCOL} == syslog-remote ]] ; then
    logger ${loggerArgs} -P 514 --tcp -n ${OUTPUT_HOST} ${suffix}
    if [ $? -ne 0 ] ; then
      printf "logger(syslog-remote) failed: ${loggerArgs} -P 514 --tcp -n ${OUTPUT_HOST}"
      exit ${EX_SOFTWARE}
    fi

  elif [[ ${OUTPUT_PROTOCOL} == stdout ]] ; then
    echo $@

  elif [[ ${OUTPUT_PROTOCOL} == amqp ]] ; then
    echo $@ | amqp-publish -p -e ${AMQP_EXCHANGE} -r ${AMQP_ROUTINGKEY} --server ${OUTPUT_HOST}:${OUTPUT_PORT} --vhost ${AMQP_VHOST}

  else
    printf "Usage: ${IAM} unknown OUTPUT_PROTOCOL:${OUTPUT_PROTOCOL}\n"
    exit ${EX_SOFTWARE}
  fi
  return
}

## @fn TidyUp(... file list ...)
## remove state that was created or is stale
## @param filelist
## @param LEAVE_BREADCRUMB_PROCS
## @param LEAVE_BREADCRUMBS
## @param RM_DISABLED
## @return void
## \callgraph
## \callergraph
##
TidyUp() {
  local ignore_leave_breadcrumbs=""
  local leave_breadcrumbs="${LEAVE_BREADCRUMBS}"
  local leave_procs="${LEAVE_BREADCRUMB_PROCS}"
  local tidypwd="."

  trap "" HUP
  case ${leave_procs} in
  "")                 Log "TidyUp(): empty leave_procs, no notification of potential children processes"  ;;
  any_signals_all)    trap "" HUP; kill -HUP -${PGID}                                                     ;;
  parent_signals_all) trap "" HUP; [[ $$ == ${PGID} ]] && kill -HUP -${PGID}                              ;;
  any_kills_all)      kill -KILL -${PGID}                                                                 ;;
  parent_kills_all)   [[ $$ == ${PGID} ]] && kill -KILL -${PGID}                                          ;;
  *)                  ErrExit ${EX_SOFTWARE} "LEAVE_BREADCRUMB_PROCS: ${leave_procs} unknown disposition" ;;
  esac

  if [ "${1}" = "${TIDYUP_FORCE}" ] ; then
    leave_breadcrumbs=""
    shift
  fi
  if [ -n "${leave_breadcrumbs}" ] ; then
    return
  fi

  local f
  for f in $@
  do
    if [ -z "${f}" ] ; then
      Log "${IAM}:TidyUp():${f}: \"(null)\""
      return
    fi

    if [ -d "${f}" -a ! -L "${f}" ] ; then
      local d=$(dirname ${f})
      local b=$(basename ${f})
      cd ${d}
      tidypwd=$(pwd)
      if [ "${tidypwd}" = "." -o "${tidypwd}" = "/" -o "${tidypwd}" = ".." ] ; then
        Log "${IAM}:TidyUp():${f} refusing to \"rm ${f}\""
        continue
      fi
      ${RM_DISABLED} rm -fr ./"${b}"
    else
      if [ -e "${f}" ] ; then
        ${RM_DISABLED} rm -f "${f}"
      fi
    fi
  done
  exit
}

## @fn ErrExit(ExitCode)
## exits or returns after emitting message: exits (parent context), returns (daughter context)
## @param ExitCode
## @param ErrorMessage The message emitted to the user just before exit()
## @param ERREXIT_PRINT_CALL_STACK if set, callstack is emitted
## @param HOSTNAME
## @param IAM
## @return ExitCode (exits in parent context, returns in daughter context)
## @note if called from daughter's context, only emit the error message for collection by the parent
## \callgraph
## \callergraph
##
ErrExit() {
    local rc=${1:-$EX_SOFTWARE}
    local calledby=""
    local bsrc=""
    export recursed=${recursed:=""}

    shift
    [ -n "${ERREXIT_PRINT_CALL_STACK}" ] && printCallStack

    bsrc="$(basename ${BASH_SOURCE}): "
    export calledby="${bsrc}${FUNCNAME[1]}(${BASH_LINENO[0]}):"

    Log "${calledby} $@"
    [ -n "${DEBUG}" ] && echo "${calledby} $@"

    local stackframes=${#BASH_LINENO[@]}
    for (( i=stackframes-2 ; i>=0; i--))
    do
        case "${FUNCNAME[i+1]}" in
            "ErrExit")
                recursed="cursed!"
                break
                ;;
            *)  ;;
        esac
     done

    if [ -z "${recursed}" ] ; then
      if [ -n "${TIDYUP_LOCK}" -a -d "${TIDYUP_LOCK}" ] ; then
        TidyUp ${TIDYUP_LOCK}
      fi
    fi
    exit ${rc}
}

## @fn InitSlurmShowConfig()
##  Initialize SHOW_CONFIG from slurm 'scontrol -o show config ...'
## @param RANDOM
## @param SHOW_CONFIG
## @return void
## \callgraph
## \callergraph
##
InitSlurmShowConfig() {

  if [ -z "${SHOW_CONFIG}" ] ; then
    local retry=0
    while [ -z "${SHOW_CONFIG}" -a ${retry} -lt ${RETRY_LIMIT} ]
    do
      export SHOW_CONFIG=$(scontrol show config 2>&1)
      (( retry++ ))
      if [[ "${SHOW_CONFIG}" == *"Transport endpoint is not connected"* ]] ; then
        Log "InitSlurmShowConfig($LINENO): 'scontrol show config': ${SHOW_CONFIG} (retry: ${retry})"
        sleep .0$[ ( ${RANDOM} % 10 ) + 1 ]s
        export SHOW_CONFIG=""
      fi
    done

    if [[ "${SHOW_CONFIG}" == *"Transport endpoint is not connected"* ]] ; then
      ErrExit ${EX_SOFTWARE} "${SHOW_CONFIG} retry limit (${RETRY_LIMIT}) exceeded"
    fi
  fi
  return
}

CollectStateSaveLocation() {
  InitSlurmShowConfig
  local ssl=$(echo ${SHOW_CONFIG} | sed 's/.*StateSaveLocation = //' | awk '{print $1}')
  if [ ! -d ${ssl} ] ; then
    ErrExit ${EX_CONFIG} "StateSaveLocation: ${ssl} is not a directory. Is slurmctld running on this host ($HOSTNAME)?"
  fi
  export STATESAVELOC=${ssl}
}

SufficientPermissions() {
  uid=$(id -u)
  unam=$(id -un)
  if [ 0 -ne "${uid}" ] ; then
    ErrExit ${EX_NOPERM} "insufficient privileges (uid=${uid}) to monitor slurm StateSaveLocation:${ssl}"
  fi
  # really would like to drop permissions & run as SlurmUser ("slurm")
}

HashDirsValid() {
  local lshashdirs=$(ls -d ${STATESAVELOC}/hash.*)
  local hashdirs
  local nhash
  hashdirs=$(echo ${lshashdirs})
  nhash=$(echo ${hashdirs} | wc -w)
  if [[ ${nhash} == 0 ]] ; then
    ErrExit ${EX_CONFIG} "SateSaveLocation/hash.* directories don't exist"
  fi

  local _d
  for _d in ${hashdirs}
  do
    local _o

    if [ ! -d ${_d} ] ; then
      ErrExit ${EX_CONFIG} "SateSaveLocation: ${_d} is not a directory"
    fi
    _o=$(ls -d ${_d} | awk '{print $3}')
    if [[ ${_o} != ${unam} && root != ${unam}  ]] ; then
      ErrExit ${EX_NOPERM} "user ${_unam}: does not own ${_d} (owner: ${_o}) and is not root"
    fi
  done
}

## @fn GetOSVersion()
## Collect OS release tags and normalize to RHEL or SLES, sets OS_VERSION
## @param /etc/os-release/
## @return void
## \callgraph
## \callergraph
##
GetOSVersion() {
  local os_version="_no_os_specified_"
  if [ ! -r /etc/os-release ] ; then
    ErrExit ${EX_SOFTWARE} "/etc/os-release unreadable"
  fi
  if [ -n "${OS_VERSION}" ] ; then
    echo ${OS_VERSION}
    return
  fi

  local v
  v=$(grep -E '^ID=' /etc/os-release | sed 's/ID=//' | sed 's/"//g')
  case "${v}" in
    rhel|"Red Hat Enterprise Linux"*|RHEL)     os_version="rhel"   ;;
    sles|"SUSE Linux Enterprise Server"*|SLES) os_version="sles"   ;;
    *) ErrExit ${EX_CONFIG} "/etc/os-release unrecognized: \"${v}\"" ;;
  esac

  echo ${os_version}
  return
}

## Required commands for a given environment @see VerifyEnv()
declare -A RequiredCommands
# @todo build this via introspection of ourselves
# [base] linux-distribution independent required commands
RequiredCommands[base]="awk base64 basename cat cksum dirname echo grep head hostname inotifywait ln logger ls md5sum jq pgrep ping printf pwd rm su sed setsid strings sum tail test touch tr wc"
##XXX amqp-publish: https://github.com/selency/amqp-publish
##XXX RequiredCommands[base]="amqp-publish ${RequiredCommands[base]}"
# [cray] Cray-specific required commands
RequiredCommands[cray]=""
# [rhel] RHEL or RHEL-alike (TOSS, CentOS, &c) required commands
RequiredCommands[rhel]=""
# [sles] SuSe required commands
RequiredCommands[sles]=""
# [slurm] Slurm dependencies - all distributions
RequiredCommands[slurm]="scontrol"

## @fn VerifyEnv()
## verifies that the command environment appears sane (path, etc)
## @return if sane, otherwise calls ErrExit
## \callgraph
## \callergraph
##
VerifyEnv() {
  local o
  local os=""
  local opath=""
  local uid=0

  ORIGPWD=$(pwd)
  os=$(GetOSVersion)

  #
  if [ "${os}" = "sles" ] ; then
    ## CRAY_PATH for jdetach and pdsh, respectively
    export PATH=${CRAY_PATH}:${PATH}
    opath="cray"
    OUTPUT_PROTOCOL=${DEFAULT_CRAY_OUTPUT_PROTOCOL}
  else
    ## inotifywait may be installed into /usr/local/*bin
    export PATH=${LOCAL_PATH}:${PATH}
    opath="rhel"
  fi

  for o in base slurm ${os} ${opath}
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
    Log "VerifyEnv(): retrieved, set to: ${PGID}"
    if [ -z "${PGID}" ] ; then
      ErrExit ${EX_SOFTWARE} "empty PGID"
    fi
  fi

  if [ ${LOG_MSGSIZE} -gt ${MAX_RELIABLE_MSGSIZE} ] ; then
    ## @todo: implement Log buffering if this ever becomes a requirement
    ErrExit ${EX_SOFTWARE} "LOG_MSGSIZE:${LOG_MSGSIZE} > MAX_RELIABLE_MSGSIZE:${MAX_RELIABLE_MSGSIZE}"
  fi

  export OUTPUT_PROTOCOL=${OUTPUT_PROTOCOL:=${DEFAULT_OUTPUT_PROTOCOL}}

  InitSlurmShowConfig
  export CLUSTERNAME=$(echo ${SHOW_CONFIG} | grep ClusterName | sed 's/ClusterName.*= //')
  if [ -z "${HOSTNAME}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty hostname"
  fi
  if [[ ${HOSTNAME} != *master* ]] ; then
    OUTPUT_PROTOCOL=${OUTPUT_PROTOCOL:-syslog}
  else
    export CLUSTERABBREV=${HOSTNAME%%-master.*}
  fi

  if [[ ${OUTPUT_PROTOCOL} == amqp ]] ; then
    export OUTPUT_HOST=${OUTPUT_HOST:=turq-rabbit0}
    export OUTPUT_PORT=${OUTPUT_PORT:=5673}

    export AMQP_VHOST=${AMQP_VHOST:=${IAM}}
    export AMQP_EXCHANGE=${AMQP_EXCHANGE:=amq.topic}
    export AMQP_ROUTINGKEY=${CLUSTERNAME}.${CLUSTERABBREV}.${AMQP_VHOST}

  elif [[ ${OUTPUT_PROTOCOL} == syslog-remote ]] ; then
    export OUTPUT_PROTOCOL=syslog
    local output_host=${OUTPUT_HOST:=${CLUSTERABBREV}-mon2}.lanl.gov
    if ping -n -c 1 -w 1 ${output_host} >/dev/null 2>&1  ; then
      export OUTPUT_HOST=${output_host}
    else
      export OUTPUT_HOST=localhost
    fi
  fi

  return ${EX_OK}
}

ValidateEnv() {
  VerifyEnv
  CollectStateSaveLocation
  SufficientPermissions
  HashDirsValid
}

ForceUnlock() {
  if [ -z ${STATESAVELOC} ] ; then
    ErrExit ${EX_SOFTWARE} "empty STATESAVELOC"
  fi
  if [ ! -d ${STATESAVELOC} ] ; then
    ErrExit ${EX_SOFTWARE} "STATESAVELOC:${STATESAVELOC} !dir"
  fi
  local _d
  for _d in $(ls -d ${STATESAVELOC}/hash.* ${STATESAVELOC})
  do
    local lock=${_d}${LOCK_SUFFIX}
    TidyUp ${lock}
  done
  return
}

Heartbeat() {
  if [ ! -d ${TIDYUP_LOCK} ] ; then
    ErrExit ${EX_SOFTWARE} "TIDYUP_LOCK:${TIDYUP_LOCK} !dir"
  fi
  if [ -z "${PGID}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty PGID"
  fi
  touch -h ${TIDYUP_LOCK}/${BASHPID}
}

mklock() {
  local mklockdir=${1:-"_no_mklockdir_"}
  if [ -z "${IAM}" ] ; then
    ErrExit ${EX_SOFTWARE} "IAM empty"
  fi
  if [ ! -d ${STATESAVELOC} ] ; then
    ErrExit ${EX_SOFTWARE} "STATESAVELOC:${STATESAVELOC} !dir"
  fi
  if [ -z "${LOCK_SUFFIX}" ] ; then
    ErrExit ${EX_SOFTWARE} "LOCK_SUFFIX empty"
  fi
  if [ -d ${LOCK_SUFFIX} ] ; then
    ErrExit ${EX_SOFTWARE} "Directory LOCK_SUFFIX:${LOCK_SUFFIX} exists"
  fi
  if [[ ${LOCK_SUFFIX} = ${STATESAVELOC}${LOCK_SUFFIX} ]] ; then
    ErrExit ${EX_SOFTWARE} "STATESAVELOC:${STATESAVELOC} LOCK_SUFFIX:${LOCK_SUFFIX} = ${LOCK_SUFFIX}"
  fi
  local lock=${mklockdir}${LOCK_SUFFIX}
  if [ -z "${mklockdir}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty lockdir"
  fi
  if [ ! -d "${mklockdir}" ] ; then
    ErrExit ${EX_SOFTWARE} "lockdir !directory"
  fi
  if [ -d ${lock} ] ; then
    ErrExit ${EX_ALREADY}  "lock exists: ${lock}"
  fi
  export TIDYUP_LOCK=""
  mkdir ${lock} || ErrExit ${EX_IOERROR} "cannot create: ${lock}"
  export TIDYUP_LOCK=${lock}

  ln -s /proc/${PGID} ${TIDYUP_LOCK}/${PGID} || ErrExit ${EX_OSERR} "ln -s /proc/${PGID} ${TIDYUP_LOCK}/${PGID} (PGID)"
  if [ ${BASHPID} -ne ${PGID} ] ; then
    ln -s /proc/${BASHPID} ${TIDYUP_LOCK}/${BASHPID} || ErrExit ${EX_OSERR} "ln -s /proc/${BASHPID} ${TIDYUP_LOCK}/${BASHPID} (BASHPID)"
  fi

  Trap "TidyUp ${TIDYUP_LOCK}"
  return
}

SigAProc() {
  local _proc=${1:-"SigAProc(): _non_numeric_proc_"}

  # _proc is numeric
  if [[ "${_proc}" =~ [0-9]+$ ]] ; then
    if [ -d /proc/${_proc} ] ; then
      for _sig in HUP TERM
      do
        if [ -d /proc/${_proc} ] ; then
          kill -${_sig} ${_proc}
          sleep .0$[ ( ${RANDOM} % 10 ) + 1 ]s
        fi
      done
      [ -d /proc/${_proc} ] && \
        kill -KILL ${_proc}
    fi
  fi
  return
}

## @fn SignalPrevious()
##
SignalPrevious() {
  local prev_procs=""
  local prev_pgid=""
  local lsuffix=${LOCK_SUFFIX}
  local pg_lock=${STATESAVELOC}${lsuffix}
  local _p

  if [ -z ${STATESAVELOC} ] ; then
    ErrExit ${EX_SOFTWARE} "empty STATESAVELOC"
  fi
  if [ -z "${LOCK_SUFFIX}" ] ; then
    ErrExit ${EX_SOFTWARE} "LOCK_SUFFIX empty"
  fi
  if [ -d ${LOCK_SUFFIX} ] ; then
    ErrExit ${EX_SOFTWARE} "Directory LOCK_SUFFIX:${LOCK_SUFFIX} exists"
  fi
  if [[ ${LOCK_SUFFIX} = ${STATESAVELOC}${LOCK_SUFFIX} ]] ; then
    ErrExit ${EX_SOFTWARE} "STATESAVELOC:${STATESAVELOC} LOCK_SUFFIX:${LOCK_SUFFIX} = ${LOCK_SUFFIX}"
  fi
  if [ ! -d ${STATESAVELOC} ] ; then
    ErrExit ${EX_SOFTWARE} "STATESAVELOC:${STATESAVELOC} !dir "
  fi
  if [ -d ${pg_lock} ] ; then
    prev_pgid=$(ls ${pg_lock})
  fi
  if [ -z "${PGID}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty PGID"
  fi
  if [[ ${_prev_pgid} =~ ^?[0-9]+$ ]] ; then
    ErrExit ${EX_SOFTWARE} "PGID:${PGID} is not numeric?"
  fi

  # find processes that have dropped lock scat
  prev_procs=$(echo $(ls ${STATESAVELOC}/hash.*${lsuffix} 2>&1 | grep -v ${STATESAVELOC} | grep -v "No such file or directory" | sed 's/^$//' | sort -n | uniq))
  if [ -n "${prev_procs}" ] ; then
    for _p in ${prev_procs}
    do
      SigAProc $(basename ${_p})
    done
    SigAProc $(basename ${prev_pgid})
  fi

  # find processes that do not share this processes' process group, but have our name
  prev_procs=$(pgrep -v -g ${PGID} ${IAM}.sh 2>&1 | grep ${IAM})
  if [ -n "${prev_procs}" ] ; then
    for _p in ${prev_procs}
    do
      SigAProc ${_p}
    done
  fi
  return
}

## @fn RecordLocalStorage()
##  -- presently a duplicate of the default RECORDing function
##
Record_LocalStorage() {
  # Collect args & stash in a local storage repository, attempting deduplication wherever practical.
  # The arg list order should match those in the invocation of Record().
  # The SENSITIVITY_NOTICE is the end of argument marker.
  # Use the provided CKSUM, if available. Its non-presence indicates that the content may have been modified.
  ${RECORD} $*
}

# @fn Record_JSON
# analogous to Record_LocalStorage()
Record_JSON() {
  ${RECORD} $*
}

## @fn Record()
Record() {
    ${RECORD} $*
}

RecordAFile() {
    jobdir=${1:-"_no_jobdir_"}
    jobid=$(basename ${jobdir} | sed 's/job.//')
    if [ ${jobid} = "_no_jobdir_" ] ; then
      ErrExit ${EX_SOFTWARE} "jobdir=_no_jobdir_ $@"
    fi
    file=${2:-"_no_file_"}
    filepath=${jobdir}/${file}
    if [ ! -r ${filepath} ] ; then
      ErrExit ${EX_SOFTWARE} "jobdir/file (${jobdir}/${file}): unreadable"
    fi

    # minimal conversion:
    # - scripts get their newlines stripped, remove non-ASCII characters
    # - environment converts null termination to whitespace, and emits colated
    case ${file} in
    script)      converted=$(awk 1 ORS=' \\n ' < ${filepath} | sed 's/"//g' | sed "s/'//g" | tr -cd '[[:print:]]') ;;
    environment) converted=$(echo $(strings  < ${filepath} | sort) | tr -cd '[[:print:]]')                         ;;
    *)           Log "Warning: Unexpected job component file found: ${filepath}"                                   ;;
    esac
    base64encoded=$(echo $(echo $(base64 ${filepath})) | tr -d '[[:blank:]]')
    cksum=$(echo $(cksum ${filepath} || md5sum ${filepath}) | awk '{print $1}')

    ## record both the converted script, so that indexing and query tools may look inside the script,
    ## and also store the encoded and checksummed script for recovery & debugging of that job

    Record JOBID=${jobid} FILE=${file} ${converted} SENSITIVITY_NOTICE=${SENSITIVITY_NOTICE}
    Record JOBID=${jobid} FILE=${file} CKSUM[${file}]=${cksum} BASE64ENCODED=${base64encoded} SENSITIVITY_NOTICE=${SENSITIVITY_NOTICE}
}

RecordAJob() {
  local jobidir=${1:-"_no_job_id_dir_"}
  local _w
  if [ "${jobidir}" = "_no_job_id_dir_" ] ; then
    ErrExit ${EX_SOFTWARE} "jobidir: _no_job_id_dir_"
  fi
  if [ ! -d ${jobidir} ] ; then
    ErrExit ${EX_IOERR} "jobidir: pwd:$(pwd) ${jobidir} is not a directory"
  fi
  for _w in script environment
  do
    RecordAFile ${jobidir} ${_w}
  done
}

## @fn RecordJobs()
## record all jobs in a given hash directory
## @param hashdir/$1
##
RecordJobs() {
  local hashdir=${1:-""}
  if [ -z "${hashdir}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty hashdir"
  fi
  if [ ! -d "${hashdir}" ] ; then
    ErrExit ${EX_IOERR} "hashdir: pwd:$(pwd) ${hashdir} not a directory"
  fi
  jobs=$(ls ${hashdir})
  local _jobs=$(echo $jobs)

  for _j in ${_jobs}
  do
    RecordAJob ${hashdir}/${_j}
  done
}

MonitorDir() {
  local _d=$@
  mklock ${_d}

  local inotifyargs_monitor_quiet_recursively="-m -q -r ${_d}"

  while read _hashdir _events _file
  do
    ## @refine on inotifywait MODIFY event, record {jobid,{script,env,timestamp}},
    ## @refine then only respond to CLOSE_WRITE on on recent known jobids
    [[ ${_events^^} == *"IS_DIR"* ]] && continue

    if [[ ${_events^^} == *"CLOSE_WRITE"* ]] ; then
      [ -n "${DEBUG}" ] && Log "MonitorDir(): _hashdir:${_hashdir} _events:${_events} _file:${_file}"
      RecordAFile ${_hashdir} ${_file}
      Heartbeat
    fi
   done < <(inotifywait ${inotifyargs_monitor_quiet_recursively})
}

RecordHashDirs() {
  for _h in $(ls -d ${STATESAVELOC}/hash.*)
  do
    RecordJobs ${_h}
  done
  return
}

MonitorHashDirs() {
  for _h in $(ls -d ${STATESAVELOC}/hash.*)
  do
    MonitorDir ${_h} &
  done
  wait
  return
}

SetSessionIDLeader() {
  if [ -z "${PGID}" ] ; then
    export PGID=$(($(ps -o pgid= -p "$$")))
  fi
  if [ ${PG_DEPTH} -ge ${PG_DEPTH_LIMIT} ] ; then
    ErrExit ${EX_SOFTWARE} "Session Process Group Depth limit ($PG_DEPTH_LIMIT) reached: ${PG_DEPTH}, refusing to re-exec:" $0 $@
  fi
  # not (yet) process group leader
  if [[ "$$" != "${PGID}" ]] ; then
   (( PG_DEPTH++ ))
   export PG_DEPTH=${PG_DEPTH} PGID=${PGID}
   exec setsid $0 $@
  fi
  return
}

ParseArgs() {
  local opt
  local _doWhat=""
  local _setdebug=""
  _doWhat=""

  while getopts "DjmS?" opt; do
    case "${opt}" in
    "D")
        _setdebug="setdebug"
        ;;

    "j")
        # recording jobs should happen first
        _doWhat="RecordHashDirs ${_doWhat}"
        ;;
    "m")
        # monitoring for events never (should) exit, append it
        _doWhat="${_doWhat} MonitorHashDirs"
        ;;

    "S")
        if [ -n "${doWhat}" ] ; then
          printf "Usage: ${IAM} SignalPrevious() may not be used with other options."
          _doWhat=""
          exit ${EX_USAGE}
        fi
        if [[ ${doWhat} != *SignalPrevious* ]] ; then
          _doWhat="SignalPrevious"
        fi
        ;;

    "?")
        Usage
        ;;
    *)
        printf "Usage: ${IAM} unknown argument $opt\n" >/dev/tty 2>&1
        Usage
        ;;
    esac
  done

  echo "${_setdebug} ${_doWhat}"
  exit ${EX_OK}
}

Usage() {
  sed -n ': << /_USAGE_$/,/_USAGE_$/p' < ${IAMFULL} | \
    grep -v '_USAGE_$' | \
    sed 's/^#//' >/dev/tty
  exit ${EX_USAGE}
}

main() {
  local DoWhat
  ValidateEnv $0 $@
  if [ $# -eq 0 ] ; then
    DoWhat=$(ParseArgs ${DEFAULT_ARGS})
    parsedOk=$?
  else
    DoWhat=$(ParseArgs $*)
    parsedOk=$?
  fi

  if [[ "$DoWhat" =~ "setdebug " ]] ; then
    export DEBUG=true
    export OUTPUT_PROTOCOL=stdout
    #LOG_TO_STDERR="true"
    DoWhat=${DoWhat#setdebug }
  fi

  if [ ${parsedOk} -eq ${EX_OK} ] ; then
    if [[ ${DoWhat} != *SignalPrevious* ]] ; then
      mklock ${STATESAVELOC}
      SetSessionIDLeader $0 $@
    fi
  fi

  local _s
  for _s in ${DoWhat}
  do
    case ${_s} in
    setdebug) ;;
    *) ${_s}  ;;
    # Log "function not implemented" ${_s}"
    # ErrExit ${EX_SOFTWARE} "unknown function"
    esac
  done
  exit ${EX_OK}
}

main $@
ErrExit ${EX_SOFTWARE} "FAULTHROUGH: main"
exit ${EX_SOFTWARE}

# UNREACHED
: << _USAGE_
#
# stash_jobscript - save a copy of a slurm jobscript and its environment
#  Usage: stash_jobscript [-j -m | -S] [-D] | [-?]
#
#  Options:
#   -j  Record the jobscript and environment for previously-submitted jobs that
#       exist in the SlurmStateLoc
#
#   -m  Monitor batch jobs as they are submitted to the slurm controller daemon
#       This causes multiple children processes to be spawned, one for each hash
#       directory, ${SlurmStateLoc}/hash.*
#
#   -S  Send exit signals to any previously running instance of ourselves
#
#   -D  Run in 'debug' mode, which sends output to stdout rather than syslog
#       Additional messages are emitted for monitored jobs.
#
#   -?  Emit this usage message
#
_USAGE_

# vim: tabstop=2 shiftwidth=2 expandtab background=dark syntax=enable

