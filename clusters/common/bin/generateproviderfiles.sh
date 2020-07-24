#!/bin/bash

## $Header: $
## Source:
## @file common/provision/bin/generateproviderfiles.sh

## @brief create the various configuration files that may vary dependent upon the active virtualization provider

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

declare -x ANCHOR_D=$(realpath ${ANCHOR})
declare -x SRCS=($(find ${ANCHOR_D}/../${env_VC} -type f -name *%*%))

getSRCS() {

  for d in ANCHOR
  do
    local _d="${!d}"
    if [ ! -d "${_d}" ] ; then
      echo "EX_CONFIG: d:${d}=${!d} not a directory pwd:$(pwd)"
      exit ${EX_CONFIG}
    fi
  done

  if [ ${#SRCS[@]} -eq 0 ] ; then
    echo "EX_CONFIG: SRCS list empty"
    exit ${EX_CONFIG}
  fi

  for f in SRCS
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

  echo ${SRCS[@]}
  return
}

declare -x ANCHOR_D=$(realpath ${ANCHOR})
declare -x VAGRANTFILE_D=${ANCHOR_D}/Vagrantfile.d
declare -x HOSTS_FILE_TARGET=$(realpath ${ANCHOR_D}/../${env_VC}/common/etc/hosts)
declare -x HOSTS_FILE=${HOSTS_FILE_TARGET}.%${env_VC^^}-NET%
declare -x CFG_VM_PROVIDERS_D=$(realpath ${VAGRANTFILE_D}/cfg.vm.providers.d)
declare -x DEFAULT_PROVIDER=$(realpath ${CFG_VM_PROVIDERS_D}/default_provider)
declare -x TSTAMP=$(date +%Y.%m.%d.%H%M)
declare -x NO_NFS=${PROVISION_SRC_FLAG_D}/NO_NFS

declare -x TMP1=${TMP}/${IAM}.${TSTAMP}.tmp1
declare -x TMP2=${TMP}/${IAM}.${TSTAMP}.tmp2

declare -a KEYS
declare -A NODEKEYTOIPADDR
declare -x PROVIDER_NET

whichProvider() {
  local which_provider=""

  for d in ANCHOR VAGRANTFILE_D CFG_VM_PROVIDERS_D ANCHOR_D
  do
    local _d="${!d}"
    if [ ! -d "${_d}" ] ; then
      echo "EX_CONFIG: d:${d}=${!d} not a directory pwd:$(pwd)"
      exit ${EX_CONFIG}
    fi
  done

  for f in DEFAULT_PROVIDER HOSTS_FILE
  do
    local _f="${!f}"
    if [ ! -f "${_f}" ] ; then
      echo "  EX_CONFIG: ${f}:${_f} missing"
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

  default_provider=$(cat ${DEFAULT_PROVIDER})
  which_provider=${default_provider}

  if [ ! -f ${CFG_VM_PROVIDERS_D}/${which_provider} ] ; then
    echo "EX_CONFIG: VC:${VC} default_provider:${default_provider} does not exist"
    exit ${EX_CONFIG}
  fi

  echo ${which_provider}
  return
}

##     generate initial tmp file as input
##     for each instance of %VC*% in SRC name
##      collect value to be replaced from hosts file
##       replace %VC*% contained in the tmp file with the value from the hosts file
##       leaving the transformed file for the next pass, if any
##     copy the final tmp file to the target
##   update the target hosts file

mkTarg(){
  local src=${1-_no_src_}
  local target

  if [ ! -f "${src}" ] ; then
    echo "  EX_CONFIG: src:${src} missing"
    exit ${EX_CONFIG}
  fi
  if [ ! -s "${src}" ] ; then
    echo "EX_CONFIG:  ${src} empty"
    exit ${EX_CONFIG}
  fi

  Rc ErrExit ${EX_SOFTWARE} "cp ${src} ${TMP1} ;"
  for k in ${KEYS[@]}
  do
    sed -i -e "s/${k}/${NODEKEYTOIPADDR[${k}]}/g" ${TMP1}
  done
  target=${src/.%${env_VC^^}*%/}
  if [ -z "${target}" ] ; then
    ErrExit ${EX_SOFTWARE} "target empty"
  fi
  Rc ErrExit ${EX_SOFTWARE} "cp -b ${TMP1} ${target} ;"
  return
}

primeSubstKeys() {
  local provider=${1:-_no_provider_}
  local keys=""
  local provider_key

  # lower-case vc, upper-case vc
  local vc_l=${env_VC,,}
  local vc_u=${env_VC^^}

  if [ "${provider}" = "_no_provider_" ] ; then
    ErrExit ${EX_SOFTWARE} "${provider}"
  fi
  if [ -z "${provider}" ] ; then
    ErrExit ${EX_SOFTWARE} "provider empty"
  fi
  if [ ! -f "${CFG_VM_PROVIDERS_D}/${provider}" ] ; then
    ErrExit ${EX_SOFTWARE} "provider template: ${CFG_VM_PROVIDERS_D}/${provider} inaccessible"
  fi

  if [ ! -f "${HOSTS_FILE}" ] ; then
    ErrExit ${EX_CONFIG} "HOSTS_FILE: \"${HOSTS_FILE}\" source missing"
  fi
  cp ${HOSTS_FILE} ${TMP2}
  if [ ! -s "${TMP2}" ] ; then
    ErrExit ${EX_SOFTWARE} "TMP2:${TMP2} zero length"
  fi
  if [ ! -f "${TMP2}" ] ; then
    ErrExit ${EX_SOFTWARE} "TMP2:${TMP2} ! -f"
  fi

  # find the provider's network entry in the specially-formatted comment
  # XXX @todo - migrate to an attribute of providers structure, similar to nodes/attributes/... 
  provider_key="%%%${vc_u}-${provider^^}-NET%%%"
  provider_val=$(grep "${provider_key}" ${TMP2} | sed 's/### //g' | sed 's/ ###//g' | awk '{print $1}')
  if [ -z "${provider_val}" ] ; then
    ErrExit ${EX_SOFTWARE} "provider_val: not found in HOSTS_FILE_TARGET:${HOSTS_FILE_TARGET}"
  fi
  export PROVIDER_NET=${provider_val}

  ## insert the specific provider name of our cluster into the hosts file
  ## so that it may be used as a key/value by subsequent template files
  ## construct two special keys, not associated with node names
  ## for example:
  ##   {VC}-NET => 192.168.56
  ##   {VC}-0NET => 192.168.56.0
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e \"/^${provider_val}.0 /s//& ${vc_l}-net /\" ${TMP2} ;"
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${vc_u}-NET%/${provider_val}/g" ${TMP2} ;"
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${vc_u}-0NET%/${provider_val}.0/g" ${TMP2} ;"

  Rc ErrExit ${EX_SOFTWARE} "cp -b ${TMP2} ${HOSTS_FILE_TARGET} ;"

  for n in ${vc_u}-NET ${vc_u}-0NET ${NODES}
  do
    k="%${n^^}%"
    if [ -z "${keys}" ] ; then
      keys="${k}"
    else
      keys="${keys} ${k}"
    fi
  done
  echo ${keys}
  return
}

buildNodeToIPMap() {
  local k
  local n
  local ip

  for k in ${KEYS[*]}
  do
    n=${k,,}
    n=${n//\%/}

    if [ ${k:1:2} != ${env_VC^^} ] ; then
      ErrExit ${EX_CONFIG} "k:${k} k[1-2]:${k:1:2} != env_VC:${env_VC^^}"
    fi
    if [ -z "${n}" ] ; then
      ErrExit ${EX_CONFIG} "n empty"
    fi

    if [ "${n}" = "vc-0net" ] ; then
      ip=$(grep -s -e " ${n/0/} " ${HOSTS_FILE_TARGET} | awk '{print $1}')
      rc=$?
    else
      ip=$(grep -s -e " ${n} " ${HOSTS_FILE_TARGET} | awk '{print $1}')
      rc=$?
      if [ "${n}" = "vc-net" ] ; then
        ip=${ip/.0/}
      fi
    fi

    if [ ${rc} -ne ${GREP_FOUND} ] ; then
      ErrExit EX_CONFIG "node:${n} not found in ${HOSTS_FILE_TARGET}: ${ip}"
    fi

    NODEKEYTOIPADDR[${k}]="${ip}"
  done
# Verbose "  NODEKEYTOIPADDR:${NODEKEYTOIPADDR[@]}"
# Verbose "  !NODEKEYTOIPADDR:${!NODEKEYTOIPADDR[@]}"
  return
}

main() {
  SetFlags >/dev/null 2>&1
  local argprovider=${1:-_default_provider_}
  local fstype=""
  local provider=""
  local srcs=""

  srcs=($(getSRCS))
  rc=$?
  if [ ${rc} -eq ${EX_ALREADY} ] ; then
    exit ${EX_OK}
  fi

  if [ ${rc} -ne ${EX_OK} ] ; then
    ErrExit ${EX_CONFIG} "${srcs[*]}"
  fi

  provider=($(whichProvider))
  if [[ ${provider[0]} == *EX_CONFIG* ]] ; then
    ErrExit ${EX_CONFIG} ${provider[@]}
  fi

  if [ "provider" = "libvirt" ] ; then
    if [ -f "${NO_NFS}" ] ; then
      Warn ${EX_CONFIG} "provider:${provider} requires NFS, but NO_NFS flag is set."
    fi
  fi

  ## @todo if there are any currently running nodes of a different type than "${provider}"
  ## warn and possibly refuse to proceed

  KEYS=($(primeSubstKeys ${provider}))
  buildNodeToIPMap

  trap "rm -f ${TMP1} ${TMP2}" 0

## Using VC,
##   for all SRC files
##    determine target name
##     generate initial tmp file as input
##     for each instance of %VC*% in SRC name
##      collect value to be replaced from hosts file
##       replace %VC*% contained in the tmp file with the value from the hosts file
##       leaving the transformed file for the next pass, if any
##     copy the final tmp file to the target
##   update the target hosts file

  for s in ${srcs[@]}
  do
    mkTarg $(realpath ${s})
  done

  trap '' 0
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
