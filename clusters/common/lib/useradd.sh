#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/useradd.sh

## @brief This library file contains a routine add a user to this node and a set of slurm account associations
## @brief It may be called as the node is provisioned, or after provisioning from an in-cluster driver

## @fn AddUserAccount()
## remove state that was created or is stale
## @param USERADD configuration skeleton directory
## @return void
## \callgraph
## \callergraph
##
AddUserAccount() {
	local USERADD_u=${1:-"_no_useradd_u_"}
	local	USERADD_d=$(dirname ${USERADD_u})

  local uid=""
  local gid=""
  local shell_arg=""
  local shell
  local shellpath
  local groups
  local group_arg
  local dir_arg
  local exists
  local multiple=""
  local numeric="^[0-9]+$"
	local _d

	for _d in USERADD_u USERADD_d
	do
		if [ ! -d "${!_d}" ] ; then
		ErrExit ${EX_SOFTWARE} "${_d}:${!_d} is not a directory"
		fi
	done

  cd ${USERADD_u} || ErrExit ${EX_OSERR} "cd ${USERADD_u}"

  if [ -d multiple ] ; then
    multiple=$(echo $(ls multiple))
  fi
  if [ -z "${multiple}" ] ; then
    multiple=1
  fi
  if ! [[ ${multiple} =~ ${numeric} ]] ; then
    ErrExit ${EX_CONFIG} "user: ${multiple}, non-numeric"
  fi

  if [ ! -d uid ] ; then
    ErrExit ${EX_CONFIG} "user: ${u}, no uid"
  fi
  uid=$(echo $(ls uid))
  if [ ! -d gid ] ; then
    ErrExit ${EX_CONFIG} "user: ${u}, no gid"
  fi
  gid=$(echo $(ls gid))

	# if a multi-account spec, loop through them, using the cfg skeleton from the primary
  for m in $(echo $(seq 1 ${multiple}))
  do
    local U=${u}
    local _uid
    local _gid
    local msg=""

    _uid=$(expr ${uid} + ${m} - 1)
    _gid=$(expr ${gid} + ${m} - 1)

    if [ "${multiple}" -eq 1 ] ; then
      U=${u}
    else
      U="${u}${m}"
    fi
    msg="${msg} ${U}: "

    if [ -d shell ] ; then
      shell=$(ls shell)
      shellpath=$(which $shell 2>&1)
      if [ -x "${shellpath}" ] ; then
        shell_arg="-s ${shellpath}"
      else
        Verbose "  Warning: ${shellpath} -- not executable"
      fi
    fi

    group_arg=""
    if [ -d groups ] ; then
      local ls_groups=$(echo $(ls groups))
      groups=$(echo ${ls_groups} | sed 's/ /,/g')

      if [ -n "${groups}" ] ; then 
        group_arg="-G ${groups}"
        msg="${msg} groups:${groups}"
      fi
    fi

    dir_arg=""
    dir=""
    if [ -d ${HOME_BASEDIR} -o -d ${HOME_BASEDIR}/${U} ] ; then
      if [ -d ${HOME_BASEDIR}/${U} ] ; then
        dir_arg="-d ${HOME_BASEDIR}/${U}"
        dir=${HOME_BASEDIR}/${U}
      elif [ -d ${HOME_BASEDIR} ] ; then
        dir_arg="-b ${HOME_BASEDIR}"
        dir=${HOME_BASEDIR}/${U}
      fi
    fi

    exists=$(echo $(getent passwd ${U} 2>&1))
    if [ -z "${exists}" ] ; then
      gid_explicit=""
      if (( ${uid} != ${gid} )) ; then
        group_arg="-G ${_gid}"
      else
        gid_explicit="-U"
      fi
      Rc ErrExit ${EX_OSERR} "useradd -u ${_uid} ${gid_explicit} -o ${shell_arg} ${group_arg} ${dir_arg} ${U}"
    else
      if [ -n "${shell_arg}" ] ; then
        Rc ErrExit ${EX_OSERR} "chsh ${shell_arg} ${U}"
      fi
      if [ -n "${group_arg}" ] ; then
        Rc ErrExit ${EX_OSERR} "usermod ${group_arg} ${U}"
      fi
      if [[ ${dir_arg} =~ -d ]] ; then
        Rc ErrExit ${EX_OSERR} "usermod ${dir_arg} ${U}"
      fi
    fi

    if [ -d "${USERADD_PASSWD}" ] ; then
      if [ ! -f "${USERADD_PASSWD_CLEARTEXT}" -a ! -f "${USERADD_PASSWD_ENCRYPTED}" ] ; then
        msg="${msg} -passwd"
        Rc ErrExit ${EX_OSERR} "passwd -d ${U} >/dev/null 2>&1"

      elif [ -f "${USERADD_PASSWD_ENCRYPTED}" -a -s "${USERADD_PASSWD_ENCRYPTED}" ] ; then
        local pw=$(echo $(cat ${USERADD_PASSWD_ENCRYPTED}))
        Rc ErrExit ${EX_OSERR} "echo \"${U}:${pw}\" | chpasswd -e"

      elif [ -f "${USERADD_PASSWD_CLEARTEXT}" -a -s "${USERADD_PASSWD_CLEARTEXT}" ] ; then
        local pw=$(echo $(cat ${USERADD_PASSWD_CLEARTEXT}))
        Verbose "   Note: setting cleartext passwd for user:${U} (Ensure PermitEmptyPasswords is allowed in sshd_config.)"
        Rc ErrExit ${EX_OSERR} "echo \"${U}:${pw}\" | chpasswd "

      else
        ErrExit ${EX_CONFIG} "broken password config: ${USERADD}/${U}/${USERADD_PASSWD}"
      fi
    fi

    if [ -d ${USERADD_u}/secontext ] ; then
      local u_secontext=$(echo $(ls ${USERADD_u}/secontext))
      if [ -n "${u_secontext}" ] ; then
        if [ -d ${dir} ] ; then
          local fstyp=$(stat -f --format="%T" ${dir})
					local existing_secontext=""
          case "${fstyp}" in
          xfs|ext*|jfs|ffs|ufs|zfs)
						existing_secontext=$(ls -Ld --scontext | awk '{print $1}')
						if [ "${existing_secontext}" != "${u_secontext}" ] ; then
							Rc ErrExit ${EX_OSERR} "chcon -R ${u_secontext} ${dir}"
						fi
            local u_setype=$(echo "${u_secontext}" | sed 's/:/ /g' | awk '{print $3}')
            if [ -z "${u_setype}" ] ; then
              ErrExit ${EX_CONFIG} "${u}:empty u_setype, u_secontext:${u_secontext}" 
            fi
            Rc ErrExit ${EX_OSERR} "semanage fcontext -a -t ${u_setype} ${dir}/\(/.*\)\? ;"
            ;;
          nfs)
            # silently skip
            ;;
          *)
            Verbose " unable to set secontext:${u_secontext}"
            Verbose " on dir: ${dir}, which has a file system type,"
            Verbose " fstype:${fstyp}  which does not implement secontext extended attributes."
            ;;
          esac
        fi
      fi
    fi

    if [ -d ${dir} ] ; then
      if [ ! -L /home/${U} ] ; then
        Rc ErrExit ${EX_OSFILE} "ln -f -s ${dir} /home/${U}"
      fi
      Rc ErrExit ${EX_OSFILE} "chown -h ${U} /home/${U} >/dev/null 2>&1"
      Rc ErrExit ${EX_OSFILE} "chown -R ${U} ${dir}     >/dev/null 2>&1"
    fi

		# user specification may include sudo privileges
    if [ ! -d "${ETC_SUDOERS_D}" ] ; then
      ErrExit ${EX_OSFILE} "${ETC_SUDOERS_D}: not a directory or does not exist, ${u}"
    fi
    local u_sudoers_d=${USERADD_u}/${SUDOERS_D}
    if [ -d "${u_sudoers_d}" ] ; then
      if [ -f "${u_sudoers_d}/${u}" ] ; then
        Rc ErrExit ${EX_OSFILE} "cp ${u_sudoers_d}/${u} ${ETC_SUDOERS_D}/${U}"
        Rc ErrExit ${EX_OSFILE} "sed -i -e 's/${u}/${U}/' ${ETC_SUDOERS_D}/${U} ; "
        msg="${msg} +sudo"
      fi
    fi
    Verbose " ${msg}"
    Verbose ""
    msg=""

		# convenient symlink glue
    if [ -d "${USERADD_d}/${U}" ] ; then
      local _home=${HOME_BASEDIR}/${U}
      local home_useradd=${_home}/useradd
      local useradd_d=${USERADD_d}/${U}

      Rc ErrExit ${EX_OSFILE} "chown -R -h ${U}:${U} ${useradd_d}"
      if [ -d "${useradd_d}/useradd" ] ; then
        Rc ErrExit ${EX_OSFILE} "ln -s ${useradd_d} ${home_useradd}"
        Rc ErrExit ${EX_OSFILE} "chown -h ${U}:${U} ${home_useradd}"
      fi
    fi

  done # m in $(echo $(seq 1 ${multiple}))
	return
}

## @fn AddSlurmAccountUserAssociations()
## @brief Add user assocations in slurm for this account
## @param USERADD configuration skeleton directory
## @return void
## \callgraph
## \callergraph
##
AddSlurmAccountUserAssociations() {
	local USERADD_u=${1:-"_no_useradd_u_"}
	local	USERADD_d=$(dirname ${USERADD_u})

  local slurm_attr=${USERADD_u}/slurm
  local multiple_attr="${USERADD_u}/multiple"
  local slurm_acct=${slurm_attr}/acct
  local slurm_qos=${slurm_attr}/qos
  local slurm_assoc=${slurm_attr}/assoc
  local slurm_adminlevel=${slurm_attr}/AdminLevel
  local DefaultAccount=""
  local accounts=""
  local associations=""
  local multiple=""
  local qos_exists=""
	local clustername
	local _d
	local _u=$(basename ${USERADD_u})
	local qsufx=""

	for _d in USERADD_u USERADD_d
	do
		if [ ! -d "${!_d}" ] ; then
			Warn ${EX_SOFTWARE} "Warning:	${_d}:${!_d} is not a directory"
		fi
	done

	clustername=$(scontrol show config | grep -i clustername | awk '{print $3}')
	if [ -z "${clustername}" ] ; then
		ErrExit ${EX_SOFTWARE} "clustername not defined in slurm configuration"
	fi
	account_exists=$(sacctmgr -iQ show account default -n cluster=${clustername} withassoc | grep "${clustername}" | awk '{print $1}' | head -1)
	if [ -z "${account_exists}" ] ; then
		ErrExit ${EX_SOFTWARE} "account \"default\" does not exist"
	fi

  # may be a login-only account
  if [ ! -d ${slurm_acct} ] ; then
    return
  fi

	# a skeleton template
  if [ "${_u}" = "User.Template" -o  "${_u}" = "user.template" -o -f ${USERADD_u}/Template ] ; then
		return
  fi

	qsufx="__${clustername}"
  if [ -d ${slurm_acct}/DefaultAccount ] ; then
    DefaultAccount=$(echo $(ls ${slurm_acct}/DefaultAccount) | awk '{print $1}')
  fi
  if [ -d ${slurm_acct}/Accounts ] ; then
    accounts=$(echo $(ls ${slurm_acct}/Accounts))
  fi

  if [ -d ${slurm_attr}/qos ] ; then
    qos=$(echo $(ls ${slurm_attr}/qos))
  fi
  qosadded=""
  qos_exists=$(echo $(sacctmgr show qos -n name=${qos}${qsufx} format=name%-30))
  if [ -z "${qos_exists}" ] ; then
    Rc ErrExit ${EX_SOFTWARE} "sacctmgr -iQ add qos name=${qos}${qsufx} ;"
    qosadded="${qosadded} ${qos}${qsufx}"
  fi

  if [ -n "${qosadded}" ] ; then
    Verbose "  added qos: ${qosadded}"
  fi

  multiple=""
  numeric="^[0-9]+$"
  if [ -d ${multiple_attr} ] ; then
    multiple=$(echo $(ls ${multiple_attr}))
  fi
  if [ -z "${multiple}" ] ; then
    multiple=1
  fi
  if ! [[ ${multiple} =~ ${numeric} ]] ; then
    ErrExit ${EX_CONFIG} "user: ${multiple}, non-numeric"
  fi

  for m in $(seq 1 ${multiple})
  do
    U=${u}
    if [ ${multiple} -gt 1 ] ; then
      U=${u}${m}
    fi

    associations=$(echo $(ls ${slurm_assoc}))
    for a in ${associations}
    do
      _p=""
      _q=""
      _a=""
      exists=""
      def_arg=""

      _p=$(basename $(echo $(readlink ${slurm_assoc}/${a}/partition)))
      _q=$(basename $(echo $(readlink ${slurm_assoc}/${a}/qos)))
      _a=$(basename $(echo $(readlink ${slurm_assoc}/${a}/acct)))

      q="qos=${qos}${qsufx}"
      namepartacctcluster="name=${U} partition=${_p} account=${_a} cluster=${clustername}"
      exists=$(sacctmgr show user withassoc -n ${namepartacctcluster} ${q} | egrep "${clustername}.*${_a}.*${_p}.*${qos}")
      if [ -n "${DefaultAccount}" ] ; then
        def_arg="defaultaccount=${DefaultAccount}"
      fi
      if [ -z "${exists}" ] ; then
        Rc ErrExit 9 "sacctmgr -iQ add user ${namepartacctcluster} ${q} ${def_arg}"
      else
        Rc ErrExit 10 "sacctmgr -iQ modify user ${namepartacctcluster} ${q} set ${def_arg}"
        Rc ErrExit 11 "sacctmgr -iQ modify user ${namepartacctcluster} set default${q}"
      fi
    done #associations

    if [ -d "${slurm_adminlevel}" ] ; then
      _adminlevel=$(echo $(ls ${slurm_adminlevel}))
      case "${_adminlevel}" in
        *"perator"|*"dministrator")
          Rc ErrExit 12 "sacctmgr -iQ update user name=${U} cluster=${clustername} set AdminLevel=${_adminlevel}"
          ;;
        "")
          ;;
        *)
          ErrExit 13 "${U}: unknown AdminLevel ${_adminlevel}"
          ;;
        esac
    fi
  done #multiple
	return
}

# vim: set ts=2 bs=2 sw=2 syntax
