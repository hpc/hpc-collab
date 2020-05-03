#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/traptidy.sh

## @brief This library file contains signal trap handlers and cleanup routines


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



## @brief This library file contains signal trap handlers

## @fn Trap()
##
Trap() {
  local notdebug_sigs="HUP TERM CHLD"
  local debug_sigs="HUP INT QUIT ILL BUS ABRT TERM STKFLT CHLD"
  local sigs=""
  sigs=${debug_sigs}

  [ -z "${DEBUG}" ]  && sigs=${notdebug_sigs}
  trap "ErrExit ${EX_TEMPFAIL} \"caught signal\"" ${sigs}
  return
}

## @fn TrapCleanup()
## declares an exit and interrupt trap, calls TidyUp with its arguments
## @param fileName
## @param TRAP_NOISY
## @param DEBUG
## @todo return (SIGBASE + &lt;signal number&gt;) when != EX_OK
## @return void
## \callgraph
## \callergraph
##
TrapCleanup() {
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
