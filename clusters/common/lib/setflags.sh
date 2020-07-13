#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/setflags.sh

## @brief This library file contains a commonly called routine to ingest
## flags from the file system which affect the running behavior of the script

## @fn IsLANL()
## @side effect: sets http_proxy, https_proxy
##
IsLANL() {
  if [ -z "${IS_LANL_PINGABLE}" ] ; then
    ErrExit ${EX_CONFIG} "empty IS_LANL_PINGABLE"
  fi
  if [ -z "${LANL_PROXY}" ] ; then
    ErrExit ${EX_CONFIG} "empty LANL_PROXY"
  fi

  ping -c 1 -i 0.1 -w 1 -n ${IS_LANL_PINGABLE} >/dev/null 2>&1
  rc=$?

  if [ ${rc} != ${EX_OK} ] ; then
    export PREFERRED_REPO=""
    return ${rc}
  fi

  export http_proxy=http://${LANL_PROXY}/
  export https_proxy=http://${LANL_PROXY}/
  export RSYNC_PROXY=${LANL_PROXY}
  export IS_LANL="true"

  if [ -n "${PREFERRED_REPO}" ] ; then
    ## XXX validity check that PREFERRED_REPO is an actual URL, else use DEFAULT_PREFERRED_REPO
    export PREFERRED_REPO=${DEFAULT_PREFERRED_REPO}
  fi
  return ${rc}
}

## @fn SetFlags()
## Set flags within our execution, based on their existence in the configuration specifier
##
SetFlags() {
  export OUTPUT_PROTOCOL=stdout
  local flags
  local set_flags=""

  if [ -L ${VC} ] ; then
    Warn ${EX_OSFILE} "VC: ${VC} symlink? -- ensure that \", disabled: true\" is removed from the synced_folder entry in Vagrantfile for ${HOSTNAME}"
    return
  fi

  if [ ! -d ${VC} ] ; then
    Warn ${EX_OSFILE} "VC: ${VC} not mounted? -- ensure that \", disabled: true\" is removed from the synced_folder entry in Vagrantfile for ${HOSTNAME}"
    return
  fi

  if [ -z "${FLAGS}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty FLAGS"
  fi

  if [ ! -d ${FLAGS} ] ; then
    ErrExit ${EX_SOFTWARE} "${FLAGS}: No such directory "
  fi

  flags=$(echo $(ls ${FLAGS}))
  for f in ${flags}
  do
    case $f in
    DEBUG)
    	export TAR_DEBUG_ARGS="v"
        export DEFAULT_ORDER_OF_OPERATIONS=${DEBUG_DEFAULT_ORDER_OF_OPERATIONS}
        export TAR_CHECKPOINT_DEBUG_ARGS="--checkpoint=1024 --checkpoint-action=dot"
        set_flags="${set_flags} TAR_DEBUG_ARGS DEBUG_DEFAULT_ORDER_OF_OPERATIONS"
	;;
    DISABLE_RM)
        if [ -s ${FLAGS}/DISABLE_RM ] ; then
          export DISABLE_RM=$(cat ${FLAGS}/DISABLE_RM)
          if [ -n "${DISABLE_RM}" ] ; then
            set_flags="${set_flags} DISABLE_RM='${DISABLE_RM}'"
          fi
        fi
        ;;
    no-yum)
    	export YUM="echo '>>> yum'"
        set_flags="${set_flags} no-yum"
	;;
    VERBOSE)
    	export VERBOSE="true"
        set_flags="${set_flags} VERBOSE"
	;;
    HALT_PREREQ_ERROR)
        export HALT_PREREQ_ERROR="true"
        set_flags="${set_flags} HALT_PREREQ_ERROR"
        ;;
    HALT_ERREXIT)
        export HALT_ERREXIT="true"
        set_flags="${set_flags} HALT_ERREXIT"
        ;;
    HUSH_OUTPUT)
        export HUSH_OUTPUT="true"
        set_flags="${set_flags} HUSH_OUTPUT"
        ;;
    BUILD_LUSTRE_FLAG)
        export LUSTRE="true"
        set_flags="${set_flags} LUSTRE"
        ;;
    ONLY_REMOTE_REPOS)
        # doesn't make sense to rsync to local repo, if using remote repositories
        if [ -n "${RSYNC_CENTOS_REPO}" ] ; then
          export RSYNC_CENTOS_REPO=""
        fi
        export ONLY_REMOTE_REPOS="true"
        set_flags="${set_flags} ONLY_REMOTE_REPOS"
        ;;
    PREFERRED_REPO)
        export PREFERRED_REPO=$(cat ${FLAGS}/PREFERRED_REPO)
        IsLANL
        if [ -n "${PREFERRED_REPO}" ] ; then
          set_flags="${set_flags} PREFERRED_REPO='${PREFERRED_REPO}'"
        fi
        ;;
    RSYNC_CENTOS_REPO)
        # doesn't make sense to rsync to local repo if only using remote repositories
        if [ -z "${ONLY_REMOTE_REPOS}" ] ; then 
          export RSYNC_CENTOS_REPO="true"
          set_flags="${set_flags} RSYNC_CENTOS_REPO"
        fi
        ;;
    SKIP_SW)
        export SKIP_SW=$(cat ${FLAGS}/SKIP_SW)
        set_flags="${set_flags} SKIP_SW:\"${SKIP_SW}\""
	if [ -n "${NO_NFS}" ] ; then
		if [[ "${SKIP_SW}" != *vboxadd* ]] ; then
			Warn ${EX_CONFIG} "  Virtualbox shared folders (vboxsf) are enabled (not skipped)"
			Warn ${EX_CONFIG} "  but NO_NFS is set, also."
			Warn ${EX_CONFIG} "  Provisioning would halt with no source upon upgrading the"
			Warn ${EX_CONFIG} "  the virtualbox guest additions."
			Warn ${EX_CONFIG} "  "
			Warn ${EX_CONFIG} "  To remediate: set clusters/common/flag/SKIP_SW to 'vboxadd'"
			Warn ${EX_CONFIG} "  To remediate:     or remove NO_NFS flag"
		fi
	fi
        ;;
    SKIP_UPDATERPMS)
        export SKIP_UPDATERPMS="true"
        set_flags="${set_flags} SKIP_UPDATERPMS"
        ;;
    SKIP_YUMDOWNLOAD|SKIP_YUMDOWNLOADS)
        export SKIP_YUMDOWNLOAD="true"
        set_flags="${set_flags} SKIP_YUMDOWNLOAD"
        ;;
    TIMESTAMPS)
        # if the TIMESTAMPS flag exists & is non-zero length, it may be a format for timestamps
	# if DEFAULT_TIMESTAMP_FORMAT is set in the env. use it
	# gnuplot likes the format of: +%d-%H-%M-%S.%6N
	DEFAULT_TIMESTAMP_FORMAT="${DEFAULT_TIMESTAMP_FORMAT:-+%d-%H-%M-%S.%6N }"
        export TIMESTAMPS="${DEFAULT_TIMESTAMP_FORMAT}"
	if [ -s ${FLAGS}/TIMESTAMPS ] ; then
          TIMESTAMPS=$(cat ${FLAGS}/TIMESTAMPS)
	  # date returns !EX_OK if its argument isn't a valid format
	  date "${TIMESTAMPS}" >/dev/null 2>&1
	  rc=$?
	  if [ "${rc}" -ne ${EX_OK} ] ; then
            TIMESTAMPS="${DEFAULT_TIMESTAMP_FORMAT}"
	  fi
	fi
        set_flags="${set_flags} TIMESTAMPS:${TIMESTAMPS}"
	;;
    NO_NFS)
        if [ -s ${FLAGS}/NO_NFS ] ; then
	  NO_NFS=$(cat ${FLAGS}/NO_NFS)
          set_flags="${set_flags} NO_NFS:${NO_NFS}"
        else
          export NO_NFS="NO_NFS"
          set_flags="${set_flags} NO_NFS"
	fi
	if [[ "${SKIP_SW}" != *vboxadd* ]] ; then
		Warn ${EX_CONFIG} "  Virtualbox shared folders (vboxsf) are enabled (not skipped) but NO_NFS is set, also."
		Warn ${EX_CONFIG} "  Provisioning would halt with no source upon upgrading the"
		Warn ${EX_CONFIG} "  virtualbox guest additions."
		Warn ${EX_CONFIG} "  "
		Warn ${EX_CONFIG} "  To remediate: "
		Warn ${EX_CONFIG} "      set clusters/common/flag/SKIP_SW to 'vboxadd' or remove NO_NFS flag"
	fi
	;;
    esac
  done
  Verbose "Flags: ${set_flags}"
  return
}
