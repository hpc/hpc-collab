#!/bin/csh

#set BASE=${HOME}/hpc-collab
set BASE=${PWD}
set CLUSTERS=${BASE}/clusters

# XXX @todo collect these dynamically, similarly to the Makefile
set ENABLED_CLUSTERS=(vc vx)

set provision_bin=${BASE}/bin
set clusters_bin=${CLUSTERS}/common/bin
set PWD=`pwd`

setenv HUSH	 @
if ( $?MAKEFLAGS ) then
	setenv MAKEFLAGS "${MAKEFLAGS} --quiet"
else
	setenv MAKEFLAGS "--quiet"
endif

foreach e ( ${provision_bin} ${clusters_bin} )
  set present=""
  foreach p ($path)
    if ( "${p}" == "${e}" )  then
      set present=true
    endif
  end
  if ( "${present}" != "true" ) then
    switch ($PATH)
      case *${e}*:
  	breaksw
      default:
	set path=($path ${e})
	breaksw
      endsw
  endif
end

set nodes=""
foreach c (${ENABLED_CLUSTERS})
  set nodes_dirs=`ls -d ${CLUSTERS}/${c}/cfg/* |& cat`
  foreach n (${nodes_dirs})
    if ( -d ${n} && ! -l ${n} ) then
      set nodes=(${nodes} `basename ${n}`)
    endif
  end
end

# node aliases:
#  <nodename>	==> <nodename> up
#  <nodename>--	==> unprovision <nodename>
#  <nodename>!	==> unprovision and then bring <nodename> up, without regard to its previous state

# cluster aliases:
#  <cluster>	=> <cluster> up
#  <cluster>--	=> unprovision <cluster>
#  <cluster>!	==> unprovision and then bring <cluster> up, without regard to its previous state

set computes=""

foreach n ($nodes)
  set cl=`echo ${n}| cut -c1-2`
  set cluster_dir=${CLUSTERS}/${cl}
  alias	"${n}"		"nohup make -C ${cluster_dir} ${n}; date"
  alias	"${n}!"		"make -C ${cluster_dir} ${n}_UNPROVISION; nohup make -C ${cluster_dir} ${n}"
  alias	"${n}--"	"make -C ${cluster_dir} ${n}_UNPROVISION"

  set iscompute=`expr index ${n} '0123456789'`
  if ( "${iscompute}" != 0 ) then
    set computes=`echo ${computes} ${n} | sort | uniq`
  endif

  # yes, this redefines the alias for multiple nodes; that's not costly in csh
  alias	"${cl}"		"nohup make -C ${cluster_dir} up; date"
  alias	"${cl}--"	"make -C ${cluster_dir} unprovision"
  alias	"${cl}!"	"make -C ${cluster_dir} unprovision; nohup make -C ${cluster_dir} up"
end

set computes="${computes} "
set computes_up=`echo "${computes}" | sed 's/ /;/g'`
set computes_unprovision=`echo "${computes}" | sed 's/ /-- ;/g'`
set computes_bounce=`echo "${computes}" | sed 's/ /! ;/g'`

alias computes "${computes_up}"
alias computes-- "${computes_unprovision}"
alias computes! "${computes_bounce}"

# common aliases for all clusters:
alias "up"		"nohup make -s -C ${BASE} up; date"

foreach t (show pkg prereq provision unprovision down)
  alias "${t}"		"make -s -C ${BASE} ${t}"
end
alias  "savelogs"	"( cd ${CLUSTERS}/vc ; env VC=vc ../common/bin/savelogsdb.sh )"
foreach t (savehome synchome)
  alias  "${t}"	"( cd ${CLUSTERS}/vc ; env VC=vc ../common/bin/synchome.sh )"
end

# when/if needed
#ssh-add ${CLUSTERS}/*/.vag*/machines/*/virtualbox/private_key >& /dev/null

# vim: tabstop=2 shiftwidth=2 expandtab background=dark
