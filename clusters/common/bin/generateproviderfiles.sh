#!/bin/bash

## $Header: $
## Source:
## @file common/provision/bin/generateproviderfiles.sh

## @brief create the various configuration files that may vary dependent upon the active virtualization provider

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
  ## % env VC=vc MODE="host" ../../clusters/common/bin/generateproviderfiles.sh
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

### @todo XXX need a cluster dependency tree config.
### @todo XXX In this case vx is dependent on vc.
if [ "${env_VC}" = "vc" ] ; then
  alt_VC=vx
else
  alt_VC=vc
fi

# if we're given an argument, append test output to it
declare -x SUFFIX=${2:-""}

# this wonkiness is so that this script can orient itself when run by different users
# in different dom0 home directory structures
if [ ! -d "$(cd ${VC}; pwd)" ] ; then
  ErrExit ${EX_CONFIG} "VC:${VC} not a directory?"
fi

declare -x ANCHOR_D=$(realpath ${ANCHOR} 2>&1)
if [ ! -d "${ANCHOR_D}" ] ; then
  ErrExit ${EX_CONFIG} "ANCHOR:${ANCHOR} ANCHOR_D:${ANCHOR_D}"
fi
declare -x ANCHOR_D_UP=$(realpath ${ANCHOR_D}/.. 2>&1)
if [ ! -d "${ANCHOR_D_UP}" ] ; then
  ErrExit ${EX_CONFIG} "ANCHOR_D_UP:${ANCHOR_D_UP}"
fi

declare -x VC_D=$(realpath ${ANCHOR_D_UP}/${env_VC} 2>&1)
if [ ! -d "${VC_D}" ] ; then
  ErrExit ${EX_CONFIG} "VC_D:${VC_D} ANCHOR_D:${ANCHOR_D} ANCHOR_D_UP:${ANCHOR_D_UP}"
fi
declare -x ALT_VC_D=$(realpath ${ANCHOR_D_UP}/${alt_VC} 2>&1)
if [ ! -d "${ALT_VC_D}" ] ; then
  ErrExit ${EX_CONFIG} "alt_VC:${alt_VC} ALT_VC_D:${ALT_VC_D} ANCHOR_D:${ANCHOR_D} ANCHOR_D_UP:${ANCHOR_D_UP}"
fi

# must match Makefile
declare -x GENERATED_FLAG_F=${VC_D}/.regenerated
# this limit should be the time it takes to regenerate whichever virtual node takes the most time
declare -x GENERATED_MAXLIMIT_MINUTES=15

declare -x SRCS_ENV=($(find ${VC_D} -type f -name *%*%))
declare -x SRCS_ALT
declare -x SRCS
if [ "${VC_D}" != "${ALT_VC_D}" ] ; then
  SRCS_ALT=($(find ${ALT_VC_D} -type f -name *%*%))
fi

SRCS=$(echo ${SRCS_ENV[@]} ${SRCS_ALT[@]})

getSRCS() {

  for d in ANCHOR
  do
    local _d="${!d}"
    if [ ! -d "${_d}" ] ; then
      echo "EX_CONFIG: d:${d}=${!d} not a directory pwd:$(pwd)"
      exit ${EX_CONFIG}
    fi
  done

  if [ -z ${SRCS+x} ]; then
    echo "EX_CONFIG: SRCS is unset"
    exit ${EX_CONFIG}
  fi

#  if [ ${#SRCS[@]} -eq 0 ] ; then
#    echo "EX_CONFIG: SRCS list empty"
#    exit ${EX_CONFIG}
#  fi

  for f in ${SRCS[@]}
  do
    if [ ! -f "${f}" ] ; then
      echo "  EX_CONFIG: ${f} missing"
      exit ${EX_CONFIG}
    fi
    if [ ! -s "${f}" ] ; then
      echo "EX_CONFIG:  ${f} empty"
      exit ${EX_CONFIG}
    fi
  done

  echo ${SRCS[@]}
  return
}

declare -x VAGRANTFILE_D=${ANCHOR_D}/Vagrantfile.d
declare -x HOSTS_FILE_TARGET=$(realpath ${VC_D}/common/etc/hosts)
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
      echo "EX_CONFIG: d:${d}=${!d} not a directory pwd:$(pwd)" >&2
      exit ${EX_CONFIG}
    fi
  done

  for f in DEFAULT_PROVIDER HOSTS_FILE
  do
    local _f="${!f}"
    if [ ! -f "${_f}" ] ; then
      echo "  EX_CONFIG: ${f}:${_f} missing" >&2
      exit ${EX_CONFIG}
    fi
    if [ ! -s "${_f}" ] ; then
      echo "EX_CONFIG:  ${f} empty" >&2
      exit ${EX_CONFIG}
    fi
  done

  if [ ! -d "${CFG}" ] ; then
    echo "EX_CONFIG:   VC:${VC}, but CFG:${CFG} ! dir" >&2
    exit ${EX_CONFIG}
  fi

  default_provider=$(cat ${DEFAULT_PROVIDER})
  which_provider=${default_provider}

  if [ ! -f ${CFG_VM_PROVIDERS_D}/${which_provider} ] ; then
    echo "EX_CONFIG: VC:${VC} default_provider:${default_provider} does not exist" >&2
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
  # if no replacement of env_VC, then we use alt_VC
  t_env=${src/.%${env_VC^^}*%/}
  t_alt=${src/.%${alt_VC^^}*%/}
  target=""
  if [ "${src}" = "${t_env}" ] ; then
    target=${t_alt}
  else
    target=${t_env}
  fi
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
  local alt_vc_l=${alt_VC,,}
  local alt_vc_u=${alt_VC^^}

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
  ##   {VC}-NET => ex. 192.168.56
  ##   {VC}-0NET => ex. 192.168.56.0
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e \"/^${provider_val}.0 /s//& ${vc_l}-net     /\" ${TMP2} ;"
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e \"/^${provider_val}.0 /s//& ${alt_vc_l}-net /\" ${TMP2} ;"

  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${vc_u}-NET%/${provider_val}/g"     ${TMP2} ;"
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${alt_vc_u}-NET%/${provider_val}/g" ${TMP2} ;"

  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${vc_u}-0NET%/${provider_val}.0/g"     ${TMP2} ;"
  Rc ErrExit ${EX_SOFTWARE} "sed -i -e "s/%${alt_vc_u}-0NET%/${provider_val}.0/g" ${TMP2} ;"

  Rc ErrExit ${EX_SOFTWARE} "cp -b ${TMP2} ${HOSTS_FILE_TARGET} ;"

  ## @todo add an "excludes pattern" .excludes and "includes pattern" .includes for each cluster's cfg
  local _nodes=$(ls -d ${VC_D}/cfg/* ${ALT_VC_D}/cfg/* | egrep -v '(provision|slurm_version|default_|README)')
  local nodes=""
  local _n
  for _n in ${_nodes}
  do
    if [ -z "${nodes}" ] ; then
      nodes="$(basename ${_n})"
    else
      nodes="${nodes} $(basename ${_n})"
    fi
  done
  local n
  for n in ${vc_u}-NET ${vc_u}-0NET ${alt_vc_u}-NET ${alt_vc_u}-0NET ${nodes}
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
  local k=""
  local n=""
  local ip=""
  local net=""

  for k in ${KEYS[*]}
  do
    n=${k,,}
    n=${n//\%/}

    if [ ${k:1:2} != ${env_VC^^} -a ${k:1:2} != ${alt_VC^^} ] ; then
      local c=""
      local cruft=""
      for c in ${VC_D} ${ALT_VC_D}
      do
        local sp=""
        if [ -f ${c}/cfg/${n} ] ; then
          if [ -n "${cruft}" ] ; then
            sp=" "
          fi
          cruft="${cruft}${sp}${c}/cfg/${n}"
        fi
      done
      ErrExit ${EX_CONFIG} "k:${k} k[1-2]:${k:1:2} != env_VC:${env_VC^^} && != alt_VC:${alt_VC^^}\n\n\"${n}\" is not a valid node specification. (${cruft})"
    fi
    if [ -z "${n}" ] ; then
      ErrExit ${EX_CONFIG} "n empty"
    fi

    # special case the patterns which match the network address or the first three octets
    ip_cracked=($(grep -s -e " ${n} " ${HOSTS_FILE_TARGET} | sed 's/\./ /g' | awk '{print $1" "$2" "$3" "$4}'))
    rc=$?

    if [ "${n}" = "${env_VC,,}-0net" -o "${n}" = "${alt_VC,,}-0net" ] ; then
      if [ -z "${net}" ] ; then
        ErrExit ${EX_SOFTWARE} "net: empty k:${k} [0net]"
      fi
      ip=${net}.0
    else
      if [ "${n}" = "${env_VC,,}-net" -o "${n}" = "${alt_VC,,}-net" ] ; then
        if [ -z "${net}" ] ; then
          n=""
          local j
          for j in 0 1 2
          do
            sep=""
            if [ "${j}" -lt 2 ] ; then
              sep="."
            fi
            n=${n}${ip_cracked[${j}]}${sep}
          done
          net=${n}
        fi
        ip=${net}
      else
        ip="${net}.${ip_cracked[3]}"
      fi
    fi

    if [ ${rc} -ne ${GREP_FOUND} ] ; then
      ErrExit EX_CONFIG "node:${n} not found in ${HOSTS_FILE_TARGET}: ${ip}"
    fi

    NODEKEYTOIPADDR[${k}]="${ip}"
  done
  return
}

main() {
  SetFlags >/dev/null 2>&1
  local argprovider=${1:-_default_provider_}
  local fstype=""
  local provider=""
  local srcs=""

  needs_regen=$(find ${VC} -type f -path ${GENERATED_FLAG_F} -mmin +${GENERATED_MAXLIMIT_MINUTES})
  if [ -f ${GENERATED_FLAG_F} -a -z "${needs_regen}" ] ; then
    exit ${EX_OK}
  fi
  Rc ErrExit ${EX_OSFILE} "rm -f ${GENERATED_FLAG_F}"

  srcs=($(getSRCS))
  rc=$?
  if [ ${rc} -eq ${EX_ALREADY} ] ; then
    exit ${EX_OK}
  fi

  if [ ${rc} -ne ${EX_OK} ] ; then
    ErrExit ${EX_CONFIG} "${srcs[*]}"
  fi

  provider=($(whichProvider))
  if [ ! -f ${CFG_VM_PROVIDERS_D}/${provider} ] ; then
    ErrExit ${EX_CONFIG} "CFG_VM_PROVIDERS_D/provider:${CFG_VM_PROVIDERS_D}/${provider} does not exist"
  fi
  if [ -z "${provider}" ] ; then
    ErrExit ${EX_CONFIG} "provider: empty"
  fi
  if [[ ${provider[0]} == *EX_CONFIG* ]] ; then
    ErrExit ${EX_CONFIG} ${provider[@]}
  fi

  if [ "${provider}" = "libvirt" -a  -f "${NO_NFS}" ] ; then
    Warn ${EX_CONFIG} "provider:${provider} requires NFS, but NO_NFS flag is set."
  fi

#  if [ -n "${DO_EXTREMELY_SLOW_CALLOUT_TO_VAGRANT}" ] ; then
    # any existent nodes from a different provider than what we have requested?
    running_nodes=$(vagrant global-status | \
                    egrep -i '(running|shutoff|poweredoff|halt)' | grep -v "${provider}" | \
                    awk '{print $2}')
    if [ -n "${running_nodes}" ] ; then
      ErrExit ${EX_CONFIG} "There are running nodes: ${running_nodes} that were not provisioned by: ${provider}."
    fi
#  fi

  KEYS=($(primeSubstKeys ${provider}))
  buildNodeToIPMap

  trap "rm -f ${TMP1} ${TMP2} ${GENERATED_FLAG_F}" HUP INT QUIT TERM

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
##  leave flag file behind, for make coordination

  for s in ${srcs[@]}
  do
    mkTarg $(realpath ${s})
  done

  trap 'date > ${GENERATED_FLAG_F}' 0
  echo -n '.'
  exit ${EX_OK}
}

main $@

ErrExit ${EX_SOFTWARE} "FAULTHROUGH"
exit ${EX_SOFTWARE}

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
