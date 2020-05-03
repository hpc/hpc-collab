#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/slurmparams.h.sh

## @brief This header file defines commonly used slurm-related parameters

if [ -n "${ANCHOR}" ] ; then
  # inside the host ("dom0"), ANCHOR is used. It must be set by the invoker.
  declare -x VC=${ANCHOR}/../..
else
  # inside the guest, the virtual cluster driver directory ("cc") is mapped to /vagrant.
  # This location is unmounted once the node is fully provisioned.
  declare -x VC=/vagrant
fi

if [ -z "${COMMON}" ] ; then
  echo "  ${0}: Error: broken configuration: COMMON empty"
  exit 99
fi

declare -x SLURMCONF=${COMMON}/${ETCSLURM}/slurm.conf
declare -x SLURMDBDCONF=${COMMON}/${ETCSLURM}/slurmdbd.conf

declare -x DEFAULT_CTLDPORT_LOWER=6817
declare -x DEFAULT_CTLDPORT_UPPER=6817
declare -x DEFAULT_CTLDPORT=${DEFAULT_CTLDPORT_LOWER}

declare -x DEFAULT_SLURMDPORT=6818

declare -x DEFAULT_DBDPORT=6819

## @todo srun port range (from SLURMCONF)
