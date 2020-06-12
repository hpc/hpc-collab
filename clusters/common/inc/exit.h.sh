#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/exit.h.sh

## @brief This header file contains common exit codes by value and name.

## @see Authoritative exit codes: <tt>/usr/include/sysexits.h</tt>
## @see Signals [Linux-specific]: <tt>/usr/include/bits/signum.h</tt>
## @see Errno's [Linux/ASM-specific]<tt>/usr/include/asm-generic/errno.h</tt>
## @see tldp.org et. al. for SIGBASE

## The operation worked, without error.
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
declare -a ExitCodeNames
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

