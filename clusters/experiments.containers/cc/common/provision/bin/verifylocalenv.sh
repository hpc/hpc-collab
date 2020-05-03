#!/bin/bash

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x ANCHOR=$(dirname $0)/..
declare -x LOADER_SHLOAD=${ANCHOR}/loader/shload.sh
declare -x BASEDIR=${ANCHOR}/../..

if [ -z "${LOADER_SHLOAD}" ] ; then
  echo "${0}: empty: LOADER_SHLOAD"
  exit 98
fi

if [ ! -f "${LOADER_SHLOAD}" ] ; then
  echo "${0}: nonexistent: LOADER_SHLOAD:${LIB_SHLOAD}"
  exit 99
fi
source ${LOADER_SHLOAD}

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

VC=cc

CFG=cfg
COMMON=common
ETC_ETHERS=/etc/ethers
ETC_HOSTS=/etc/hosts
COMMON_ETC_HOSTS=${COMMON}/${ETC_HOSTS}
COMMON_ETC_ETHERS=${COMMON}/${ETC_ETHERS}
TMP=${TMP:-/tmp}

for f in ${ETC_ETHERS} ${ETC_HOSTS}
do
  tmp=${TMP}/$(basename ${f}).$$
  trap "rm -f ${tmp}" 0
  where=${BASEDIR}/${COMMON}/${f}

  rc=${GREP_NOTFOUND}
  if [ -f ${f} ] ; then
    grep ${VC} ${f} >${tmp} 2>&1
    rc=$?
  fi

  if [ ${rc} -eq ${GREP_FOUND} -a -s ${tmp} ] ; then
    rm -f ${tmp}
    Verbose " ${f}: contains ${VC} hosts"
    continue
  fi

  grep ${VC} ${where} > ${tmp}
  rc=$?

  runas=$(id -u -n)

  if [ ${runas} = "root" ] ; then
    if [ ${rc} -eq ${GREP_NOTFOUND} -a -s ${tmp} ] ; then
      cat ${tmp} >> ${f}
      Verbose "Added ${VC} to ${f}"  
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

exit ${EX_OK}
