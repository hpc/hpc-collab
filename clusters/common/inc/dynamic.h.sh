#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/dynamic.h.sh

## @brief This header file sets initial values for dynamic run-time parameters.

declare -x ARCH=$(uname -m)
declare -x HOSTNAME=$(hostname -s)
declare -x IAM=$(basename $0 .sh)
declare -x IAMFULL=${0}
declare -x ORIGPWD=$(pwd)
declare -x PGID=${PGID:-$(($(ps -o pgid= -p "$$")))}
