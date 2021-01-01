#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/ingestfiles.h.sh

## @brief This header file contains parameters related to bulk ingestion of files, rsync, tar, cp, yum, &c

## CENTOS_RSYNC_REPO_URL A reasonably short list of repositories which provide the rsync protocol
declare -x CENTOS_RSYNC_REPO_URL=(          \
    "rsync://linux.mirrors.es.net"          \
    "rsync://centos.sonn.com/CentOS"        \
    "rsync://mirrors.ocf.berkeley.edu"      \
    "rsync://rsync.gtlib.gatech.edu"        \
    "rsync://mirrors.kernel.org"            \
    "rsync://mirror.math.princeton.edu/pub" \
    "rsync://mirror.cc.columbia.edu"        \
    "rsync://mirror.es.its.nyu.edu"         \
    "rsync://mirrors.rit.edu"               \
    "rsync://mirrors.cat.pdx.edu"           \
)

##
declare -x YUM=$(which yum)

declare -x TAR_DEBUG_ARGS=${TAR_DEBUG_ARGS:-""}
declare -x TAR_ARGS="xBp"
declare -x TAR_CHECKPOINT_DEBUG_ARGS="--checkpoint=1024 --checkpoint-action=dot"
declare -x TAR_CHECKPOINT_ARGS=""

declare -x TAR_OVERWRITE="--overwrite"
declare -x TAR_LONG_ARGS="${TAR_CHECKPOINT_ARGS} ${TAR_OVERWRITE}"

declare -x YUM_TIMEOUT_BASE=20
declare -x YUM_TIMEOUT_EARLY=$(expr ${YUM_TIMEOUT_BASE} \* 12)
declare -x YUM_TIMEOUT_INSTALL=$(expr ${YUM_TIMEOUT_BASE} \* 24)
declare -x YUM_TIMEOUT_UPDATE=$(expr ${YUM_TIMEOUT_BASE}  \* 48)
declare -x REPOSYNC_TIMEOUT_COEFFICIENT=4
declare -x YUM_RETRY_LIMIT=3

## RSYNC_RETRY_LIMIT How many times to attempt to rsync
declare -x RSYNC_RETRY_LIMIT="7"
declare -x RSYNC_TIMEOUT_DRYRUN=$(expr ${YUM_TIMEOUT_BASE} / 2)
declare -x RSYNC_TIMEOUT=$(expr ${YUM_TIMEOUT_BASE} \* 2)

## cluster-internal repository linkage
## @see cfgfs.h.sh
declare -x YUM_REPOS_D=/etc/yum.repos.d
declare -x YUM_CENTOS_REPO_LOCAL=CentOS-Base-local.repo
declare -x YUM_CENTOS_REPO_REMOTE=CentOS-Base.repo
declare -x YUM_CENTOS_RELEASEVER=7
