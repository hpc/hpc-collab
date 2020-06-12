#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/rc.sh

## @brief This library file contains a the commonly called routine to run an executable command

## @fn Rc()
##  Rc (RunCommand) dispatches a command, tests its return code and ErrFunc()'s (ErrExits/Logs) as appropriate.
##  It is typically called as:
##   Rc ErrFunction ErrCode Cmd Msg
## where EX_OK is the exit code that indicates success of the command
## ErrFunction is what is called with the ErrCode and the output from the executing Cmd
## and Msg is passed to ErrFunction to emit on error. The return code from the Cmd
## is appended to the Msg when passed to ErrFunction.
## If ErrFunction returns, then this function's return code is the value collected from Cmd
## ErrFunction is expected to resemble ErrExit(), Log() or in-job equivalents to them.
## @param efunc
## @param ecode
## @param cmd
## @param [msg]
## @return if efunc() returns, the return code from the executed cmd
## @todo extensions: embed 1) 'su - user' 2) allow 'ignore (all) return codes'
## \callgraph
## \callergraph
##
Rc() {
  set +x
  set +v
  local efunc=${1}
  local ecode=${2}
  local cmd=${3}
  local msg=${4:-"_use_command_as_message_"}
  local rc
  local cmd_output=""

  if [ "${VERBOSE}" = "true+" ] ; then
    echo "${cmd}"
  fi

  ## if the command sets I/O sources or destination then need to have bash eval
  if [[ ${cmd} =~ "<" || ${cmd} =~ ">" || \
        ${cmd} =~ ")" || ${cmd} =~ "(" || \
        ${cmd} =~ "|" || ${cmd} =~ ";" || \
        ${cmd} =~ "&"                       ]] ; then
    cmd_output=$(eval ${cmd} 2>&1)
    rc=$?
  else
    cmd_output="`${cmd} 2>&1`"
    rc=$?
  fi
  if [ -z "${msg}" -o "${msg}"  = "_use_command_as_message_" ] ; then
    msg="${cmd}"
  fi

  if [ ${rc} -ne ${EX_OK} ] ; then
    [ ${ecode} -eq ${EX_OK} ] && shift
    ${efunc} ${ecode} "${msg} [rc=${rc}] ${cmd_output} "
  fi
  if [ -n "${DEBUG}" ] ; then
    echo "DEBUG: ${cmd_output}"
  fi

  return ${rc}
}

