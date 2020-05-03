#!/bin/bash

## $Header: $
## Source:
## @file vcbuild/build/slurm/1.build-rpms

_d=$(dirname $0)
provision_d=${_d}/../../../provision
loader_d=${provision_d}/loader
build_d=${provision_d}/../../build

VCLOAD=$(cd ${loader_d}; pwd)/shload.sh

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

PRODUCT=$(basename $(pwd))

BUILDWHERE=$(cd ${build_d}; pwd)
BUILDWHAT=${CFG}/${HOSTNAME}/build
BUILDSLURM=${BUILDWHAT}/${PRODUCT}
RPMS=${BUILDSLURM}/RPMS.Manifest
VERSION_FILE=${BUILDSLURM}/version
BUILDWHERE_PRODUCT=${BUILDWHERE}/${PRODUCT}
RPMBUILD=${BUILDWHERE}/rpmbuild
ARCH=$(uname -m)
RPMS_ARCH=${RPMBUILD}/RPMS/${ARCH}
SOURCES=${RPMBUILD}/SOURCES
IAM=$(basename ${0})

SLURM_VERSION=$(cat ${VERSION_FILE})

SLURM_TARBALL=slurm-${SLURM_VERSION}.tar.bz2
SLURM_SPEC_F=${PRODUCT}.spec
SLURM_SPEC=${BUILDWHERE_PRODUCT}/${SLURM_SPEC_F}
tstamp=$(date +%Y.%m.%d.%H:%M)
tstamp_dots=$(date +%Y.%m.%d.%H.%M)

TMPDIR=${TMPDIR:-/tmp/}
tmpfile=${TMPDIR}${IAM}.${tstamp}.$$.out

MARKER_TAG=${HOSTNAME}

if [ -z "${MARKER_TAG}" ] ; then
  ErrExit ${EX_CONFIG} "MARKER_TAG: empty"
fi

SetFlags >/dev/null 2>&1


SPECFILE_VERSION=$(grep -i '^Version:' ${SLURM_SPEC} | grep -v '%{version}' | sed 's/Version:\t//')
rpms=$(ls ${RPMS_ARCH}/${PRODUCT}*${SPECFILE_VERSION}*${MARKER_TAG}*.${ARCH}.rpm 2>&1)
rc=${EX_OK}

if ! [[ ${rpms} =~ "No such file or directory" ]] ; then
  _rpms=""
  for _r in ${rpms}
  do
    _rpms="${_rpms} $(basename ${_r} .${ARCH}.rpm)"
  done
  Verbose " ${_rpms}"
  exit ${EX_OK}
fi  

old_rpms=$(echo $(ls ${RPMS_ARCH}/${PRODUCT}*${ARCH}.rpm 2>/dev/null))
if [ -n "${old_rpms}" ] ; then
  Rc ErrExit ${EX_OSFILE} "rm -f ${old_rpms}"
fi

_where_f=${BUILDSLURM}/${SLURM_SPEC_F}.append.where
_what_f=${BUILDSLURM}/${SLURM_SPEC_F}.append.what

if [ ! -f ${_where_f} ] ; then
  ErrExit ${EX_CONFIG} "_where_f:${_where_f} unreadable"
fi
if [ ! -f ${_what_f} ] ; then
  ErrExit ${EX_CONFIG} "_what_f:${_what_f} unreadable"
fi

_appendwhere=$(cat ${_where_f})
_appendwhat=$(cat ${_what_f})
_dir=${BUILDWHERE_PRODUCT}

if [ ! -f "${SLURM_SPEC}" ] ; then
  ErrExit ${EX_SOFTWARE} "Append(${SLURM_SPEC_F}) SLURM_SPEC:${SLURM_SPEC} does not exist"
fi 

grep -s "${MARKER_TAG}" ${SLURM_SPEC} >/dev/null 2>&1
_rc=$?
if [ ${GREP_NOTFOUND} -eq ${_rc} ] ; then
  _hint=$(echo ${_appendwhat} | awk '{print $1}')
  _hint2=$(echo ${_appendwhat} | awk '{print $2}')
  _comment_prefix="## "

  _marker="${_comment_prefix}--- ${IAM} ${MARKER_TAG} ${tstamp} ---"
  Verbose " ${SLURM_SPEC_F} ${_hint} ${_hint2}"

  if [ -z "${tmpfile}" ] ; then
    ErrExit ${EX_SOFTWARE} "tmpfile: empty"
  fi
  trap "rm -f ${tmpfile}" 0 1 2 3 15
  ( echo -e "\n${_marker}" ; cat ${_what_f} ; echo -e "${_marker}\n" ) >> ${tmpfile}
  Rc ErrExit ${EX_OSFILE} "sed -i \"/^${_appendwhere}$/r ${tmpfile}\" ${SLURM_SPEC} ;"
  Rc ErrExit ${EX_OSFILE} "rm -f ${tmpfile}"
  awk "/^%define rel	/{\$0=\$0\".${MARKER_TAG}\"}{print}" ${SLURM_SPEC} > ${tmpfile}
  rc=$?
  if [ ${rc} -ne 0 ] ; then
    ErrExit ${EX_OSFILE} "awk "/^Release:	.*$/{\$0=\$0\".${MARKER_TAG}\"}{print}" ${SLURM_SPEC} > ${tmpfile}"
  fi
  Rc ErrExit ${EX_OSFILE} "mv ${tmpfile} ${SLURM_SPEC}"
fi

exit ${rc}
