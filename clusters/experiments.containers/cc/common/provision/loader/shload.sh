#!/bin/bash

## $Header: $
## Source:
## @file provision/lib/shload.sh

## @brief This file loads the initial set of shell parameters, constants and functions into the context of the <software>/<function>/script.
## It is a predecessor to the common functions, so must explicitly specify a few parameters (PROVISION_SRC_D, EX_SOFTWARE) locally.

ANCHOR=${ANCHOR:-/vagrant/cfg/provision}
declare -x PROVISION_SRC_D=${ANCHOR}

declare -x PROVISION_SRC_LIB_D=${PROVISION_SRC_D}/lib
declare -x PROVISION_SRC_INC_D=${PROVISION_SRC_D}/inc
declare -x PROVISION_SRC_ENV_D=${PROVISION_SRC_D}/env

declare -x SH_ENV=$(ls ${PROVISION_SRC_ENV_D})
declare -x SH_HEADERS=$(ls ${PROVISION_SRC_INC_D})
declare -x SH_LIBS=$(ls ${PROVISION_SRC_LIB_D})

# EX_SOFTWARE is needed if initial loader linkage fails
declare -x EX_SOFTWARE=70

for _d in ${PROVISION_SRC_D} ${PROVISION_SRC_LIB_D} ${PROVISION_SRC_INC_D} ${PROVISION_SRC_ENV_D}
do
  if [ ! -d ${_d} ] ; then
    echo "$(basename ${0}): _d:${_d} not a directory"
    exit ${EX_SOFTWARE}
  fi
done

if [ -z "${SH_HEADERS}" -o -z "${SH_LIBS}" -o -z "${SH_ENV}" ] ; then
  echo -e "$(basename ${0}): broken linkage, empty SH_HEADERS:${SH_HEADERS}, SH_LIBS:${SH_LIBS} or SH_ENV:${SH_ENV}"
  exit ${EX_SOFTWARE}
fi

for _l in ${SH_ENV} ${SH_HEADERS} ${SH_LIBS}
do
  _found_one=""
  for _sw in env inc lib
  do
    _f=${PROVISION_SRC_D}/${_sw}/${_l}
    if [ -r "${_f}" ] ; then
      _found_one=${_f}
      source ${_f}
    fi
  done
  if [ -z "${_found_one}" ] ; then
    echo -e "$(basename ${0}): cannot find ${_l}"
    exit ${EX_SOFTWARE}
  fi
done
