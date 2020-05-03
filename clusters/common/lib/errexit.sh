#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/errexit.sh

## @brief This library file contains the terminal error handler, ErrExit().

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
    set +x
    set +v
    local rc=${1:-$EX_SOFTWARE}
    local calledby=""
    local bsrc=""
    export recursed=${recursed:=""}

    shift
    [ -n "${ERREXIT_PRINT_CALL_STACK}" ] && printCallStack >/dev/stderr

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
    if [ -n "${HALT_ERREXIT}" ] ; then
      local isvirt=$(virt-what)
      if [[ ${isvirt} != *kvm* && ${isvirt} != *virtualbox* ]] ; then
        echo "[refusing to poweroff non-virtual system]"
      else
        poweroff --force --no-wall
      fi
    fi
    exit ${rc}
}

