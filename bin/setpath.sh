#!/bin/bash

BASE=${HOME}/hpc-collab
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

for n in ${nodes}
do
  declare -x cl=${n:0:2}

  declare -x cluster_dir=${CLUSTERS}/${cl}
  alias	"${n}"="touch ${n}.out; nohup make -C ${cluster_dir} ${n} > ${n}.out &"
  alias	"${n}!"="touch ${n}.out; make -C ${cluster_dir} ${n}_UNPROVISION; nohup make -C ${cluster_dir} ${n} > ${n}.out &"
  alias	"${n}--"="make -C ${cluster_dir} ${n}_UNPROVISION" 

  # yes, this redefines the alias for multiple nodes; that is not costly
  alias	"${cl}"="touch ${cl}.up.out ;nohup make -C ${cluster_dir} up > ${cl}.up.out &"
  alias	"${cl}--"="make -C ${cluster_dir} unprovision"
  alias	"${cl}!"="make -C ${cluster_dir} unprovision; touch ${cl}.up.out; nohup make -C ${cluster_dir} up > ${cl}.up.out &"
done

# common aliases for all clusters:
alias "up"="nohup make -s -C ${BASE} up > up.out &"
for t in help show pkg prereq provision unprovision down
do
  alias "${t}"="make -s -C ${BASE} ${t}"
done
alias  "savelogs"="env TMPDIR=. make -C ${CLUSTERS} savelogs"

# when/if needed
# ssh-add ${CLUSTERS}/*/.vag*/machines/*/virtualbox/private_key > /dev/null 2>&1
