#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/bin/compilevagrantfile.sh

## This ANCHOR is used because the shell loader may be called from the primary host ("dom0") or from the guest host ("/vagrant/...")
declare -x VC=${VC:-_VC_UNSET_}

if [ ${VC} = "_VC_UNSET_" ] ; then
  echo ${0}: VC is unset. Need virtual cluster identifier.
  exit 97
fi
env_VC=${VC}

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

# this wonkiness is so that this script can orient itself when run by different users
# in different dom0 home directory structures
if [ ! -d "$(cd ${VC}; pwd)" ] ; then
  ErrExit ${EX_CONFIG} "echo VC:${VC} not a directory?"
fi

declare -x NO_NFS_F=$(realpath ${PROVISION_SRC_FLAG_D}/NO_NFS)
declare -x VAGRANTFILE_D=$(realpath ${ANCHOR}/Vagrantfile.d)
declare -x VAGRANTFILE_TEMPLATE=$(realpath ${VAGRANTFILE_D}/Vagrantfile.template)
declare -x SYNCEDFOLDERS_D=$(realpath ${VAGRANTFILE_D}/synced_folders.d)
declare -x DEFAULT_FSTYPE=$(realpath ${SYNCEDFOLDERS_D}/default_fstype)
declare -x CFG_VM_PROVIDERS_D=$(realpath ${VAGRANTFILE_D}/cfg.vm.providers.d)
declare -x DEFAULT_PROVIDER=$(realpath ${CFG_VM_PROVIDERS_D}/default_provider)
declare -x TSTAMP=$(date +%Y.%m.%d.%H%M)
declare -x VAGRANTFILE_TMP1=${TMP}/${IAM}.${TSTAMP}.tmp1
declare -x VAGRANTFILE_TMP2=${TMP}/${IAM}.${TSTAMP}.tmp2
declare -x VAGRANTFILE_TARGET=$(realpath ${VC}/Vagrantfile)
declare -x REGENERATED=$(realpath ${VC}/.regenerated)
declare -x PROVIDER
numeric="^[0-9]+$"

cd ${VC}

chkConfig() {
  local which_fs=""
  local which_provider=""
  local no_nfs

  for d in ANCHOR VAGRANTFILE_D SYNCEDFOLDERS_D CFG_VM_PROVIDERS_D
  do
    local _d="${!d}"
    if [ ! -d "${_d}" ] ; then
      echo "EX_CONFIG: d:${d}=${!d} not a directory pwd:$(pwd)"
      exit ${EX_CONFIG}
    fi
  done

  for f in DEFAULT_FSTYPE DEFAULT_PROVIDER VAGRANTFILE_TEMPLATE
  do
    local _f="${!f}"
    if [ ! -f "${_f}" ] ; then
      echo "  EX_CONFIG: ${f} missing"
      exit ${EX_CONFIG}
    fi
    if [ ! -s "${_f}" ] ; then
      echo "EX_CONFIG:  ${f} empty"
      exit ${EX_CONFIG}
    fi
  done

  if [ ! -d "${CFG}" ] ; then
    echo "EX_CONFIG:   VC:${VC}, but CFG:${CFG} ! dir"
    exit ${EX_CONFIG}
  fi

  default_fs=$(cat ${DEFAULT_FSTYPE})
  which_fs=${default_fs}
  no_nfs=""

  if [ -f "${NO_NFS_F}" ] ; then
    if [ -s "${NO_NFS_F}" ] ; then
      no_nfs=$(echo $(cat ${NO_NFS_F}))
    else
      no_nfs="true"
      which_fs="virtualbox"
    fi
  fi

  if [ -s "${NO_NFS_F}" -a "${which_fs}" = "nfs4" ] ; then
    which_fs=$(echo $(cat ${NO_NFS_F}))
  fi

  if [ -z "${which_fs}" ] ; then
    echo "EX_CONFIG:  VC:${VC} NO_NFS:${NO_NFS} empty which_fs"
    exit ${EX_CONFIG}
  fi

  case "${which_fs}" in
    "nfs4"|"nfs"|"virtualbox")
      ;;
    *|"")
      echo "EX_CONFIG:  which_fs:${which_fs} != nfs4, nfs nor virtualbox, using default_fs:${default_fs}"
      which_fs=${default_fs}
      ;;
  esac

  default_provider=$(cat ${DEFAULT_PROVIDER})
  which_provider=${default_provider}
  if [ -z "${which_provider}" ] ; then
    echo "EX_CONFIG: which_provider: empty"
    exit ${EX_CONFIG}
  fi
  if [ ! -f ${CFG_VM_PROVIDERS_D}/${which_provider} ] ; then
    echo "EX_CONFIG: VC:${VC} default_provider:${default_provider} does not exist"
    exit ${EX_CONFIG}
  fi

  echo "${which_fs}" "${which_provider}" "${no_nfs}"

  return
}

main() {
  SetFlags >/dev/null 2>&1
  local argprovider=${1:-_default_provider_}
  local fstype=""
  local provider=""
  local no_nfs=""

  configParams=($(chkConfig))
  rc=$?
  if [ ${rc} -eq ${EX_ALREADY} ] ; then
    exit ${EX_OK}
  fi
  if [ ${rc} -ne ${EX_OK} ] ; then
    ErrExit ${EX_CONFIG} "${configParams[*]}"
  fi

  fstype=$(echo ${configParams[0]})
  if [ "${argprovider}" = "_default_provider_" ] ; then
    provider=$(echo ${configParams[1]})
  fi

  if [ -z "${provider}" ] ; then
    ErrExit ${EX_SOFTWARE} "provider: empty"
  fi

  no_nfs=$(echo ${configParams[2]})
  if [ "${fstype}" = "virtualbox" -a "${provider}" != "virtualbox" ] ; then

    msg="Warning: fs:${fstype}, but provider:${provider} "
    if [ -n "${no_nfs}" ] ; then
      msg="${msg} and NO_NFS:${no_nfs}"
    fi
    msg="${msg} cannot provide fs:${fstype}; forcing fstype:nfs4"
    Warn ${EX_CONFIG} "${msg}"
    fstype=nfs4
  fi

## Using VC,
##   construct node list
##   construct Vagrantfile from
##     1) template,
##     2) per-node attributes
##     3) synced_folder.d/<fstype>
##     4) cfg.vm.provider/<provider>

  trap "rm ${VAGRANTFILE_TMP1} ${VAGRANTFILE_TMP2} ${REGENERATED}" 0
  export PROVIDER=${provider}
  INSERT_NODES_PATTERN="_insert_nodes_"
  INSERT_NODES_LINENO=$(sed -n -e "/${INSERT_NODES_PATTERN}/=" < ${VAGRANTFILE_TEMPLATE})
  TRIM=$((${INSERT_NODES_LINENO} - 2))
  Rc ErrExit ${EX_OSFILE} "sed -n -e \"1,${TRIM}p\" < ${VAGRANTFILE_TEMPLATE} > ${VAGRANTFILE_TMP1}"
  NODES_APPEND=$((${INSERT_NODES_LINENO} + 2))

  SYNCEDFOLDERS_PATTERN="_insert_synced_folders_"
  SYNCEDFOLDERS_LINENO=$(sed -n -e "/${SYNCEDFOLDERS_PATTERN}/=" < ${VAGRANTFILE_TEMPLATE})
  SYNCEDFOLDERS_TRIM=$((SYNCEDFOLDERS_LINENO - 2))
  SYNCEDFOLDERS_APPEND=$((SYNCEDFOLDERS_LINENO + 2))

  INSERT_PROVIDER_PATTERN="_insert_provider_"
  INSERT_PROVIDER_LINENO=$(sed -n -e "/${INSERT_PROVIDER_PATTERN}/=" < ${VAGRANTFILE_TEMPLATE})
  INSERT_PROVIDER_TRIM=$((${INSERT_PROVIDER_LINENO} - 2))
  INSERT_PROVIDER_APPEND=$((${INSERT_PROVIDER_LINENO} + 2))
  sed -n -e "${INSERT_PROVIDER_APPEND},\$p" < ${VAGRANTFILE_TEMPLATE} > ${VAGRANTFILE_TMP2}

  NODESTAB_PREFIX="nodes = {"
  ip=""
  mac=""
  bridge=""
  mem=""
  procs=""
  ingestfromhost_path=""
  ingestfromhost_args=""
  adddiskpath=""
  ATTR_D=""
  COMMON_ETC_D=$(realpath common/etc/)

  HOSTS=${COMMON_ETC_D}/hosts
  ETHERS=${COMMON_ETC_D}/ethers

  if [ ! -d "${COMMON_ETC_D}" ] ; then
    ErrExit ${EX_CONFIG} "COMMON_ETC_D:${COMMON_ETC_D} ! dir"
  fi
  for f in HOSTS ETHERS
  do
    if [ ! -f ${!f} ] ; then
      ErrExit ${EX_CONFIG} "${IAM}: ${f}:${!f} not found"
    fi
  done

  nodelist=($(echo ${CFG}/*/attributes/bootorder/*))
  n_NODES=$(echo ${nodelist[@]} | wc -w)
  if [[ "${n_NODES}" = *"No such file or directory"* ]] ; then
    ErrExit ${EX_CONFIG} "cluster recipe broken: cannot load node list:${n_NODES}"
  fi
  lowest_i=32768
  for b in $(echo ${CFG}/*/attributes/bootorder/*)
  do
    i=$(basename ${b})
    if [ "${i}" -lt "${lowest_i}" ] ; then
      lowest_i="${i}"
    fi
  done
  last_i=$(expr ${n_NODES} + ${lowest_i})
  cfg_nodelist=""

  for i in $(seq ${lowest_i} ${last_i})
  do
    node_paths=$(ls ${CFG}/*/attributes/bootorder/${i} 2>&1 | grep -v 'No such file or directory')
    cfg_nodelist="${cfg_nodelist} ${node_paths}"
  done

  NODES_BOOTORDER=""
  i=1
  for c in ${cfg_nodelist}
  do
    p=$(realpath ${c})
    d=$(dirname ${c})
    np=$(realpath ${d}/../..)
    n=$(basename ${np})

    sep=" "
    if [ -z "${NODES_BOOTORDER}" ] ; then
      sep=""
    fi
    if [ "${i}" = "${n_NODES}" ] ; then
      LASTNODE="${node}"
    fi
    NODES_BOOTORDER="${NODES_BOOTORDER}${sep}${n}"
    i=$(expr ${i} + 1)
  done
  if [ -z "${NODES_BOOTORDER}" ] ; then
    ErrExit ${EX_CONFIG} "NODES_BOOTORDER: empty"
  fi

  n_NODES_ORDERED=$(wc -w <<< ${NODES_BOOTORDER})
  if [[ ${n_NODES_ORDERED} != ${n_NODES} ]] ; then
    ErrExit ${EX_CONFIG} "n_NODES_ORDERED:${n_NODES_ORDERED} != n_NODES:${n_NODES}"
  fi
  trap "rm ${VAGRANTFILE_TMP1} ${VAGRANTFILE_TMP2} ${VAGRANTFILE_TARGET} ${REGENERATED}" 0

  (
    echo "${NODESTAB_PREFIX}"
    for n in ${NODES_BOOTORDER}
    do
      CFG_NODE_D=${CFG}/${n}
      ATTR_D=${CFG_NODE_D}/attributes

      memory=$(ls ${ATTR_D}/memory)
      if ! [[ ${memory} =~ ${numeric} ]] ; then
        ErrExit ${EX_CONFIG} "memory:${ATTR_D}/memory value is not numeric:\"${memory}\""
      fi
      memory=( ${memory} )
      if [ ${#memory[@]} -ne 1 ] ; then
        ErrExit ${EX_CONFIG} "memory:${ATTR_D}/memory directory has invalid specification:${memory[*]}"
      fi
      memory="${memory[*]}"

      procs=$(ls ${ATTR_D}/procs)
      if ! [[ ${procs} =~ ${numeric} ]] ; then
        ErrExit ${EX_CONFIG} "procs:${ATTR_D}/procs value is not numeric:\"${procs}\""
      fi
      procs=( ${procs} )
      if [ ${#procs[@]} -ne 1 ] ; then
        ErrExit ${EX_CONFIG} "procs:${ATTR_D}/procs directory has invalid specification:${procs[*]}"
      fi
      procs="${procs[*]}"

      ip=$(grep -e " ${n} "    ${HOSTS} | awk '{printf "%s",$1}') 
      mac=$(grep -e "[ 	]${n}" ${ETHERS}| awk '{printf "%s",$1}' | sed 's/://g')
      if [ -z "${ip}" ] ; then
        ErrExit ${EX_CONFIG} "ip:${ip} empty, n:${n}" >/dev/tty
      fi
      ## XXX @todo resembles a valid IP address, in a network defined in .../etc/networks
      if [ -z "${mac}" ] ; then
        ErrExit ${EX_CONFIG} "mac:${mac} empty, n:${n}" >/dev/tty
      fi
      ## XXX @todo resembles a valid MAC address, with a OUI prefix defined in .../etc/ethers

      bridge=""
      if [ -f ${ATTR_D}/bridge ] ; then
        bridge=$(cat ${ATTR_D}/bridge)
      fi
      ingestfromhost_path=""
      if [ -f ${ATTR_D}/ingestfromhost/path ] ; then
        ingestfromhost_path=$(cat ${ATTR_D}/ingestfromhost/path)
      fi
      ingestfromhost_args=""
      if [ -f ${ATTR_D}/ingestfromhost/args ] ; then
        ingestfromhost_args=$(cat ${ATTR_D}/ingestfromhost/args)
      fi
      adddiskpath=""
      if [ -f ${ATTR_D}/adddiskpath/path ] ; then
        adddiskpath=$(cat ${ATTR_D}/adddiskpath/path)
      fi
      echo " \"${n}\" => {"
      echo "    :ip  => \"${ip}\","
		  echo "    :mac => \"${mac}\","
      bridge_emit=${bridge:-"nil"}
		  echo "    :bridge => ${bridge_emit},"
		  echo "    :memory => \"${memory}\","
		  echo "    :cpus => \"${procs}\","

		  echo "    :ingestfromhost => {	"
      if [ -z "${ingestfromhost_path}" ] ; then
        echo "      path: nil,"
      else
        echo "      path: \"${ingestfromhost_path}\","
      fi
      if [ -z "${ingestfromhost_args}" ] ; then
        echo "      args: nil"
      else
        echo "      args: \"${ingestfromhost_args}\""
      fi
		  echo "    },"

      if [ -z "${adddiskpath}" ] ; then
        echo "    :adddiskpath => nil"
      else
        echo "    :adddiskpath => \"${adddiskpath}\""
      fi

      sep=","
      if [ "${LASTNODE}" = "${n}" ] ; then
        sep=""
      fi
		  echo " }${sep}"
    done
    # nodes table terminator
		echo "}${separator}"
    sed -n -e "${NODES_APPEND},${SYNCEDFOLDERS_TRIM}p" < ${VAGRANTFILE_TEMPLATE}
    cat ${SYNCEDFOLDERS_D}/${fstype}

    sed -n -e "${SYNCEDFOLDERS_APPEND},${INSERT_PROVIDER_TRIM}p" < ${VAGRANTFILE_TEMPLATE}
    cat ${CFG_VM_PROVIDERS_D}/${PROVIDER} ${VAGRANTFILE_TMP2}
  ) >> ${VAGRANTFILE_TMP1}
  rc=$?
  if [ ${rc} -ne 0 ] ; then
    Rc ErrExit ${EX_OSFILE} "rm -f ${VAGRANTFILE_TMP1}"
  fi

  #Rc ErrExit ${EX_OSFILE} "cp -buv ${VAGRANTFILE_TMP1} ${VAGRANTFILE_TARGET}"
  Rc ErrExit ${EX_OSFILE} "sed -i -e \"/%CLUSTERNAME%/s//${env_VC}/g\" ${VAGRANTFILE_TMP1} ;"
  Rc ErrExit ${EX_OSFILE} "rsync -cbv ${VAGRANTFILE_TMP1} ${VAGRANTFILE_TARGET}"
  Rc ErrExit ${EX_OSFILE} "rm -f ${VAGRANTFILE_TMP1} ${VAGRANTFILE_TMP2}"
  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
