#!/bin/bash

## $Header: $
## Source:
## @file vcsched/config/slurm/2.start-slurmctld-early

## @brief start slurmctld service early

VCLOAD=../../../provision/loader/shload.sh

if [ ! -f "${VCLOAD}" ] ; then
  echo "${0}: missing: ${VCLOAD}"
  exit 99
fi
source ${VCLOAD}

# if we're given an argument, append test output to it
declare -x OUT=${1:-""}

if [ -n "${OUT}" ] ; then
  touch ${OUT} || exit 1
  exec > >(tee -a "${OUT}") 2>&1
fi

declare -x SLURMCONF=${ETCSLURM}/slurm.conf
declare -x SLURMCONF_TEMPLATE=${ETCSLURM}/slurm.conf.template
declare -x TSTAMP=$(date +%Y.%m.%d.%H.%M)
declare -x PROD=$(basename $(pwd))
declare -x IAM=$(basename $0)

Rc ErrExit ${EX_SOFTWARE} "mkdir -p ${ETCSLURM}/prolog.d"

trap '' 0
exit ${EX_OK}

