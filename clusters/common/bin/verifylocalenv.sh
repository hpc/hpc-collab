#!/bin/bash

## This ANCHOR is used because the shell loader may be called from the
## primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}
ANCHOR_INCLUSTER=/home/${VC}/common/provision
declare -x HOSTNAME=${HOSTNAME:-$(hostname -s)}

if [ ${VC} = "_VC_UNSET_" ] ; then
  if [ -d "${ANCHOR_INCLUSTER}" -a "${ANCHOR_INCLUSTER:2}" = "${HOSTNAME:0:2}" ] ; then
    declare -x VC=${ANCHOR_INCLUSTER}
  else
    declare -x VC=${HOSTNAME:0:2}
  fi
  declare -x CLUSTERNAME=${VC}
  echo ${0}: VC is unset. Assuming: \"${VC}\"
fi

isvirt=$(systemd-detect-virt)
rc=$?

if [ "${isvirt}" != "none" -a "${MODE}" != "host" ] ; then
  # running on VM, add users' accounts to all nodes, on one of them (Features=controller),
  # add slurm user accounts and associations
  # assume 
  declare -x ANCHOR=${ANCHOR_INCLUSTER}
  declare -x MODE=${MODE:-"cluster"}
else
  declare -x MODE=${MODE:-"host"}
  ## the invocation directory is expected to be the clusters/${VC} directory
  ## % pwd
  ## <git-repo>/clusters/vc
  ## % env VC=vc MODE="host" ../../clusters/common/bin/verifylocalenv.sh
  declare -x ANCHOR=../common
fi

declare -x LOADER_SHLOAD=$(realpath ${ANCHOR}/loader/shload.sh)
declare -x BASEDIR=$(realpath ${ANCHOR}/..)

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LOADER_SHLOAD} -- be sure to invoke with: env VC=<clustername> $(basename ${0})"
  exit 99
fi
source ${LOADER_SHLOAD}
env_VC=$(basename ${VC})


SetFlags >/dev/null 2>&1

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

CFG=cfg
COMMON=common
ETC_ETHERS=/etc/ethers
ETC_HOSTS=/etc/hosts
COMMON_ETC_HOSTS=${COMMON}/${ETC_HOSTS}
COMMON_ETC_ETHERS=${COMMON}/${ETC_ETHERS}
TMP=${TMP:-/tmp}

OPTIONAL_EXE="vmtouch pkill"

if [ -z "${VC}" ] ; then
  ErrExit ${EX_CONFIG} "VC: empty"
fi

_VC=$(cd ${VC}; pwd)
if [ -z "${_VC}" ] ; then
  ErrExit ${EX_CONFIG} "_VC: empty"
fi

if [ ! -d "${_VC}" ] ; then
  ErrExit ${EX_CONFIG} "_VC:${_VC} not directory"
fi

VC=$(basename ${_VC})

for f in ${ETC_ETHERS} ${ETC_HOSTS}
do
  tmp=${TMP}/$(basename ${f}).$$
  trap "rm -f ${tmp}" 0
  where=${_VC}/${COMMON}/${f}

  rc=${GREP_NOTFOUND}
  if [ -f ${f} ] ; then
    grep ${VC} ${f} >${tmp} 2>&1
    rc=$?
  fi

  if [ ${rc} -eq ${GREP_FOUND} -a -s ${tmp} ] ; then
    rm -f ${tmp}
    #Verbose "  ${f}: contains ${VC} hosts already"
    continue
  fi

  grep ${VC} ${where} > ${tmp}
  rc=$?

  runas=$(id -u -n)

  if [ ${runas} = "root" ] ; then
    if [ ${rc} -eq ${GREP_NOTFOUND} -a -s ${tmp} ] ; then
      cat ${tmp} >> ${f}
      Verbose "  Added ${VC} to ${f}"  
    fi
  else
    if [ ${rc} -eq ${GREP_NOTFOUND} ] ; then
      echo "Add the following lines to ${f} to enable access by name from: $(hostname -s) to ${VC} nodes."
      echo --- cut here ${f} cut here ---
      cat ${tmp}
      echo --- cut here ${f} cut here ---
    fi
  fi
  rm -f ${tmp}
done

for x in ${OPTIONAL_EXE}
do
  is_executable=$(which ${x} 2>/dev/null)
  if [ -n "${is_executable}" ] ; then
    if [ ! -x "${is_executable}" ] ; then
      Verbose "  ${is_executable}"
    fi
  fi
done

exit ${EX_OK}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
