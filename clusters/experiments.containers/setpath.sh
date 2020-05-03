#!/bin/bash

provision_bin=cc/cfg/provision/bin
PWD=$(pwd)

case "${PATH}" in
*${provision_bin}*)	;;
*)	export PATH=${PATH}:${PWD}/${provision_bin} ;;
esac

