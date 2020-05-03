#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/orderofoperations.h.sh

## @brief This header file defines order of operations. In some cases, especially those requiring
## custom configuration, it may be appropriate to rearrange the provisioning order of operations.

# Order of functions called
# @todo future allow main option parsing to trigger which or an arbitrary selection of these to enable severable debuggability

# This structure allows us (eventually) to invoke each of these separately
# for debugging and/or unprovisioning.

declare -x CORE_ORDER_OF_OPERATIONS="SetFlags TimeStamp VerifyEnv               	  \
                                     CopyHomeVagrant CopyCommonProvision OverlayRootFS    \
                                     AppendFilesRootFS InstallEarlyRPMS                   \
                                     ConfigureLocalRepos WaitForPrerequisites InstallRPMS \
                                     BuildSW InstallLocalSW ConfigSW SetServices UserAdd  \
                                     VerifySW UpdateRPMS MarkNodeProvisioned              "

declare -x DEBUG_DEFAULT_ORDER_OF_OPERATIONS="DebugNote VerbosePWD ClearSELinuxEnforce  \
                                              ${CORE_ORDER_OF_OPERATIONS}               \
                                              Timestamp                                 "


declare -x NORMAL_ORDER_OF_OPERATIONS="${CORE_ORDER_OF_OPERATIONS}                       \
                                       SetVagrantfileSyncFolderDisabled FlagSlashVagrant \
                                       TimeStamp                                         "

## yes, there's a bash one-liner to do this, but no, this may be more readable 
if [ -n "${DEBUG}" ] ; then
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${DEBUG_DEFAULT_ORDER_OF_OPERATIONS}
else
  declare -x DEFAULT_ORDER_OF_OPERATIONS=${NORMAL_ORDER_OF_OPERATIONS}
fi

