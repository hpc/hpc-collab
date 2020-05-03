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
CFG=${VC}/cfg
COMMON=${VC}/common
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

# collect state from vagrant, selecting on cc nodes which are running
nodes_running=$(vagrant global-status | egrep "${VC}.*running " | awk '{print $2}')

for n in ${nodes_running}
do
	rm -f ${poweroff}/${n} ${nonexistent}/${n}

	# mark them as running, but only if they haven't been fully provisioned previously
	if [ ! -f ${provisioned}/${n} ] ; then
	  touch ${running}/${n}
	fi
done

# set other node's state, and clear their leftover running or provisioned flags
nodes=$(echo $(ls ${CFG} | grep -v provision))
for n in ${nodes}
do
	vg_state=$(vagrant global-status | grep $n | awk '{print $4}')

	case "${vg_state}" in
	"running")
		if [ -f ${provisioned}/${n} ] ; then
			rm -f ${running}/${n}
		fi
		;;
	"poweroff")
		touch ${poweroff}/${n}
		rm -f ${running}/${n} ${nonexistent}/${n}
		;;
	"nonexistent"|"not created"|"")
		touch ${nonexistent}/${n}
		rm -f ${running}/${n} ${poweroff}/${n}
		;;
	*)
		rm -f ${provisioned}/${n} ${running}/${n}
		;;
	esac
done

exit 0
