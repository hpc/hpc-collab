#!/bin/bash

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}

if [ ${VC} = "_VC_UNSET_" ] ; then
  echo ${0}: VC is unset. Need virtual cluster identifier.
  exit 97
fi

#declare -x ANCHOR=cfg/provision
declare -x ANCHOR=../common
declare -x LOADER_SHLOAD=${ANCHOR}/loader/shload.sh
declare -x BASEDIR=${ANCHOR}/..

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LOADER_SHLOAD}"
  exit 99
fi
source ${LOADER_SHLOAD}

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
