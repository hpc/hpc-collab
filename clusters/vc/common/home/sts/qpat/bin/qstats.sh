#!/bin/bash

## $Header: $
## Source: https://git.lanl.gov/sts/qstats
## @file qstats.sh
## @author LANL/HPC/ENV/WLM/sts Steven Senator sts@lanl.gov
## @note This script is mostly written in POSIX style, with a soupçon of bashisms.
## This is a consequence of the author's heritage, and deadlines, not due to a requirement.
##

## @page Copyright
## <h2>© 2019-2020. Triad National Security, LLC. All rights reserved.</h2>
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

#
# qstats.sh
#  Usage:  qstats.sh [-a] [-b] [-B] [-c] [-C] [-d] [-f] [-F] [-l] [-L] [-N] [-n] [-p] [-P] [-q] [-r] [-R] [-S|-D] [-s] [-t] [-u] [-w] [--boot]
#

#
# Retrieves and lists the following slurm data:
#  [-a] accounts: fair share for accounts
#  [-b] blocked jobs; the reason that they were blocked
#  [-B] block jobs total
#  [-c] cluster name
#  [-C] provide slurm.conf path, signature and change time of slurm.conf
#  [-d] diagnostic statistics
#  [-f] fairshare values for each user who has an enqueued, pending job
#  [-F] backfill statistics
#  [-l] length of queue for each QOS
#  [-L] licenses
#  [-N] node attributes
#  [-n] node counts for nodes' state for the default partition
#  [-p] priority components for each pending job
#  [-P] pending job characteristics
#  [-q] QOS requested by pending jobs
#  [-u] user's fairshare values for enqueued, pending jobs
#  [-R] running job characteristics
#  [-r] reservations present and their attributes
#  [-S] syslog output, mutually exclusive with "-D", stdout output
#  [-s] scheduler parameters
#  [-t] total time enqueued
#  [-w] weights used to calculate total priority
#  [-D] Debug mode: stdout output, mutually exclusive with "-S", syslog output
#  [-V] CSV data output format [not all options recognize this output format]
#  [--boot] boot mode:
#       for each non-scheduled node, set the node weight to an explicit value of DISCOVERED_DOWN_WEIGHT
#
# To Do:
# 1. Pending Job Resources and Attributes requested, including ranges, of:
#   a. QOSPriorityWeights()
#    XXX To Do: multiple priority/(top priority) * QOSWeight
#   b. revisit output of JobAttributes(), fixing the formatting & var. names
#   c. Time to complete meaningful schedulable cycle / time to next checkpoint
#   d. user tags, if any
#
# 2. better self documenting
#   u. emit human-friendly time rather than seconds
#   v. select a specific syslog facility
#   w. pre-prime local bash arrays with 'squeue -t PD -h' &c.
#   y. doxygen-ify
#   z. Usage message
#
# 3. option to set timeout
#
# 4. stats selectable by: partition, QOS
#


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

## see Log()
declare -x DEFAULT_OUTPUT_PROTOCOL=${DEFAULT_OUTPUT_PROTOCOL:-"syslog"}

## see main()
declare -x TIMEOUT=${TIMEOUT:-300}

## local, this is interpreted as a parameter @see TidyUp() so must be no spaces in the value
declare -x TIDYUP_FORCE="ignore_LEAVE_BREADCRUMBS"
declare -x TIDYUP_LOCK=""
declare -x LEAVE_BREADCRUMB_PROCS=${LEAVE_BREADCRUMB_PROCS:-""}
declare -x LEAVE_BREADCRUMBS=${LEAVE_BREADCRUMBS:-""}

declare -x TRAP_NOISY=${TRAP_NOISY:-""}

declare -x CLUSTERNAME=""
declare -x SHOW_CONFIG=""
declare -x CSV="csv"
declare -x SEPARATOR="\n"

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

## @fn ErrExit(ExitCode)
## exits or returns after emitting message: exits (parent context), returns (daughter context)
## @param ExitCode
## @param ErrorMessage The message emitted to the user just before exit()
## @param ERREXIT_PRINT_CALL_STACK if set, callstack is emitted
## @param HOSTNAME
## @param IAM
## @param MYNAME to determine parental context
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
        TidyUp ${TIDYUP_LOCK}/pid ${TIDYUP_LOCK} ${TMP_OUT}
      fi
    fi

    exit ${rc}
}


# To Do (future):
# - awkify/pythonify/bashify, to (ease?) enable arithmetic functions
# - output format selector (key=value, JSON, XML)
#

Log(){
  local flush=${1:-_false_}
  local tag="${IAM}"
  local suffix
  local prefix

  if [[ ${OUTPUT_PROTOCOL} == syslog* ]] ; then
    if [[ ${flush} != flush ]] ; then
      shift
      suffix="-- $*"
    else
      suffix="-f ${TMP_OUT}"
      if [ -z "${TMP_OUT}" -o ! -r "${TMP_OUT}" -o ! -s "${TMP_OUT}" ] ; then
        return
      fi
    fi
  elif [[ ${OUTPUT_PROTOCOL} == amqp || ${OUTPUT_PROTOCOL} == stdout ]] ; then
    if [[ ${flush} == flush ]] ; then
      if [ -z "${TMP_OUT}" -o ! -r "${TMP_OUT}" -o ! -s "${TMP_OUT}" ] ; then
        return
      fi
      prefix="cat ${TMP_OUT}"
    else
      prefix="echo $@"
    fi
  fi

  if [[ ${OUTPUT_PROTOCOL} == syslog ]] ; then
      ${prefix} | logger -t "${tag}" -S 4096 ${suffix}

  elif [[ ${OUTPUT_PROTOCOL} == syslog-remote ]] ; then
    ${prefix} | logger -t "${tag}" -S 4096 -P 514 --tcp -n ${OUTPUT_HOST} ${suffix}
    if [ $? -ne 0 ] ; then
      printf "logger(syslog-remote) failed"
      exit ${EX_SOFTWARE}
    fi

  elif [[ ${OUTPUT_PROTOCOL} == stdout ]] ; then
    ${prefix}

  elif [[ ${OUTPUT_PROTOCOL} == amqp ]] ; then
    ${prefix} | amqp-publish -p -e ${AMQP_EXCHANGE} -r ${AMQP_ROUTINGKEY} --server ${OUTPUT_HOST}:${OUTPUT_PORT} --vhost ${AMQP_VHOST}

  else
    printf "Usage: ${IAM} unknown OUTPUT_PROTOCOL:${OUTPUT_PROTOCOL}\n"
    exit ${EX_USAGE}
  fi
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
  "")                                                                                                     ;;
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

## @fn TidyUpUnlock
##
TidyUpUnlock() {
  for f in $@
  do
    flock -u ${f} || Log "${IAM}:TidyUpUnlock():unlock failed: \"flock -u ${f}\""
  done
  return
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
    rhel|"Red Hat Enterprise Linux"*|RHEL|centos) os_version="rhel"   ;;
    sles|"SUSE Linux Enterprise Server"*|SLES)    os_version="sles"   ;;
    *) ErrExit ${EX_CONFIG} "/etc/os-release unrecognized: \"${v}\""  ;;
  esac

  echo ${os_version}
  return
}

## Required commands for a given environment @see VerifyEnv()
declare -A RequiredCommands
# @todo build this via introspection of ourselves
# [base] linux-distribution independent required commands
RequiredCommands[base]="awk base64 basename cat cksum dirname echo grep head hostname logger ls mkdir printf ps pwd rm su sed setsid sha1sum stat strings sum tail test timeout wc"
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
  local uid=0

  ORIGPWD=$(pwd)
  os=$(GetOSVersion)

  #
  if [ "${os}" = "sles" ] ; then
    ocray="cray"
    ## CRAY_PATH for jdetach and pdsh, respectively
    export PATH=${CRAY_PATH}:${PATH}
  fi

  for o in base slurm ${os} ${ocray}
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

  return ${EX_OK}
}

mklock() {
  local mklockdir=${1:-"_no_mklockdir_"}
  if [ -z "${mklockdir}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty lockdir"
  fi
  if [[ "${mklockdir}" = _no_mklockdir_ ]] ; then
    ErrExit ${EX_SOFTWARE} "mklockdir: _no_mklockdir_"
  fi

  local lock=${mklockdir}/${MYNAME}.lock
  if [ ! -d "${mklockdir}" ] ; then
    local mkdir_out
    mkdir_out=$(mkdir ${mklockdir} 2>&1) || ErrExit ${EX_SOFTWARE} "! -d ${mklockdir}, mkdir mklockdir:${mklockdir}: ${mkdir_out}"
  fi
  if [ -d ${lock} ] ; then
    ErrExit ${EX_ALREADY}  "lock exists: ${lock}"
  fi
  export TIDYUP_LOCK=""
  local mkdir_out=""
  mkdir_out=$(mkdir ${lock} 2>&1) || ErrExit ${EX_IOERR} "mkdir lock:${lock}: ${mkdir_out}"
  export TIDYUP_LOCK=${lock}
  echo $$ > ${TIDYUP_LOCK}/pid
  Trap "TidyUp ${TIDYUP_LOCK}/pid ${TIDYUP_LOCK} ${TMP_OUT}"
  return
}

SetEnv() {
  OUTPUT_PROTOCOL="stdout"
  export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/opt/slurm/bin:/opt/slurm/sbin
  VerifyEnv
  OUTPUT_PROTOCOL=${DEFAULT_OUTPUT_PROTOCOL}

  IAM=`basename $0`
  local lock=/var/tmp/$(basename ${IAM} .sh)

  export SQUEUE_SORT="-t,-p,e,S"

  # JOBID PRIORITY QOS ACCOUNT USER STATE TIME TIME_LIMIT END_TIME NODES NODELIST(REASON)
  export SQUEUE_FORMAT="%.22i %.9Q %.11q %.18a %.13u %.8T %.12M %.12l %.20e %.6D %R"

  # PARTITION    AVAIL  NODES  STATE
  export SINFO_FORMAT="%.12R %.5a %.6D %.6t"

  # DISCOVERED_DOWN_WEIGHT - a node discovered down, with the "--boot" option has its weight set to this value
  # may be overridden by a value inherited from the run-time environment
  export DISCOVERED_DOWN_WEIGHT=${DISCOVERED_DOWN_WEIGHT:-20480}

  export SHOW_CONFIG=$(timeout 15s scontrol show config 2>&1)
  if [ -z "${SHOW_CONFIG}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty SHOW_CONFIG"
  fi
  if [[ ${SHOW_CONFIG} = *"fail "* ]] ; then
    ErrExit ${EX_SOFTWARE} "show config: ${SHOW_CONFIG}"
  fi
  export CLUSTERNAME=$(scontrol show config | grep ClusterName | awk '{print $3}')
  HOSTNAME=$(hostname -s)
  if [[ ${HOSTNAME} !=  master ]] ; then
    OUTPUT_PROTOCOL=${OUTPUT_PROTOCOL:-syslog}
  else
    export CLUSTER2LETTERS=$(hostname -s | sed 's/-master//')
  fi

  # Note: actual limit is <= ~8050 (varies depending upon OUTPUT_PROTOCOL)
  export MAX_RELIABLE_MSG_SIZE=8000

  # XXX more arguments to specify these on the command line? (running out of letters)
  export OUTPUT_PROTOCOL=${OUTPUT_PROTOCOL:=${DEFAULT_OUTPUT_PROTOCOL}}

  if [[ ${OUTPUT_PROTOCOL} == amqp ]] ; then
    export OUTPUT_HOST=${OUTPUT_HOST:=turq-rabbit0}
    export OUTPUT_PORT=${OUTPUT_PORT:=5673}

    export AMQP_VHOST=${AMQP_VHOST:=qstats}
    export AMQP_EXCHANGE=${AMQP_EXCHANGE:=amq.topic}
    export AMQP_ROUTINGKEY=${CLUSTERNAME}.${CLUSTER2LETTERS}.${AMQP_VHOST}

  elif [[ ${OUTPUT_PROTOCOL} == syslog-remote ]] ; then
    export OUTPUT_PROTOCOL=syslog
    local output_host=${OUTPUT_HOST:=${CLUSTER2LETTERS}-mon2}
    ping -n -c 1 -w 1 ${output_host} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -ne ${EX_OK} ] ; then
      export OUTPUT_HOST=${output_host}
    fi
  fi

  MOTD_PATH=/var/lib/perceus/vnfs/fe/rootfs/etc/motd
  DSTMODE=""
  if DSTModeCheck ; then
    DSTMODE=true
  fi

  export SLURM_CONF=$(echo ${SHOW_CONFIG} | sed 's/.*SLURM_CONF = //' | awk '{print $1}')
  if [ ! -r ${SLURM_CONF} ] ; then
    ErrExit ${EX_SOFTWARE} "slurm.conf:${SLURM_CONF} unreadable"
  fi

  TMP_OUT=/tmp/${IAM}.$$
  > ${TMP_OUT}
  mklock ${lock}
}

export DEBUG=""
SetDebug() {
  DEBUG=${1:-"true"}
  OUTPUT_PROTOCOL="stdout"
}

SetOutputCSV() {
  export CSV="csv"
}

LogBuf() {
  local size=$(timeout 5s stat --format="%s" ${SLURM_CONF})
  if [ ${size} -gt ${MAX_RELIABLE_MSG_SIZE} ] ; then
    Log flush
    > ${TMP_OUT}
  fi
  if [ -n "${TMP_OUT}" -a -w "${TMP_OUT}" ] ; then
    echo -e "$@" >> ${TMP_OUT}
  fi
  return
}

ClusterName() {
  if [ -z "${CLUSTERNAME}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty ClusterName"
  fi
  cl="CLUSTERNAME=${CLUSTERNAME}"
  if [ -n "${CSV}" ] ; then
    cl="CLUSTERNAME ${CLUSTERNAME}"
  fi
  LogBuf "${cl}"
}

Configuration() {
  # slurm.conf: current signature and last changed timestamp

  local ctime=$(timeout 5s stat --format="%y" ${SLURM_CONF})
  local slurmconf_sig=$(timeout 30s sha1sum ${SLURM_CONF} | awk '{print $1}')
  LogBuf "SLURM_CONF=${SLURM_CONF} SLURM_CONF_SIG=${slurmconf_sig}  SLURM_CONF_CTIME=${ctime}"
  LogBuf "SHOW_CONFIG=${SHOW_CONFIG}"
}

Backfill() {
# Backfilling stats
#   Total backfilled jobs (since last slurm start): 5858
#   Total backfilled jobs (since last stats cycle start): 680
#   Total backfilled heterogeneous job components: 0
#   Total cycles: 331
#   Last cycle when: Fri Dec 07 15:04:56 2018 (1544220296)
#   Last cycle: 460745
#   Max cycle:  789442
#   Mean cycle: 225972
#   Last depth cycle: 402
#   Last depth cycle (try sched): 76
#   Depth Mean: 123
#   Depth Mean (try depth): 30
#   Last queue length: 403
#   Queue length mean: 124

  # yes the sed commands could be combined, but this shows the decomposition
  bf_stats=$(timeout 30s sdiag | sed -n '/Backfilling stats/,/Queue length mean:/s/: /=/p' | sed 's/ /_/g' | sed 's/=_/=/' | sed 's/(//' | sed 's/)//')
  bf=$(echo ${bf_stats} | sed 's/ / BACKFILL_/g')
  # XXX fixme BACKFILL_ in the following
  LogBuf BACKFILL_${bf}
}

Diagnostics() {
  CTLD_SINCE=$(timeout 30s sdiag | awk '/Data since/ {print $8}' | sed 's/(//' | sed 's/)//')
  DBD_AGENT_QUEUE_SIZE=$(timeout 30s sdiag | awk '/DBD Agent queue size:/ {print $5}')
  LogBuf "SLURMCTLD_SINCE=${CTLD_SINCE} DBD_AGENT_QUEUE_SIZE=${DBD_AGENT_QUEUE_SIZE}"
}

JobAttributes() {
  local header=""
  if [ "${1}" = "_header_" ] ; then
    header="true"
    shift
  fi
  jobid=${1:-:no_jobid:}
  attr=$(timeout 30s scontrol show job $jobid -o)
  heading=$(echo $(scontrol show job ${jobid} | sed 's/ /\n/g' | sed '/^$/d' | sed 's/=.*$//'))
  x_attr_noeq=$(echo $(echo $(scontrol show job ${jobid} | sed 's/ /\n/g' | sed '/^$/d' | sed 's/^.*=//')) | sed 's/ /,/g')
  attr_noeq=${x_attr_noeq/${jobid},/${jobid}  }
 

#% scontrol show job 1068851 -o
# JobId= JobName= UserId= GroupId= MCS_label=N/A Priority= Nice=0 Account= QOS=standard WCKey=* JobState=PENDING Reason=Resources Dependency=(null) Requeue=0 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0 RunTime=00:00:00 TimeLimit=16:00:00 TimeMin=N/A SubmitTime=2018-11-02T10:12:12 EligibleTime=2018-11-02T10:39:51 StartTime=2018-11-02T12:21:12 EndTime=2018-11-03T04:21:12 Deadline=N/A PreemptTime=None SuspendTime=None SecsPreSuspend=0 Partition=standard AllocNode:Sid=ko-fe1:176331 ReqNodeList=(null) ExcNodeList=(null) NodeList=(null) SchedNodeList=ko025 NumNodes=1-1 NumCPUs=1 NumTasks=1 CPUs/Task=1 ReqB:S:C:T=0:0:*:* TRES=cpu=1,node=1 Socks/Node=* NtasksPerN:B:S:C=0:0:*:* CoreSpec=* MinCPUsNode=1 MinMemoryNode=0 MinTmpDiskNode=0 Features=(null) DelayBoot=00:00:00 Gres=(null) Reservation=(null) OverSubscribe=NO Contiguous=0 Licenses=(null) Network=(null) Command=... WorkDir=.. AdminComment={ "color" : "TURQUOISE" }  StdErr=... StdIn=... StdOut=... Power=
  if [ -z "${CSV}" ] ; then 
    LogBuf $(timeout 30s scontrol show job $jobid -o)
  else
    if [ -n "${header}" ] ; then
      LogBuf "${heading}"
    fi
    LogBuf "${attr_noeq}"
  fi
}

Licenses() {
  local _licname _lictotal _licused _licfree _licremote
  #% scontrol show licenses -o
  # LicenseName=scratch3@slurmdb Total=1490 Used=0 Free=1490 Remote=yes
  # LicenseName=scratch4@slurmdb Total=1490 Used=0 Free=1490 Remote=yes

  while read -r _licname _lictotal _licused _licfree _licremote
  do
    _licname=`echo ${_licname} | sed -e 's/LicenseName=//'`
    LogBuf "LICENSE[${_licname}] ${_lictotal} ${_licused} ${_licfree} ${_licremote}"
  done < <(timeout 30s scontrol show licenses -o 2>&1)
}

PendingJobs() {
  Jobs pending $@
}

RunningJobs() {
  Jobs running $@
}

Jobs() {
  local state=$1
  local lstate
  if [ "${state}" = "pending" ] ; then
    lstate=PD
  else
    lstate=R
  fi
  shift

  local QL
  QL=`squeue -t ${lstate} -h | grep -v "Zero Bytes were transmitted" | wc -l`
  if [ -n "${CSV}" ] ; then
    LogBuf "QUEUELENGTH[${state}] ${QL}"
  else
    LogBuf QUEUELENGTH[${state}]=${QL}
  fi

  first="_header_"
  for j in $(timeout 60s squeue -t ${lstate} -h | awk '{print $1}' 2>&1 | grep -v "Zero Bytes were transmitted")
  do
    if [ -n "${CSV}" ] ; then
      JobAttributes ${first} $j
      first=""
    else
      JobAttributes $j
    fi
  done
}

JobPrioritiesComponents() {
  # sprio -l output formatted as:
  # JOBID USER PRIORITY AGE FAIRSHARE JOBSIZE PARTITION QOS NICE TRES (version 17.02)
  # except on Cray, where it is:
  # JOBID PARTITIONNAME NUSER PRIORITY AGE FAIRSHARE JOBSIZE PARTITION QOS NICE TRES (version > 17.02)
  # > 19.05.1-2
  # JOBID PARTITION     USER  PRIORITY SITE AGE ASSOC FAIRSHARE JOBSIZE PARTITION QOS NICE TRES
  # sprio only selects pending jobs that are not Dependent, Blocked, etc
  # TRES is likely to be missing (slurm.conf of Oct 2018, slurm version 17.02)

  sprio_version=$(timeout 60s sprio --version | awk '{print $2}')
  case $sprio_version in
  17.02*)
    readwhat="_jobid _user _priority _age _fairshare _jobsize _partition _qos _nice"
    ;;
  17.11*)
    readwhat="_jobid _partitionname _user _priority _age _fairshare _jobsize _partition _qos _nice"
    ;;
  18.08*)
    readwhat="_jobid _partitionname _user _priority _age _fairshare _jobsize _partition _qos _nice"
    ;;
  19.05*|20.02*)
    readwhat="_jobid _partitionname _user _priority _site _age _assoc _fairshare _jobsize _partition _qos _nice _tres"
    ;;
  *)
    LogBuf "Warning: internal error: JobPrioritiesComponents(): slurm version is not recognized -- skipped"
    return 1
    ;;
  esac

  local i=0
  while read -r $readwhat
  do
    (( i++ ))
    LogBuf "JOBID=${_jobid} USER=${_user} PRIORITY=${_priority} AGE=${_age} FAIRSHARE=${_fairshare} ASSOCIATION=${_assoc} JOBSIZE=${_jobsize} QOS=${_qos} SITE=${_site} NICE=${_nice} TRES=${_tres}"
    JobAttributes ${_jobid}
  done < <(timeout 60s sprio -l -h)
#  "sprio -l -h -n" #emits equivalent floats
  LogBuf "QUEUELENGTH[pending]=${i}"
}

EnqueuedBlocked() {
  local cmd=LogBuf
  local show_header=""
  local first="true"

  if [ "$1" = "-l" ] ; then
    cmd=echo
  else
    if [ -n "${CSV}" ] ; then
      show_header="JobID  Blocked Reason"
    fi
  fi

  while read -r _jobid _priority _qos _account _user _state _time _time_limit _end_time _nodes _reason
  do
    if [ -n "${first}" -a -n "${show_header}" ] ; then
      LogBuf "${show_header}"
    fi
    if [ -n "${cmd}" ] ; then
      ${cmd} ${_jobid} `echo ${_reason} | sed 's/(//' | sed 's/)//'`
    else
      ${cmd} JOBID=${_jobid} BlockedReason=`echo ${_reason} | sed 's/(//' | sed 's/)//'`
    fi
    first=""
  done < <(timeout 60s squeue --noheader -t PD 2>&1 | grep -v "Zero Bytes were transmitted" | sed 's/\[/ &/' | sed 's/\]/& /')
}

TotalTime() {
  declare -A totaltime
  total_keys="blocked policyblocked pending all"
  for _k in $total_keys
  do
    (( totaltime[${_k}]=0 ))
  done

  while read -r _jobid _priority _qos _account _user _state _time _time_limit _end_time _nodes _reason
  do
    local _t

    (( _t=0 ))
    _t=`date +%s -d ${_time_limit} 2>&1`

    if [[ ${_t} =~ "invalid date" ]] ; then
#      LogBuf "JOBID=${_jobid} TIMELIMIT=${_time_limit} Warning: TotalTime(): internal error: date/time conversion error -- skipped"
      continue
    fi

    # Yes, we can do better with regexp, but the following is readable
    case "${_reason}" in
    *Depend*)
              (( totaltime["blocked"] = ${totaltime["blocked"]} + ${_t} ))
              ;;
    *Max*)
              (( totaltime["policyblocked"] = ${totaltime["policyblocked"]} + ${_t} ))
              ;;
    *Limit*)
              (( totaltime["policyblocked"] = ${totaltime["policyblocked"]} + ${_t} ))
              ;;
    *Priority*)
              (( totaltime["pending"] = ${totaltime["pending"]} + ${_t} ))
              ;;
    *)
              ;;
    esac
    (( totaltime["all"] = ${totaltime["all"]} + ${_t} ))
  done < <(timeout 60s squeue -t PD -h 2>&1)

  for _k in $total_keys
  do
    LogBuf "TOTALTIME[${_k}]=${totaltime[${_k}]}"
  done
}

SchedulerParams() {
#
# SchedulerParameters     = kill_invalid_depend,bf_continue,bf_interval=240,bf_max_job_user_part=10,bf_max_job_test=3000,default_queue_depth=3600
# SchedulerTimeSlice      = 30 sec
# SchedulerType           = sched/backfill
  schedparam=$(echo ${SHOW_CONFIG} | sed -n '/Scheduler/s/ = /=/p' | sed -n 's/ \+//gp')
  LogBuf $schedparam
}

Reservations() {
#ReservationName=sts-test StartTime=2018-10-11T17:53:10 EndTime=2018-10-12T18:00:00 Duration=1-00:06:50 Nodes=sn360 NodeCnt=1 CoreCnt=36 Features=(null) PartitionName=standard Flags=OVERLAP,IGNORE_JOBS TRES=cpu=36 Users=(null) Accounts=root Licenses=(null) State=ACTIVE BurstBuffer=(null) Watts=n/a
  reservations=$(timeout 30s scontrol show reservation -o | awk '/ReservationName=/ {print $1}' | sed 's/^ReservationName=//')
  Active=""
  Inactive=""
  r=$(echo $reservations)

  for _r in $r
  do
    while read -r _resname _starttime _endtime _duration _nodes _nodecnt _corecnt _features _partitionname _flags _tres _users _accounts _licenses _state _burstbuffer _watts
    do
      local _s
      LogBuf "RESERVATION=${_r} ${_state} ${_nodecnt} ${_partitionname} ${_features} ${_flags} ${_users} ${_accounts} ${_starttime} ${_endtime}"
      _s=${_state//State=}
      case $_s in
      ACTIVE) [ -z "${Active}" ] && Active="${_r}" || Active="${_r} ${Active}" ;;
      INACTIVE) [ -z "$Inactive}" ] && Inactive="${_r}" ||  Inactive="${_r} ${Inactive}" ;;
      *) ErrExit ${EX_SOFTWARE} "Unknown reservation state, res: ${_r}" ;;
      esac

      while read -r _jobid _jobpriority _jobqos _jobaccount _jobuser _jobstate _jobtime _jobtime_limit _jobend_time _jobnodes _jobreason
      do
        local _suffix
        set _suffix = ""
        # JOBREASON=${_jobreason} = nodelist if running
        case "${_jobstate}" in
        "RUNNING")
          _suffix="JOBNODELIST=${_jobreason}"
          ;;
        *)
          _suffix="JOBREASON=${_jobreason}"
          ;;
        esac
        LogBuf "RESERVATION=${_r} JOBID=${_jobid} JOBQOS=${_jobqos} JOBACCOUNT=${_jobaccount} JOBUSER=${_jobuser} JOBSTATE=${_jobstate} JOBTIME=${_jobtime} JOBTIME_LIMIT=${_jobtime_limit} JOBEND_TIME=${_jobendtime} JOBNODES=${_jobnodes} ${_suffix}"
      done < <(timeout 60s squeue --reservation=${_r} -h 2>&1)

    done < <(timeout 30s scontrol show reservation ${_r} -o)
    for _a in Active Inactive
    do
      if [ -n "${!_a}" ] ; then
        LogBuf "RESERVATIONS[${_a^^}]=\"${!_a}\""
      fi
    done
  done

}

ResetNodeWeights() {
  local found_any=0
  ## for nodes that are marked drain, draining or down
  ##   explicitly set the node weight to a flag value, high enough so that it wouldn't normally be possible
  while read -r _node _state _user _timestamp _reason
  do
    local _weight=$(NodeAttr ${_node} Weight Owner)
    if (( ${_weight} == 1 )) ; then
      (( found_any++ ))
      scontrol update node=${_node} weight=${DISCOVERED_DOWN_WEIGHT}
      LogBuf "NODE=${_node} STATE=${_state} USER=${_user} WHEN=${_timestamp} REASON=\"${_reason}\" WEIGHT=${DISCOVERED_DOWN_WEIGHT}"
    fi
  done < <(timeout 240s sinfo -R -N -o "%N %8t %12U %19H %E" -h)
  if (( ${found_any} > 0 )) ; then
    LogBuf "NODE[unschedulable]=${found_any}"
  fi
}

NodeState() {

  # print # nodes in a given state
  defaultPartition=$(timeout 240s sinfo -o "%12P" -h | grep '*' | sed 's/*//' | sed 's/ //g')
  if [ -z "$defaultPartition" ] ; then
    LogBuf "NodeState(): cannot determine default partition"
    return
  fi
  LogBuf "PARTITION[default]=${defaultPartition}"

  for _p in $(timeout 30s sinfo -o "%16R" -h)
  do
    while read -r _partitionstate _nodecount _nodestate
    do
      LogBuf "PARTITION[${_p}]=${_partitionstate} NODESTATE[${_nodestate}]=${_nodecount}"
    done < <(timeout 30s sinfo --partition=${_p} -o "%.5a %.6D %.6t" -h)
  done

  # for nodes which are drained or down, print the timestamp, culprit and reason that they're down
  # NODELIST STATE    USER         TIMESTAMP           REASON
  while read -r _node _state _user _timestamp _reason
  do
    LogBuf "NODE=${_node} STATE=${_state} USER=${_user} WHEN=${_timestamp} REASON=\"${_reason}\""
  done < <(timeout 240s sinfo -R -N -o "%N %8t %12U %19H %E" -h -p any)
}

declare -x SHOW_NODE
declare -x RETRY_LIMIT="5"
declare -x HOSTNAME

## @fn InitNodeAttr()
##  Initialize SHOW_NODE from slurm 'scontrol -o show node ...'
## @param RANDOM
## @param HOSTNAME
## @return void
## @see https://slurm.schedmd.com/job_array.html
## \callgraph
## \callergraph
##
InitNodeAttr() {
  HOSTNAME=${1:-"_no_hostname_"}

  [ -z "${HOSTNAME}" ] && export HOSTNAME=$(hostname -s)
  if [ -z "${SHOW_NODE}" ] ; then
    local retry=0
    while [ -z "${SHOW_NODE}" -a ${retry} -lt ${RETRY_LIMIT} ]
    do
      export SHOW_NODE=$(timeout 60s scontrol -o show node ${HOSTNAME} 2>&1)
      (( retry++ ))
      if [[ "${SHOW_NODE}" == *"Transport endpoint is not connected"* ]] ; then
        LogBuf "InitNodeAttr($LINENO): 'scontrol show node': ${SHOW_NODE} (retry: ${retry})"
        sleep .0$[ ( ${RANDOM} % 10 ) + 1 ]s
        export SHOW_NODE=""
      fi
    done
  fi
  return
}

## @fn CrackAttr
## Retrieve attribute
## @param AttrName
## @param NextAttr
## @return attribute's value on function's stdout
## @return void
## \callgraph
## \callergraph
##
CrackAttr() {
  local AttrName=${1:-_no_job_atttribute_name_}
  local NextAttr=${2:-"$"}
  local attr=""
  local scontrol_out=""

  ## match on AttrName (exactly as given), trimming leading and trailing whitespace, and removing "${AttrName}=" up to NextAttr
  attr=$(grep -Po "\s${AttrName}=.+\s"   | sed 's/^ *//' | sed "s/ ${NextAttr}=.*\$//" | sed "s/${AttrName}=//")
  echo ${attr}
  return
}

## @fn NodeAttr("ATTRIBUTE NAME")
## Retrieve Node's attribute, modifies SHOW_NODE if not already set
## @param AttrName
## @param NextAttr
## @return attribute's value on function's stdout
## @return void
## \callgraph
## \callergraph
##
NodeAttr() {
  node=${1:-_no_nodename_}
  InitNodeAttr ${node}
  shift
  echo ${SHOW_NODE} | CrackAttr $@
  return
}

Nodes() {
  # NODELIST PARTITION WEIGHT ACTIVE_FEATURES AVAIL_FEATURES
  # nodes in multiple partitions will be listed multiple times
  defaultPartition=$(timeout 30s sinfo -o "%12P" -h | grep '*' | sed 's/*//' | sed 's/ //g')
  if [ -z "$defaultPartition" ] ; then
    LogBuf "NodeState(): cannot determine default partition"
    return
  fi
  fe_nodes=$(grep FUTURE ${SLURM_CONF} | sed 's/NodeName=//' | awk '{print $1}')
  while read -r _node _weight _availableFeatures _activeFeatures
  do
    LogBuf "NODE=${_node} WEIGHT=${_weight} FEATURES_AVAIL=${_availableFeatures} FEATURES_ACTIVE=${_activeFeatures}"
  done < <(sinfo -N --partition=${defaultPartition} -o "%N %w %f %b" -h)
  for _n in ${fe_nodes}
  do
    _weight=$(NodeAttr ${_n} Weight Owner)
    _availableFeatures=$(NodeAttr ${_n} AvailableFeatures ActiveFeatures)
    _activeFeatures=$(NodeAttr ${_n} ActiveFeatures Gres)
    LogBuf "NODE=${_n} WEIGHT=${_weight} FEATURES_AVAIL=${_availableFeatures} FEATURES_ACTIVE=${_activeFeatures}"
  done
}

PriorityWeights() {
  # JOBID   PRIORITY        AGE  FAIRSHARE    JOBSIZE        QOS
  # Weights                 14400      48000      14400      48000
  ((_age=0))
  ((_fairshare=0))
  ((_jobsize=0))
  ((_qos=0))
  read _weights _age _fairshare _jobsize _qos < <(sprio -w -h 2>&1 | grep -v "Zero Bytes were transmitted")
  [ _age = "" ] && _age=
  LogBuf "PRIORITYWEIGHT[AGE]=$_age PRIORITYWEIGHT[FAIRSHARE]=$_fairshare PRIORITYWEIGHT[JOBSIZE]=$_jobsize PRIORITYWEIGHT[QOS]=$_qos"

}

FairShareAccount() {
  local accounts
  local _a
  accounts=$(echo $(sacctmgr show accounts format=account%-40 -n))

  for _a in ${accounts}
  do

# note empty columns
# Account User Partition RawShares NormShares RawUsage NormUsage EffectvUsage FairShare LevelFS GrpTRESMins TRESRunMins
#      xd                 46989000  0.981411 12994716338 0.138147 1.000000 0.981411              cpu=2695366394,mem=0,energy=0+

     read -r __account __rawshares __normshares __rawusage __effectvusage __fairshare __levelfs __etc < <(sshare --account=${_a} --partition -l -n )
    LogBuf "ACCOUNT=${_a} RAWSHARES=${__rawshares} NORMSHARES=${__normshares} RAWUSAGE=${__rawusage} EFFECTVUSAGE=${__effectvusage} FAIRSHARE=${__fairshare} LEVELFS=${__levelfs}""${suffix}"
  done
  return
}

FairShareUser() {

  local partitions
  local _p
  declare -A useraccounts
  partitions=$(sinfo --summarize --format="%R" -h| egrep -v 'tossdev|any')

  while read -r _jobid _priority _qos _account _user _state _time _time_limit _end_time _nodes _reason
  do
    local tuple
    tuple="${_account} ${_user}"

    if [ -z "${_user}" ] ; then
      LogBuf "_user=\"\""
      break
    fi
    if [ -z "${_account}" ] ; then
      LogBuf "_account=\"\""
      break
    fi

    if [ -z "${useraccounts[${tuple}]}" ] ; then
      useraccounts[$tuple]="${tuple}"
    else
      if [ "${useraccounts[${tuple}]}" != "${tuple}" ] ; then
        LogBuf "FairShareUser(Malformed Duplicate)=${useraccounts[${tuple}]}"
      fi
    fi
  done < <(squeue -t PD -h 2>&1 | egrep '(Priority|Resources)')

  for t in "${useraccounts[@]}"
  do
    local _u=${t#* }
    local _a=${t% *}

    # sshare output presents the account on the first line, and the user data on the 2nd
    # the 2nd line has an extra column of data, with the user name

    # Account User Partition RawShares NormShares RawUsage NormUsage EffectvUsage FairShare LevelFS   GrpTRESMins TRESRunMins
    # <account>              46989000  0.981411 12989861305 0.138092 1.000000     0.981411            cpu=2695339599,mem=0,energy=0+
    # <account> <user> debug 1         0.001202 1419338     0.000015 0.000109     0.036948  11.000065 cpu=0,mem=0,energy=0,node=0,b+
    # <account> <user> standard 1      0.001202 156030002   0.001659 0.012012     0.010843  0.100063  cpu=10446,mem=0,energy=0,node+

    while read -r __account __user __partition __rawshares __normshares __rawusage __effectvusage __fairshare __levelfs __etc
    do
      local __partition_msg
      # sshare may report the entries without a column entry for the user, if so, the user variable will contain the rawshares value
      # attempt to interpret the fields correctly
      isnumber_regex='^[0-9.]+$'
      if [[ ${__user} =~ ${isnumber_regex} ]] ; then
        __levelfs=${__fairshare}
        __fairshare=${__effectvusage}
        __effectvusage=${__rawusage}
        __rawusage=${__normshares}
        __normshares=${__rawshares}
        __rawshares=${__user}
      fi
      __partition_msg="PARTITION=${__partition}"
      if [[ ${__partition} =~ ${isnumber_regex} ]] ; then
        __levelfs=${__fairshare}
        __fairshare=${__effectvusage}
        __effectvusage=${__rawusage}
        __rawusage=${__normshares}
        __normshares=${__rawshares}
        __rawshares=${__partition}
        __partition_msg=""
      fi
      LogBuf "USER=${_u} ACCOUNT=${_a} ${__partition_msg} RAWSHARES=${__rawshares} NORMSHARES=${__normshares} RAWUSAGE=${__rawusage} EFFECTVUSAGE=${__effectvusage} FAIRSHARE=${__fairshare} LEVELFS=${__levelfs}""${suffix}"
    done < <(sshare --user=${_u} --account=${_a} --partition -l -n)
  done
}

BlockedLength() {
  blockedLength=$(EnqueuedBlocked -l | wc -l)
  if [ -z "${CSV}" ] ; then
    LogBuf "QUEUELENGTH[blocked]=${blockedLength}"
  else
    LogBuf "QUEUELENGTH[blocked]  ${blockedLength}"
  fi
}

EnqueuedQOS() {
  local QOS
  QOS=`squeue -t PD -h 2>&1 | grep -v "Zero Bytes were transmitted" | awk '{print $3}' | sort | uniq`
  case $1 in
  "-l")
    printf "${QOS}"
    ;;
  *)
    LogBuf PendingJobsQOS=\"${QOS}\"
    ;;
  esac
}

QOSPriorityWeights() {
# sacctmgr -n -P show qos
#normal|0|00:00:00||cluster|||1.000000|||||||||||||0||||
  while read -r _qosname _qospriority _ignored
  do
    LogBuf "QOS=${_qosname} PRIORITY=${_qospriority}"
    #XXX To Do: multiple priority/(top priority) * QOSWeight
  done < <(sacctmgr -n -P show qos | sed 's/|/ /g' | awk '{printf "%s %s\n", $1, $2}')
}

QueueLengthPendingByQOS() {
  local q
  local QL
  local total
  (( total=0 ))
  for q in `EnqueuedQOS -l`
  do
    QL=`squeue -t PD -h --qos=$q 2>&1 | grep -v "Zero Bytes were transmitted" | wc -l`
    (( total=${total} + ${QL} ))
    LogBuf QUEUELENGTH[${q}]=${QL}
  done
  LogBuf QUEUELENGTH[total]=${total}
}

DSTModeCheck() {
  if [ -r ${MOTD_PATH} -a -L ${MOTD_PATH} ] ; then
    isDST=$(readlink ${MOTD_PATH})
    if [[ ${isDST} = *DST* ]] ; then
      return 0
    fi
  fi
  return 1
}

# ParseArgs() is not re-entrant, modifies OPTIND
# This ParseArgs/Main structure where we set a known internal key
# and then check for it during the action phase is an old habit from
# when it made sense to do this with a bitfield.
# Some might claim a minor security benefit, in that the actual implementation
# routines need not be known to the upper layer arg parsing layer.
# It might still make sense if we wanted to rearrange the order of the requests.

ParseArgs() {
  local opt
  local _doWhat
  _doWhat=""
  while getopts "DBabdCcFfLlNnpPqRrSstuVw-:" opt; do
    case "${opt}" in
    "-")
      case ${OPTARG} in
      "boot")
        _doWhat="${_doWhat} ResetNodeWeights"
        ;;
      *)
        printf "Usage: ${IAM} unknown long-form argument $opt\n"
        ;;
      esac
      ;;
    "D")
        _doWhat="SetDebug ${_doWhat}"
      ;;
    "V")
        _doWhat="SetOutputCSV ${_doWhat}"
      ;;
    "a")
        _doWhat="${_doWhat} FairShareAccount"
      ;;
    "b")
        _doWhat="${_doWhat} EnqueuedBlocked"
      ;;
    "B")
        _doWhat="${_doWhat} BlockedLength"
      ;;
    "c")
        _doWhat="${_doWhat} ClusterName"
      ;;
    "C")
        _doWhat="${_doWhat} Configuration"
      ;;
    "d")
        _doWhat="${_doWhat} Diagnostics"
      ;;
    "f")
        _doWhat="${_doWhat} FairShareUser"
      ;;
    "F")
        _doWhat="${_doWhat} Backfill"
      ;;
    "L")
        _doWhat="${_doWhat} Licenses"
      ;;
    "l")
        _doWhat="${_doWhat} QueueLengthPendingByQOS"
      ;;
    "n")
        _doWhat="${_doWhat} NodeState"
      ;;
    "N")
        _doWhat="${_doWhat} Nodes"
      ;;
    "p")
        _doWhat="${_doWhat} JobPrioritiesComponents"
      ;;
    "P")
        _doWhat="${_doWhat} PendingJobs"
      ;;
    "q")
        _doWhat="${_doWhat} QOSPriorityWeights EnqueuedQOS"
      ;;
    "r")
        _doWhat="${_doWhat} Reservations"
      ;;
    "R")
        _doWhat="${_doWhat} RunningJobs"
      ;;
    "s")
        _doWhat="${_doWhat} SchedulerParams"
      ;;
    "S")
        if [ -n "${DEBUG}" ] ; then
          printf "Usage: ${IAM} syslog is mutually exclusive with DEBUG/stdout" >/dev/tty
          exit ${EX_USAGE}
        fi
        export OUTPUT_PROTOCOL="syslog"
      ;;
    "t")
        _doWhat="${_doWhat} TotalTime"
      ;;
    "u")
        _doWhat="${_doWhat} FairShareUser"
      ;;
    "w")
        _doWhat="${_doWhat} PriorityWeights"
      ;;
    *)
        printf "Usage: ${IAM} unknown argument\n" >/dev/tty
        exit ${EX_USAGE}
     ;;
    esac
  done
  shift $((OPTIND -1))
  echo "$_doWhat"
}

Do() {
  local _s

  for _s in $@
  do
    ${_s}
  done
}

main() {
  SetEnv $*
  DoWhat=$(ParseArgs $*)

  # setdebug is treated specially so that it takes effect before any other functions
  # no matter where in the argument string that it was presented
  if [[ "$DoWhat" =~ "SetDebug" ]] ; then
    SetDebug debug
    DoWhat=${DoWhat#SetDebug}
    OUTPUT_PROTOCOL="stdout"
  fi
  if [[ "$DoWhat" =~ "SetOutputCSV" ]] ; then
    SetOutputCSV
    DoWhat=${DoWhat#SetOutputCSV}
  fi

  Do ${DoWhat}
  Log flush
  exit ${EX_OK}
}

main $*
exit $?
# vim: tabstop=2 shiftwidth=2 expandtab background=dark
