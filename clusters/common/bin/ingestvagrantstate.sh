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

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

SetFlags >/dev/null 2>&1

PWD=$(pwd)
CWD=$(basename ${PWD})

VC=${CWD}
CFG=cfg
COMMON=common

CLUSTERNAME=$(basename ${VC})
STATE_D=${COMMON}/._state
nonexistent=${STATE_D}/nonexistent
poweroff=${STATE_D}/poweroff
running=${STATE_D}/running
provisioned=${STATE_D}/provisioned

for d in ${STATE_D} ${nonexistent} ${poweroff} ${running} ${provisioned}
do
  if [ ! -d ${d} ] ; then
	mkdir -p ${d}
  fi
done

# collect state from vagrant, selecting on running nodes in this cluster
vagrant_status=$(vagrant global-status)
nodes_running=$(echo "${vagrant_status}" | egrep "${CLUSTERNAME}.*running " | awk '{print $2}')

for n in $(echo ${nodes_running})
do
	${DISABLE_RM} rm -f ${poweroff}/${n} ${nonexistent}/${n}

	# mark them as running, but only if they haven't been fully provisioned previously
	if [ ! -f ${provisioned}/${n} ] ; then
	  touch ${running}/${n}
	fi
done

# set other node's state, and clear their leftover running or provisioned flags
if [ ! -d "${CFG}" ] ; then
  ErrExit ${EX_CONFIG} "CFG:${CFG} not a directory?"
fi
nodes=$(echo $(ls ${CFG} | grep ${CLUSTERNAME}))
no_state=""

for n in ${nodes}
do
	vg_state=$(echo "${vagrant_status}" | grep $n | awk '{print $4}')

	case "${vg_state}" in
	"running")
		if [ -f ${provisioned}/${n} ] ; then
			${DISABLE_RM} rm -f ${running}/${n}
		fi
		;;
	"poweroff"|"shutoff")
		touch ${poweroff}/${n}
		${DISABLE_RM} rm -f ${running}/${n} ${nonexistent}/${n}
		;;
	"nonexistent"|"not created"|"")
		touch ${nonexistent}/${n}
    for _f in ${running}/${n} ${poweroff}/${n}
    do
      if [ -f ${_f} ] ; then
        ${DISABLE_RM} rm -f ${_f}
      fi
    done
		;;
 "")
  no_state="${no_state} ${n}"
  ;;
	*)
		${DISABLE_RM} rm -f ${provisioned}/${n} ${running}/${n}
		;;
	esac
done
if [ -n "${no_state}" ] ; then
  Verbose "no state: ${no_state}"
fi

exit 0

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
