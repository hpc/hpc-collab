#!/bin/bash

shopt -s expand_aliases

#BASE=${HOME}/hpc-collab
BASE=${PWD}
if [ $(basename "${BASE}") = "bin" ] ; then
  BASE=${BASE}/..
fi
CLUSTERS=${BASE}/clusters
provision_bin=${BASE}/bin
clusters_bin=${CLUSTERS}/common/bin
PWD=$(pwd)

export HUSH=@
if ! [[ ${MAKEFLAGS} =~  --quiet ]] ; then
  export MAKEFLAGS="${MAKEFLAGS} --quiet"
fi

for e in ${provision_bin} ${clusters_bin}
do
  case "${PATH}" in
    *${e}*)				;;
    *)	export PATH=${PATH}:${e}	;;
  esac
done

# XXX @todo collect enabled clusters (vc,vx) dynamically, similarly to the Makefile,
## that is, they are enabled if a Makefile and a Vagrantfile is present

set nodes=""
for n in $(ls -d ${CLUSTERS}/{vc,vx}/cfg/* | grep -v provision | egrep 'vc|vx' | sort -d | uniq)
do
  nodes="${nodes} $(basename ${n})"
done

# node aliases:
#  <nodename>	==> <nodename> up
#  <nodename>--	==> unprovision <nodename>
#  <nodename>!	==> unprovision and then bring <nodename> up, without regard to its previous state

# cluster aliases:
#  <cluster>	=> <cluster> up
#  <cluster>--	=> unprovision <cluster>
#  <cluster>!	==> unprovision and then bring <cluster> up, without regard to its previous state

declare -x computes=""

for n in ${nodes}
do
  declare -x cl=${n:0:2}

  declare -x cluster_dir=${CLUSTERS}/${cl}
  alias	"${n}"="make -C ${cluster_dir} ${n}"
  alias	"${n}!"="make -C ${cluster_dir} ${n}_UNPROVISION; nohup make -C ${cluster_dir} ${n}"
  alias	"${n}--"="make -C ${cluster_dir} ${n}_UNPROVISION"

  if [[ ${n} = *?[0-9]* ]] ; then
    computes="${computes} ${n}"
  fi

  # yes, this redefines the alias for multiple nodes; that is not costly
  alias	"${cl}"="make -C ${cluster_dir} up"
  alias	"${cl}--"="make -C ${cluster_dir} unprovision"
  alias	"${cl}!"="make -C ${cluster_dir} unprovision; make -C ${cluster_dir} up"
done

computes() {
  for n in ${computes}
  do
    declare -x cl=${n:0:2}
    declare -x cluster_dir=${CLUSTERS}/${cl}
    make -C ${cluster_dir} ${n}
  done
}

computes_unprovision() {
  for n in ${computes}
  do
    declare -x cl=${n:0:2}
    declare -x cluster_dir=${CLUSTERS}/${cl}
    make -C ${cluster_dir} ${n}_UNPROVISION
  done
}

computes_bounce() {
  for n in ${computes}
  do
    declare -x cl=${n:0:2}
    declare -x cluster_dir=${CLUSTERS}/${cl}
    make -C ${cluster_dir} ${n}!
  done
}
alias computes!=computes_bounce

# common aliases for all clusters:
alias "up"="(nohup make -s -C ${BASE} up 2>&1 >up.out ; echo output in: up.out ) &"
for t in help show pkg prereq provision unprovision down
do
  alias "${t}"="make -s -C ${BASE} ${t}"
done
alias  "savelogs"="( cd ${CLUSTERS}/vc ; env VC=vc ../common/bin/savelogsdb.sh )"

# when/if needed
# ssh-add ${CLUSTERS}/*/.vag*/machines/*/virtualbox/private_key > /dev/null 2>&1

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
