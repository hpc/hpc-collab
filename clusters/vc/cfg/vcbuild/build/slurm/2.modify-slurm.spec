#!/bin/bash

## $Header: $
## Source:
## @file vcbuild/build/slurm/2.modify-slurm.spec

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
tmpfile1=${TMPDIR}${IAM}.${tstamp}.$$.tmp1
tmpfile2=${TMPDIR}${IAM}.${tstamp}.$$.tmp2
tmpfile3=${TMPDIR}${IAM}.${tstamp}.$$.tmp3

MARKER_TAG=${HOSTNAME}

if [ -z "${MARKER_TAG}" ] ; then
  ErrExit ${EX_CONFIG} "MARKER_TAG: empty"
fi

SetFlags >/dev/null 2>&1

if [ ! -f "${SLURM_SPEC}" ] ; then
  ErrExit ${EX_SOFTWARE} "Append(${SLURM_SPEC_F}) SLURM_SPEC:${SLURM_SPEC} does not exist"
fi 
if [ ! -s "${SLURM_SPEC}" ] ; then
  ErrExit ${EX_CONFIG} "Append(${SLURM_SPEC_F}) SLURM_SPEC:${SLURM_SPEC} empty"
fi

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

grep -s "${MARKER_TAG}" ${SLURM_SPEC} >/dev/null 2>&1
_rc=$?
if [ ${GREP_FOUND} -eq ${_rc} ] ; then
  Verbose " ${SLURM_SPEC} contains MARKER_TAG:${MARKER_TAG}"
  exit ${EX_OK}
fi

trap "rm -f ${tmpfile1} ${tmpfile2} ${tmpfile3}" 0 1 2 3 15
Rc ErrExit ${EX_OSFILE} "cp ${SLURM_SPEC} ${tmpfile1}"

# tmpfile1: input for each pass
# tmpfile2: output for each pass
# tmpfile3: if needed 

_comment_prefix="## "
for _op in append delete
do
  for _w in ${BUILDSLURM}/${SLURM_SPEC_F}.[0-9]?${_op}.where
  do
    _where_f=${_w}
    _what_f=${_w/where/what}

    if [ ! -f ${_where_f} ] ; then
      Warn ${EX_CONFIG} "_where_f:${_where_f} unreadable"
    fi
    if [ ! -f ${_what_f} ] ; then
      Warn ${EX_CONFIG} "_what_f:${_what_f} unreadable"
    fi
    _where=""
    _what=""
    _sed_op=""
    case "${_op}" in
      "append")	_where=$(cat ${_where_f})
                _what=$(cat ${_what_f})
                _sed_op="r ${tmpfile2}"
    		_hint=$(echo ${_what} | awk '{print $1}')
                _hint2=$(echo ${_what} | awk '{print $2}')
                ;;
      "delete")	_where=$(cat ${_where_f})
                _what=$(cat ${_what_f})
                _sed_op="d"
                _hint=$(echo ${_where})
                _hint2=""
                ;;
      "replace") ErrExit ${EX_SOFTWARE} "replace: not yet implemented" ;;
      *) ErrExit ${EX_SOFTWARE} "unknown op: ${_op}" ;;
    esac
    _dir=${BUILDWHERE_PRODUCT}

    Verbose " ${_op} ${SLURM_SPEC_F} ${_hint} ${_hint2}"

    if [ -n "${_sed_op}" ] ; then
      ( echo -e "\n${_comment_prefix} ${_comment_prefix} ${MARKER_TAG}"	; \
        echo -e "${_comment_prefix}   _w:$(basename $_w)"			; \
        if [ -r "${_what_f}" -a -s "${_what_f}" ] ; then			  \
	  cat ${_what_f} 							; \
	fi									; \
	echo -e "${_comment_prefix}   _w:$(basename $_w)"			; \
        echo -e "${_comment_prefix} ${_comment_prefix} ${MARKER_TAG}"		; \
      ) >> ${tmpfile2}
      sed "/^${_where}/${_sed_op}" ${tmpfile1} > ${tmpfile3}
      Rc ErrExit ${EX_OSFILE} "cp ${tmpfile3} ${tmpfile2}"
    fi
    Rc ErrExit ${EX_OSFILE} "mv ${tmpfile2} ${tmpfile1}"
  done
done

# for now, assume that we always start with the stock slurm .1 release
ed - ${tmpfile1} << __SED_BUMP_RELEASE_EOF__
/^%define rel	1/d
/^Release:/i
%define rel	1.${MARKER_TAG}
.
w
q
__SED_BUMP_RELEASE_EOF__
Rc ErrExit ${EX_OSFILE} "cp -b --preserve=all ${tmpfile1} ${SLURM_SPEC}"

exit ${EX_OK}
