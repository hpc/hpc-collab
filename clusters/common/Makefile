
#
# Makefile to programmatically
#  - report on the current state of the virtual cluster's nodes
#  - codification of the dependencies between nodes
#  - perform node state changes including necessary bookkeeping as they transition among states
#
# This Makefile is a convenience, mostly. The direct vagrant tools remain accessible.
# It does enforce discipline on the state directory, which may be helpful.
#

SHELL	       := bash
.SHELLFLAGS    := -eu -o pipefail -c
MAKEFLAGS      += --warn-undefined-variables
HUSH		=

ifneq (,$(findstring --quiet,$(MAKEFLAGS)))
  HUSH	       ?= @
endif

PWD		= $(shell pwd)
WHERE_INVOKED	= $(basename $(dir $(PWD)))
IAM		= $(notdir $(PWD))
MAKEFILE_DIR	= $(CURDIR)
BASE_DIR	= $(realpath $(MAKEFILE_DIR)/../..)
CLUSTERS_DIR	= $(BASE_DIR)/clusters

VIRTUALCLUSTER ?= $(IAM)
export VC	   ?= $(VIRTUALCLUSTER)

CFG	        = cfg
NODES  	        = $(filter $(VC)%, $(notdir $(wildcard $(CFG)/*)))
TSTAMP	       := $(shell date +%y%m%d.%H%M)
OS	        = $(shell uname -s)

ifeq (,$(findstring $(BASE_DIR)/bin,$(PATH)))
export PATH    := $(PATH):$(BASE_DIR)/bin
endif
ifeq (,$(findstring $(CLUSTERS_DIR)/common/bin,$(PATH)))
export PATH    := $(PATH):$(CLUSTERS_DIR)/common/bin
endif

### ### state transitions ### ###
# these are not mutually exclusive,
#  - a provisioned node may be powered off
#  - an up node may be partially provisioned, the provision.sh script did not complete successfully 
#  - provisioned means that the provision.sh script completed successfully
# to be usable, a node must be in PROVISIONED state
#
# ### state diagram
# 					State Transitions

#                                     ⬐ ─────────────────────── [unprovision.sh] ⟵ ────────────────────── ↰
#                                     ↓                                                                    ↑
# NONEXISTENT ─── "vagrant up" ─── → RUNNING ─── [provision.sh] ── → PROVISIONED ─── vagrant halt ─── → POWEROFF
#     ↑                ↑ ⬑ ──────────────────────────────────────────── ⬑ ──── [already provisioned] ⟵ ─── ↲ 
#     ↑                ⬑ ────────────────────── [unprovision.sh] ────────────── UNPROVISION ⟵ ──────────── ↲ 
#     ⬑ ─────────────────────────────────────── "vagrant destroy" ──────────────────────────────────────── ↲ 

# state diagram ###

# flag files are created to match these states by the ingestvagrantstate.sh script for make consistency
COMMON_D	    = common
STATE_D		    = $(COMMON_D)/._state

NONEXISTENT_D	    = $(STATE_D)/nonexistent
POWEROFF_D	    = $(STATE_D)/poweroff
RUNNING_D	    = $(STATE_D)/running
PROVISIONED_D	    = $(STATE_D)/provisioned

STATE_DIRS_ALL	    = $(STATE_D) $(PROVISIONED_D) $(RUNNING_D) $(POWEROFF_D) $(NONEXISTENT_D)
STATE_DIRS	    = $(PROVISIONED_D) $(RUNNING_D) $(POWEROFF_D) $(NONEXISTENT_D)

RUNNING_FLAGS       = $(addprefix $(RUNNING_D)/,     $(NODES))
POWEROFF_FLAGS      = $(addprefix $(POWEROFF_D)/,    $(NODES))
NONEXISTENT_FLAGS   = $(addprefix $(NONEXISTENT_D)/, $(NODES))
PROVISIONED_FLAGS   = $(addprefix $(PROVISIONED_D)/, $(NODES))

# unprovision doesn't have a flag; so use explicit target
TARGETS_UNPROVISION = $(addsuffix _UNPROVISION, $(NODES))

TMP		       ?= $(COMMON_D)/tmp
XFR			= xfr
XFR_PREV		= $(WHERE_INVOKED)/$(VC)~/$(XFR)
DOXYGEN_OUT		= Doxygen.out

repos_tgz		= repos.tgz
XFR_REPOS_TGZ		= $(XFR)/$(repos_tgz)
XFR_REPOS_TGZ_PREV	= $(XFR_PREV)/$(repos_tgz)

PROVISION_D     	= $(CFG)/provision
PROVISION_FLAG_D	= $(PROVISION_D)/flag
PROVISION_ENV	 	= $(PROVISION_D)/env
PROVISION_BIN	 	= $(PROVISION_D)/bin

DISABLE_RM_FLAG_FILE	= $(PROVISION_FLAG_D)/DISABLE_RM
DISABLE_RM		:= $(shell test -s ${PROVISION_FLAG_D}/DISABLE_RM && cat ${PROVISION_FLAG_D}/DISABLE_RM)

TARBALLS		= tarballs
TARBALLS_D		= ../../$(TARBALLS)
TARBALL_REPOS_TGZ	= $(TARBALLS_D)/$(repos_tgz)
TAR_EXCLUDE_ARGS	= --exclude=$(repos_tgz) --exclude=$(TARBALLS) --exclude=._\* \
				--exclude=.ssh --exclude=.vagrant

TAR_GET			= $(TARBALLS_D)/$(VC),$(TSTAMP).tgz
TAR_GET_CKSUM		= $(TARBALLS_D)/$(VC),$(TSTAMP).cksum

TAR_CHECKPOINT_ARGS	=
ifeq ($(OS),Linux)
TAR_CHECKPOINT_ARGS	= --checkpoint-action=dot --checkpoint=4096
endif

TAR_VERBOSE_ARGS	= $(TAR_EXCLUDE_ARGS) -cvzf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ARGS		= $(TAR_EXCLUDE_ARGS) -czf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ADDITIONAL_FILES	= Makefile README Doxyfile setpath.csh setpath.sh
#TAR_ADDITIONAL_FILE	= $(TAR_ADDITIONAL_FILES) $(PROVISION_D)/Modules/*

vc_tgz			= $(VC).tgz
vc_cksum		= $(VC).cksum
VC_TGZ			= $(TARBALLS_D)/$(vc_tgz)
VC_CKSUM		= $(TARBALLS_D)/$(VC).cksum
TMP_VC_CKSUM		= $(TMP)/$(VC).cksum

VBOX_VERSION		= $(shell cat $(CFG)/provision/config/vboxadd/version)
VBOXADD_ISO_SUF		= VBoxGuestAdditions_$(VBOX_VERSION).iso
XFR_VBOXADD_ISO		= $(XFR)/$(VBOXADD_ISO_SUF)
XFR_VBOXADD_ISO_PREV	= $(XFR_PREV)/$(VBOXADD_ISO_SUF)
TARBALL_VBOXADD_ISO	= $(TARBALLS_D)/$(VBOXADD_ISO_SUF)
XFR_PREREQ		= $(XFR_VBOXADD_ISO) $(XFR_REPOS_TGZ)

### XXX @todo generate COMPLETE from the inverse of QUICK
FLAGS			= RSYNC_CENTOS_REPO  SKIP_UPDATERPMS  SKIP_SW  BUILD_LUSTRE_FLAG
FLAGS_QUICK		= RSYNC_CENTOS_REPO~ SKIP_UPDATERPMS  SKIP_SW  BUILD_LUSTRE_FLAG~
FLAGS_NORMAL		= RSYNC_CENTOS_REPO  SKIP_UPDATERPMS~ SKIP_SW  BUILD_LUSTRE_FLAG~
FLAGS_COMPLETE  	= RSYNC_CENTOS_REPO  SKIP_UPDATERPMS~ SKIP_SW~ BUILD_LUSTRE_FLAG
FLAGS_OFF		= $(foreach f,$(FLAGS),$(f)~)
FLAGS_ON		= $(foreach f,$(FLAGS),$(f))

PROVISION_FLAGS_QUICK    = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_QUICK))
PROVISION_FLAGS_NORMAL   = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_NORMAL))
PROVISION_FLAGS_COMPLETE = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_COMPLETE))

INGEST_STATE		= ingestvagrantstate.sh
UNPROVISION		= unprovision.sh
MARK_PROVISIONED	= markprovisioned.sh
VERIFY_LOCALENV		= verifylocalenv.sh
SAVE_LOGSDB		= savelogsdb.sh

# match entries in the directories defined by $(STATE_D)/<state>
STATE_LIST	        = nonexistent poweroff running provisioned
NODES_STATE		= $(subst $(STATE_D)/,,$(foreach s,$(STATE_LIST),$(wildcard $(STATE_D)/$(s)/*)))

# XXX todo: automate these with the list of states 
# emit directory contents in each of the state directories, stripping off all but the final <node>

NODES_STATE_NONEXISTENT = $(notdir $(foreach s,nonexistent,$(wildcard $(STATE_D)/$(s)/*)))
NODES_STATE_POWEROFF    = $(notdir $(foreach s,poweroff,$(wildcard $(STATE_D)/$(s)/*)))
NODES_STATE_RUNNING     = $(notdir $(foreach s,running,$(wildcard $(STATE_D)/$(s)/*)))
NODES_STATE_PROVISIONED = $(notdir $(foreach s,provisioned,$(wildcard $(STATE_D)/$(s)/*)))

NODES_RUNNING		= $(foreach n,$(NODES),$(RUNNING_D)/$(n))
NODES_PROVISIONED	= $(foreach n,$(NODES),$(PROVISIONED_D)/$(n))
NODES_POWEROFF		= $(foreach n,$(NODES),$(POWEROFF_D)/$(n))
NODES_NONEXISTENT	= $(foreach n,$(NODES),$(NONEXISTENT_D)/$(n))
NODES_UNPROVISION	= $(foreach n,$(NODES),$(n)_UNPROVISION)

QUICK_HUMANFRIENDLY_FLAG_NAMES    = quick quick-flag flag-quick flags-quick flag-quicker \
					flags-quicker flags-faster flag-faster provision-flags-quick
NORMAL_HUMANFRIENDLY_FLAG_NAMES   = normal normal-flag flag-normal flags-normal provision-flags-normal
COMPLETE_HUMANFRIENDLY_FLAG_NAMES = complete complete-flag flag-complete flags-complete provision-flags-complete

HUMANFRIENDLY_FLAGS	= $(QUICK_HUMANFRIENDLY_FLAG_NAMES) \
		$(NORMAL_HUMANFRIENDLY_FLAG_NAMES) \
		$(COMPLETE_HUMANFRIENDLY_FLAG_NAMES)

SAVELOGS_TARGETS	= savelogs save-logs savelog save-log collectlogs collect-logs collectlog collect-log

HUMANFRIENDLY_TARGETS	= clean clean-state compare-vc-cksum doc help							\
				ingest-state show show-state show-vars status						\
				todo verifylocalenv copyright pkg							\
				$(SAVELOGS_TARGETS)

PHONY			= $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

.PHONY: $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

.DELETE_ON_ERROR: $(NODES_STATE)

all:	show

copyright:
	$(HUSH)copyright.sh

clean-state:
	$(HUSH)mkdir -p $(STATE_DIRS_ALL)
	$(HUSH)$(DISABLE_RM) rm -f $(RUNNING_D)/* $(POWEROFF_D)/* $(NONEXISTENT_D)/*
	$(HUSH)vagrant global-status --prune >/dev/null 2>&1 &

clean: $(NONEXISTENT_FLAGS)
	$(HUSH)$(DISABLE_RM) rm -f $(DOXYGEN_OUT)
	$(HUSH)$(DISABLE_RM) rm -f $(PROVISIONED_D)/*
	$(HUSH)find . -name ._\* -type f -exec $(DISABLE_RM) rm -f \{\} \;

show show-state status:	$(STATE_DIRS_ALL) ingest-state
ifneq ($(NODES_STATE_PROVISIONED),)
	$(info		provisioned: $(sort $(NODES_STATE_PROVISIONED)))
endif
ifneq ($(NODES_STATE_RUNNING),)
	$(info		booting: $(sort $(NODES_STATE_RUNNING)))
endif
ifneq ($(NODES_STATE_POWEROFF),)
	$(info		powered off: $(sort $(NODES_STATE_POWEROFF)))
endif
ifneq ($(NODES_STATE_NONEXISTENT),)
	$(info		nonexistent: $(sort $(NODES_STATE_NONEXISTENT)))
endif

PAGER	?= less
todo:
	$(PAGER) ../Notes ../todo todo

show-vars:
	$(HUSH)$(info )
	$(HUSH)$(info NODES_WITH_REQUIRED_PROVISIONED_NODE_TARGETS: $(NODES_WITH_REQUIRED_PROVISIONED_NODE_TARGETS))
	$(HUSH)$(info PATH:		$(PATH))
	$(HUSH)$(info PATH:		$${PATH})
	$(HUSH)$(info )
	$(HUSH)$(info FLAGS:		$(FLAGS))
	$(HUSH)$(info FLAGS_OFF:	$(FLAGS_OFF))
	$(HUSH)$(info FLAGS_ON:		$(FLAGS_ON))
	$(HUSH)$(info FLAGS_QUICK:	$(FLAGS_QUICK))
	$(HUSH)$(info FLAGS_COMPLETE:	$(FLAGS_COMPLETE))
	$(HUSH)$(info )

## @todo use graphviz on Makefile to self-generate this
help:	Makefile
	$(HUSH)$(info ) 
	$(HUSH)$(info   make [ up | provision | ready | poweroff | halt | down | nonexistent | unprovision | savelogs])
	$(HUSH)$(info   make [show | help])
	$(HUSH)$(info   make [flag-quick | flag-complete | quick | complete | flag | show-flags])
	$(HUSH)$(info   make ['$(NODES)'])
	$(HUSH)$(info	make doc)
	$(HUSH)$(info )
	$(HUSH)$(info     provision, ready, up		= ready to run, node is running and successfully provisioned)
	$(HUSH)$(info     halt, poweroff, off		= node is not running, halted, down, powered off)
	$(HUSH)$(info     nonexistent			= node is not configured)
	$(HUSH)$(info     unprovision, down		= node is not configured and no flags remain indicating it is)
	$(HUSH)$(info   			  	  This state is used internally and for debugging.)
	$(HUSH)$(info     flag-quicker			= set provision flags for quicker provisioning)
	$(HUSH)$(info     flag-complete			= set provision flags for (more) complete provisioning)
	$(HUSH)$(info )
	$(HUSH)$(info     help				= this message)
	$(HUSH)$(info     show [DEFAULT]			= show a list of individual node state)
	$(HUSH)$(info     doc				= generate and view documentation)
	$(HUSH)$(info )
	$(HUSH)$(info    Equivalencies:')
	$(HUSH)$(info     	<node>             	  	= "make provision <node>")
	$(HUSH)$(info     	<node>!     	          	= "make destroy <node>; make provision <node>")
	$(HUSH)$(info     	<node>+        	 	      	= "make running <node>")
	$(HUSH)$(info     	<node>-               		= "make poweroff <node>")
	$(HUSH)$(info     	<node>--               		= "make unprovision <node>")
	$(HUSH)$(info )
	$(HUSH)$(info   make todo			= shows the current working notes)
	$(HUSH)$(info   make ingest-state		= force recollection of vagrant state)
	$(HUSH)$(info   make savelogs			= collect cluster logs and db dump from running cluster
	$(HUSH)$(info )
	$(HUSH)$(info   "make up", "make <node>" or "make show"  will be of most use.)
	$(HUSH)$(info )
	$(HUSH)$(info 	"Shorcuts for these commands are available if one's PATH includes: $(PROVISION_BIN)")
	$(HUSH)$(info 	which can be set with "[bash] . setpath.sh" or "[*csh] source setpath.csh")
	$(HUSH)$(info	 so that they can just be invoked as "up", "show", "unprovision" &c)
	$(HUSH)$(info )
	$(HUSH)sed -n '/^# ### state diagram/,/^# state diagram ###/p;/^state diagram ###/q' < Makefile | grep -v 'state diagram' | sed 's/^# / /'


## @todo compress into some clever ~ toggle rules
$(PROVISION_FLAG_D):
	$(error PROVISION_FLAG_D doesn't exist)

## XXX TODO foreach(...FLAGS..., generate pattern rule)
## # remove tilde to turn flags on

$(PROVISION_FLAG_D)/RSYNC_CENTOS_REPO~: | $(PROVISION_FLAG_D)
	-@mv $(subst ~,,$@) $@

$(PROVISION_FLAG_D)/SKIP_UPDATERPMS~: | $(PROVISION_FLAG_D)
	-@mv $(subst ~,,$@) $@
 
$(PROVISION_FLAG_D)/SKIP_SW~ : | $(PROVISION_FLAG_D)
	-@mv $(subst ~,,$@) $@
 
# for any of these flags, add a tilde
$(PROVISION_FLAG_D)/RSYNC_CENTOS_REPO: | $(PROVISION_FLAG_D)
	-@mv $@~ $@
 
$(PROVISION_FLAG_D)/SKIP_UPDATERPMS: | $(PROVISION_FLAG_D)
	-@mv $@~ $@
 
$(PROVISION_FLAG_D)/SKIP_SW: | $(PROVISION_FLAG_D)
	-@mv $@~ $@

$(PROVISION_FLAGS_QUICK):

$(PROVISION_FLAGS_NORMAL):

$(PROVISION_FLAGS_COMPLETE):


$(QUICK_HUMANFRIENDLY_FLAG_NAMES): $(PROVISION_FLAGS_QUICK) flag

$(NORMAL_HUMANFRIENDLY_FLAG_NAMES): $(PROVISION_FLAGS_NORMAL) flag

$(COMPLETE_HUMANFRIENDLY_FLAG_NAMES): $(PROVISION_FLAGS_COMPLETE) flag

flags flag: | $(PROVISION_FLAG_D)
	$(HUSH)ls $(PROVISION_FLAG_D)

###

ingest-state: clean-state
	$(HUSH)env VC=$(VC) $(INGEST_STATE)

verifylocalenv: $(STATE_DIRS_ALL)
	$(HUSH)env VC=$(VC) $(VERIFY_LOCALENV)

### ### ### ### ###
# cluster-specific differences, if it exists
-include $(IAM).mk
###

### ### ### ###
# individual node rules, if present
-include nodes.mk
###

### ### ###
# common node targets

vpath % $(PROVISIONED_D)

# base target is interpreted as a nodename to be provisioned
%: verifylocalenv $(PROVISIONED_D)/%

# nodename with exclamation point is forced to unprovision, then reprovision
%!: verifylocalenv $(NONEXISTENT_D)/% $(PROVISIONED_D)/%

# nodename with double minus/hyphen is forced to unprovision
%--: verifylocalenv %_UNPROVISION

# nodename with single minus/hyphen is powered off, remains provisioned
%-: verifylocalenv $(POWEROFF_D)/%

# nodename with plus sign is forced running, but isn't forced to provision
%+: verifylocalenv $(RUNNING_D)/%

### ### ### ###
# bulk NODE states
#  ie. all PROVISIONED, all POWEROFF, all UNPROVISION

up provision: verifylocalenv $(PROVISIONED_FLAGS) ingest-state
up! provision!: unprovision up ingest-state

running ready on: verifylocalenv $(RUNNING_FLAGS)

halt down poweroff off: verifylocalenv $(POWEROFF_FLAGS)

nonexistent: verifylocalenv $(NONEXISTENT_FLAGS)

unprovision down: verifylocalenv $(TARGETS_UNPROVISION) clean-state

provision-quicker quicker-provision: flags-quicker provision

provision-complete complete-provision: flags-complete provision

### ###

## @todo convert $(wildcard ...) to an ordered-only prerequisite, with node dependencies, prerequisite_predecessor()
## @todo ...would require tighter integration to collect requires/* and Vagrantfile structure

# generate the required nodes targets with a secondary (but empty recipe) rule
# this wouldn't be necessary if the '%' could be used as an replacement argument
# ex. : $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/%/requires/*)))
NODES_WITH_REQUIRED_PROVISIONED_NODE_TARGETS = $(foreach n,$(NODES),$(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/$(n)/requires/*))))

$(NODES_WITH_REQUIRED_PROVISIONED_NODE_TARGETS):


$(PROVISIONED_D)/%: $(XFR_PREREQ) $(notdir $(wildcard $(CFG)/%/requires/*))
	$(HUSH)export _prereq_nodes="$(sort $(notdir $(wildcard $(CFG)/$(@F)/requires/*)))"		; \
	for prereq in $^ $${_prereq_nodes}								; \
        do												  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then							  \
	    continue											; \
	  fi												; \
	  export _VCC=$${prereq:0:2}									; \
	  if [ -n "$${_VCC}" -a -d "../$${_VCC}" -a -d "../$${_VCC}/cfg/$${prereq}" ] ; then		  \
	    if [ -n "$(HUSH)" ] ; then									  \
	      echo "prerequisite: $${prereq}"								; \
	    fi												; \
	    env VC=$${_VCC} VIRTUALCLUSTER=$${_VCC} $(MAKE) -s VC=$${_VCC} -C ../$${_VCC} $${prereq}	; \
	    continue											; \
	  fi												; \
	  if [ ! -f "$${prereq}" ] ; then								  \
	    echo prerequisite: $${prereq} missing							; \
	    exit 105											; \
	  fi												; \
	done												; \
	if [ -f $(RUNNING_D)/$(@F) -a ! -f $(PROVISIONED_D)/$(@F) ] ; then				  \
	  vagrant destroy -f $(@F) || exit 106								; \
	fi								    			  	; \
	if [ ! -f $(PROVISIONED_D)/$(@F) ] ; then			      			 	  \
	  vagrant up --provision $(@F)									; \
	  rc=$$?											; \
	  if [ $${rc} -ne 0 ] ; then									  \
	    $(DISABLE_RM) rm -f $(PROVISIONED_D)/$(@F)							; \
	    exit 107											; \
	  else												  \
	    env VC=$(VC) $(MARK_PROVISIONED) $(@F)							; \
	  fi												; \
	fi

$(RUNNING_D)/%: $(XFR_PREREQ) ingest-state
	$(HUSH)if [ -f $(PROVISIONED_D)/$(@F) ] ; then							  \
	  vagrant up --no-provision $(@F)							    	; \
	  rc=$$?											; \
	  if [ $${rc} -ne 0 ] ; then								  	  \
	    $(DISABLE_RM) rm -f $(PROVISIONED_D)/$(@F)							; \
	    exit 101											; \
	  fi												; \
	elif [ -f $(POWEROFF_D)/$(@F) ] ; then								  \
	  vagrant up --no-provision $(@F)								; \
	  rc=$$?											; \
	  if [ $${rc} -ne 0 ] ; then									  \
	    $(DISABLE_RM) rm -f $(PROVISIONED_D)/$(@F)							; \
	    exit 102											; \
	  fi												; \
													  \
	elif [ ! -f $(PROVISIONED_D)/$(@F) -a ! -f $(NONEXISTENT_D)/$(@F) ] ; then			  \
	  vagrant destroy -f $(@F) || exit 103								; \
	fi												; \
	ssh $(@F) uptime >/dev/null 2>&1								; \
	rc=$$?												; \
	if [ $${rc} -ne 0 ] ; then									  \
	  $(DISABLE_RM) rm -f $(PROVISIONED_D)/$(@F)							; \
	  exit 104											; \
	fi

$(POWEROFF_D)/%:
	$(HUSH)if [ ! -f "$(NONEXISTENT_D)/$(@F)" ] ; then						  \
		vagrant halt $(@F)									; \
	fi

$(NONEXISTENT_D)/%: $(POWEROFF_D)/%
	$(HUSH)vagrant destroy -f $(@F)

%_UNPROVISION: $(NONEXISTENT_D)/% ingest-state
	$(HUSH)$(UNPROVISION) $(subst _UNPROVISION,,$(@F))


###
# packaging

pkg:	$(TARGETS_UNPROVISION)

$(TARBALLS_D):
	$(HUSH)mkdir -p $@

$(TARBALL_REPOS_TGZ) $(TARBALL_VBOXADD_ISO): $(TARBALLS_D)
	$(MAKE) -C ../../requires/ingest
	$(HUSH)for _f in $@										; \
	do												  \
	  if [ ! -f $${_f} ] ; then									  \
	    echo missing prerequisite: $${_f}								; \
	    exit 104											; \
	  fi												; \
	done

$(VC_TGZ): $(TAR_GET)
	$(HUSH)ln -n -f $< $(VC_TGZ)

$(VC_CKSUM): $(TARBALLS_D) $(VC_TGZ)
	$(HUSH)cksum $(VC_TGZ) > $(VC_CKSUM)

# Attempt to ln to conserve disk space, but fallback to rsync as gracefully as possible
$(XFR_REPOS_TGZ): $(TARBALL_REPOS_TGZ)
	$(HUSH)if [ -n "$(ALTERNATE_VC_D)" ] ; then							  \
	  if [ -d "$(ALTERNATE_VC_D)" ] ; then								  \
	    if [ -d "$(ALTERNATE_VC_D)/$(XFR)" ] ; then							  \
	      if [ -f "$(ALTERNATE_VC_D)/$(XFR)/$(repos_tgz)" ] ; then					  \
	        if [ ! -L "$(ALTERNATE_VC_D)/$(XFR)/$(repos_tgz)" ] ; then				  \
	          ln -n -f $(ALTERNATE_VC_D)/$(XFR)/$(repos_tgz) $(XFR_REPOS_TGZ)			; \
	        fi											  \
	      else											  \
		if [ -f "$(XFR_REPOS_TGZ_PREV)" ] ; then						  \
	          if [ ! -L "$(XFR_REPOS_TGZ_PREV)" ] ; then						  \
	            ln -n -f $(XFR_REPOS_TGZ_PREV) $(XFR_REPOS_TGZ)		 			; \
	          fi											  \
	        fi											  \
	      fi											  \
	    fi												  \
	  fi												  \
	fi
	$(HUSH)rsync -LHcau $(TARBALL_REPOS_TGZ) $(XFR_REPOS_TGZ)

# attempt to use ln to avoid running out of space on the partition holding $(XFR_...)
$(XFR_VBOXADD_ISO): $(TARBALL_VBOXADD_ISO)
	$(HUSH)if [ -f $(XFR_VBOXADD_ISO_PREV) ] ; then							  \
	  ln -f $(XFR_VBOXADD_ISO_PREV) $@ |& grep -v 'Invalid cross-device'				; \
	else												  \
	  ( ln -f $< $@ |& grep -v 'Invalid cross-device') ||						  \
	    rsync -LHcau $< $@										; \
	fi

