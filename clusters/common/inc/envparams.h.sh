#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/envparams.h.sh

## @brief This header file contains global parameters which may be overridden by prior existence
## in the run-time environment.
## @todo consider moving some of these into associated function libraries 

## parameters which govern provisioning execution behavior
declare -x VERBOSE=${VERBOSE:-""}
declare -x ERREXIT_PRINT_CALL_STACK=${ERREXIT_PRINT_CALL_STACK:-"true"}
declare -x HALT_PREREQ_ERROR=${HALT_PREREQ_ERROR:-""}
declare -x HALT_ERREXIT=${HALT_ERREXIT:-""}
declare -x HUSH_OUTPUT=${HUSH_OUTPUT:-""}
declare -x PREVENT_SLASHVAGRANT_MOUNT=${PREVENT_SLASHVAGRANT_MOUNT:-"true"}
declare -x PREFERRED_REPO=${PREFERRED_REPO:-""}
declare -x ONLY_REMOTE_REPOS=${ONLY_REMOTE_REPOS:-""}
declare -x LUSTRE=${LUSTRE:-""}
declare -x BUILD_LUSTRE=${BUILD_LUSTRE:-""}
declare -x DEFAULT_PREFERRED_REPO="rsync://linux.mirrors.es.net"
declare -x DEFAULT_COLUMNS=${COLUMNS:-100}
declare -x RSYNC_CENTOS_REPO=${RSYNC_CENTOS_REPO:-""}
declare -x SKIP_SW=${SKIP_SW:-""}
declare -x SKIP_UPDATERPMS=${SKIP_UPDATERPMS:-""}
declare -x DEFAULT_DB="${DEFAULT_DB:-mariadb}"
declare -x WHICH_DB=${WHICH_DB:-${DEFAULT_DB}}

declare -x IS_LANL_PINGABLE="proxyout.lanl.gov"
declare -x LANL_PROXY=${IS_LANL_PINGABLE}:8080
declare -x IS_LANL=${IS_LANL:-""}

## see Log(), setebug, VerifyEnv, controls how error messages are emitted
declare -x DEFAULT_OUTPUT_PROTOCOL=${DEFAULT_OUTPUT_PROTOCOL:-"stdout"}
declare -x OUTPUT_PROTOCOL=${DEFAULT_OUTPUT_PROTOCOL}

# see TidyUp()
declare -x LEAVE_BREADCRUMB_PROCS=${LEAVE_BREADCRUMB_PROCS:-"parent_signals_all"}

## local, this is interpreted as a parameter @see TidyUp() so must be no spaces in the value
declare -x TIDYUP_FORCE="ignore_LEAVE_BREADCRUMBS"
declare -x TIDYUP_LOCK=""

declare -x LOG_TO_STDERR=${LOG_TO_STDERR:-""}
declare -x TRAP_NOISY=${TRAP_NOISY:-"true"}

## DEBUG chiefly governs the order of opreations, but perhaps should be subsumed into a level mechanism
## rather than a simple binary flag
declare -x DEBUG=${DEBUG:-""}

