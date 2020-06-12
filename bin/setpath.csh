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
  set nodes_dirs=`ls -d ${CLUSTERS}/${c}/cfg/*`
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

foreach n ($nodes)
  set cl=`echo ${n}| cut -c1-2`
  set cluster_dir=${CLUSTERS}/${cl}
  alias	"${n}"		"nohup make -C ${cluster_dir} ${n}; date"
  alias	"${n}!"		"make -C ${cluster_dir} ${n}_UNPROVISION; show; nohup make -C ${cluster_dir} ${n}"
  alias	"${n}--"	"make -C ${cluster_dir} ${n}_UNPROVISION; show"

  # yes, this redefines the alias for multiple nodes; that's not costly in csh
  alias	"${cl}"		"nohup make -C ${cluster_dir} up; date"
  alias	"${cl}--"	"make -C ${cluster_dir} unprovision; show"
  alias	"${cl}!"	"make -C ${cluster_dir} unprovision; show; nohup make -C ${cluster_dir} up"
end

# common aliases for all clusters:
alias "up"		"nohup make -s -C ${BASE} up; date"

foreach t (show pkg prereq provision unprovision down)
  alias "${t}"		"make -s -C ${BASE} ${t}"
end
alias  "savelogs"	"( cd ${CLUSTERS}/vc ; env VC=vc ../common/bin/savelogsdb.sh )"

# when/if needed
#ssh-add ${CLUSTERS}/*/.vag*/machines/*/virtualbox/private_key >& /dev/null
