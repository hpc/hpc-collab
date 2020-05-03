# vx.mk

# ### ### ###
### ### ### ###
# vx-specific cluster config
### ### ### ###

# used to search for sources for tarballs, etc
ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)

# @todo programmatical determine that vcdb is the data base host, perhaps DBDPORT config in firewall?
# ls all requires/* nodes, find those which end in "db", pick one
# if it isn't in this cluster, issue 'delete cluster' command

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@								; \
	export _prereq_nodes="$(sort $(notdir $(wildcard $(CFG)/$(@F)/requires/*)))"	; \
	for _n in $${prereq_nodes}							  \
	do										; \
	  if [ -z "$${_n}" ] ; then							  \
	    echo "vx.mk: node: empty (prerequisite node list)"				; \
	    exit 99									; \
	  fi										; \
	  if [ -z "$(IAM)" ] ; then							; \
	    echo "vx.mk: IAM/VC: empty (prerequisite node list)"			; \
	    exit 99									; \
	  fi										; \
	  if ! [[ "$${_n}" =~ *db ]] ; then						  \
	    continue									; \
	  fi										; \
	  if [[ $${_n:0:2} != "$(IAM)" ] ; then						  \
	    export EXISTS=`ssh $${_n} sacctmgr show cluster $(IAM) -n`			; \
 	    if [ -n "$${EXISTS}" ] ; then						  \
	      if [ -z "$(HUSH)" ] ; then						; \
	        echo "deleting $(IAM): ssh $${_n} sacctmgr -iQ delete cluster $(IAM)"	; \
	      fi									; \
 	      ssh $${_n} sacctmgr -iQ delete cluster $(IAM)				; \
	    fi										; \
	  fi										; \
 	fi	

### ### ### ###
