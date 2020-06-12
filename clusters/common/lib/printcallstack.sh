#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/printcallstack.sh

## @fn printCallStack(void)
## prints the bash function call stack. It is not re-entrant.
## It must not call other functions that could then call itself. (ie. ErrExit())
##
## Much of this function is adapted from a wide variety of bash shell
## debugging sites and programming fora.
##
## @note Non-copyright:
## This function is separable, was not authored by a Triad or LANL employee and
## is not copyrightten Triad nor by Los Alamos National Lab.
##
## @param ORIGPWD
## @param BASH_LINENO
## @param BASH_SOURCE
##
## \callergraph
##
printCallStack() {

    # This may miss the bottom-most func, if it was called via eval
     local i=0
     local stackframes=${#BASH_LINENO[@]}
     # stackframes-2 skips main
     echo ''
     for (( i=stackframes-2 ; i>=0; i--))
     do
        echo -n "${BASH_SOURCE[i+1]}: ${FUNCNAME[i+1]}(${BASH_LINENO[i]}): "
        if [ -r ${ORIGPWD}/${BASH_SOURCE[i+1]} ] ; then
          head -${BASH_LINENO[i]} < ${ORIGPWD}/${BASH_SOURCE[i+1]} | tail -1
        fi
     done
     return
}

