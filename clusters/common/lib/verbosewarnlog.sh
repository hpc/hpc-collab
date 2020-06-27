#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/verbosewarnlog.sh

## @brief This library file contains routines that emit messages.

## @fn Log()
## emit a message to to stderr & syslog
## @param ErrorMessage
## @param BASHPID
## @param IAM
## @param LOG_TO_STDERR
## @return void
## \callgraph
## \callergraph
##
Log() {
  local pgid=$(($(ps -o pgid= -p "$$")))
  local tag="${IAM}[${pgid}/${BASHPID}]"
  local loggerArgs="-S ${LOG_MSGSIZE}"
  local flush=${1:-_false_}
  local tag="${IAM}"
  local suffix="-- $@"

  [ -n "${LOG_TO_STDERR}" ] && loggerArgs="${loggerArgs} -s "
  loggerArgs="-t ${tag} ${loggerArgs} "

  if [[ ${OUTPUT_PROTOCOL} == syslog ]] ; then
      logger "${loggerArgs}" ${suffix}

  elif [[ ${OUTPUT_PROTOCOL} == syslog-remote ]] ; then
    logger ${loggerArgs} -P 514 --tcp -n ${OUTPUT_HOST} ${suffix}
    if [ $? -ne 0 ] ; then
      printf "logger(syslog-remote) failed: ${loggerArgs} -P 514 --tcp -n ${OUTPUT_HOST}"
      exit ${EX_SOFTWARE}
    fi

  elif [[ ${OUTPUT_PROTOCOL} == stdout ]] ; then
    echo -e $@

  elif [[ ${OUTPUT_PROTOCOL} == amqp ]] ; then
    echo $@ | amqp-publish -p -e ${AMQP_EXCHANGE} -r ${AMQP_ROUTINGKEY} --server ${OUTPUT_HOST}:${OUTPUT_PORT} --vhost ${AMQP_VHOST}

  else
    printf "Usage: ${IAM} unknown OUTPUT_PROTOCOL:${OUTPUT_PROTOCOL}\n"
    exit ${EX_SOFTWARE}
  fi
  return
}

## @fn Verbose()
##
Verbose() {
  local tty=$(tty 2>&1)
  local columns
  local numeric="^[0-9]+$"
  local tstamp

  if [[ ${tty} =~ /dev/* ]] ; then
    columns="${COLUMNS}:-$(stty size < ${tty} | awk '{print $2}')"
  fi
  if ! [[ ${columns} =~ ${numeric} ]] ; then
    columns=${DEFAULT_COLUMNS}
  fi
  export COLUMNS=$(expr ${columns} - 1)
  if [ -n "${VERBOSE}" ] ; then
    if [ -n "${TIMESTAMPS}" ] ; then
      tstamp=$(date "${TIMESTAMPS}")
    fi
    local has_stdbuf=$(which stdbuf)
    if [ -x "${has_stdbuf}" ] ; then
      stdbuf -oL -eL printf "${tstamp}%-20s " "$*" | fmt -w ${COLUMNS}
    else
      printf "${tstamp}%-20s " "$*" | fmt -w ${COLUMNS}
    fi
  fi

  return
}

Warn() {
  local _ec=${1}
  shift
  Log ${ExitCodeNames[${_ec}]}:${_ec} $@
  return
}


