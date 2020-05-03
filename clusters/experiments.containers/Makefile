
#
# Makefile to programmatically
#  - report on the current state of the virtual cluster's nodes
#  - codification of the dependencies between nodes
#  - perform node state changes including necessary bookkeeping as they transition among states
#  - package and unpackage the configuration tree into tarballs 
#  - position some of the bulkier tarballs (ie. repository tarball) separately
#
# This Makefile is a convenience, mostly. The direct vagrant tools remain accessible.
# It does enforce the discipline on the state directory, which may be helpful.
#

SHELL		:= bash
.SHELLFLAGS	:= -eu -o pipefail -c
MAKEFLAGS	+= --warn-undefined-variables

VIRTUALCLUSTER	   = cc
ALT_VIRTUALCLUSTER = vc

CFG	       = $(VIRTUALCLUSTER)/cfg
NODES  	       = $(filter-out provision, $(notdir $(wildcard $(CFG)/*)))
TSTAMP	      := $(shell date +%y%m%d.%H%M)
OS	       = $(shell uname -s)

export PATH	  := $(shell echo $${PATH}):$(CFG)/provision/bin
export VAGRANT_CWD = $(VIRTUALCLUSTER)

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

# flag files are created to match these states by the ingestvagrantstate.sh script for make convenience
VC		  = $(VIRTUALCLUSTER)
COMMON_D	  = $(VC)/common
STATE_D	  	  = $(COMMON_D)/._state

NONEXISTENT_D	    = $(STATE_D)/nonexistent
POWEROFF_D	    = $(STATE_D)/poweroff
RUNNING_D	    = $(STATE_D)/running
PROVISIONED_D	    = $(STATE_D)/provisioned

STATE_DIRS	    = $(STATE_D) $(PROVISIONED_D) $(RUNNING_D) $(POWEROFF_D) $(NONEXISTENT_D)

RUNNING_FLAGS       = $(addprefix $(RUNNING_D)/,     $(NODES))
POWEROFF_FLAGS      = $(addprefix $(POWEROFF_D)/,    $(NODES))
NONEXISTENT_FLAGS   = $(addprefix $(NONEXISTENT_D)/, $(NODES))
PROVISIONED_FLAGS   = $(addprefix $(PROVISIONED_D)/, $(NODES))

# unprovision doesn't have a flag; so use explicit target
TARGETS_UNPROVISION = $(addsuffix _UNPROVISION, $(NODES))

TMP	       ?= $(COMMON_D)/tmp
XFR		= $(VIRTUALCLUSTER)/xfr
XFR_PREV	= $(VIRTUALCLUSTER)~/xfr
ALT_XFR		= $(ALT_VIRTUALCLUSTER)/xfr
DOXYGEN_OUT	= Doxygen.out

repos_tgz	= repos.tgz
REPOS_TGZ	= $(XFR)/$(repos_tgz)
REPOS_TGZ_PREV	= $(XFR_PREV)/$(repos_tgz)
ALT_REPOS_TGZ	= ../$(ALT_XFR)/$(repos_tgz)

TARBALLS	     = tarballs
TARBALL_REPOS_TGZ    = $(TARBALLS)/$(repos_tgz)
TAR_EXCLUDE_ARGS     = --exclude=$(repos_tgz) --exclude=$(TARBALLS) --exclude=._\* \
			--exclude=.ssh --exclude=.vagrant

TAR_GET		     = $(TARBALLS)/$(VIRTUALCLUSTER),$(TSTAMP).tgz
TAR_GET_CKSUM	     = $(TARBALLS)/$(VIRTUALCLUSTER),$(TSTAMP).cksum

TAR_CHECKPOINT_ARGS  =
ifeq ($(OS),Linux)
TAR_CHECKPOINT_ARGS := --checkpoint-action=dot --checkpoint=4096
endif
TAR_VERBOSE_ARGS     = $(TAR_EXCLUDE_ARGS) -cvzf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ARGS	     = $(TAR_EXCLUDE_ARGS) -czf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ADDITIONAL_FILES = Makefile README Doxyfile setpath.csh setpath.sh
#TAR_ADDITIONAL_FILES = Makefile README Doxyfile $(VIRTUALCLUSTER)/modulefile

cc_tgz		= $(VIRTUALCLUSTER).tgz
cc_cksum	= $(VIRTUALCLUSTER).cksum
CC_TGZ		= $(TARBALLS)/$(cc_tgz)
CC_CKSUM	= $(TARBALLS)/$(VIRTUALCLUSTER).cksum
TMP_CC_CKSUM	= $(TMP)/$(VIRTUALCLUSTER).cksum

PROVISION_D      = $(CFG)/provision
PROVISION_FLAG_D = $(PROVISION_D)/flag
PROVISION_ENV	 = $(PROVISION_D)/env
PROVISION_BIN	 = $(PROVISION_D)/bin

VBOX_VERSION		= $(shell cat $(PROVISION_D)/config/vboxadd/version)
VBOXADD_ISO_SUF		= VBoxGuestAdditions_$(VBOX_VERSION).iso
VBOXADD_ISO		= $(XFR)/$(VBOXADD_ISO_SUF)
TARBALL_VBOXADD_ISO	= $(XFR)/$(VBOXADD_ISO_SUF)

### XXX @todo generate COMPLETE from the inverse of QUICK
FLAGS		= RSYNC_CENTOS_REPO  SKIP_UPDATERPMS  SKIP_SW  BUILD_LUSTRE_FLAG
FLAGS_QUICK	= RSYNC_CENTOS_REPO~ SKIP_UPDATERPMS  SKIP_SW  BUILD_LUSTRE_FLAG~
FLAGS_NORMAL	= RSYNC_CENTOS_REPO  SKIP_UPDATERPMS~ SKIP_SW  BUILD_LUSTRE_FLAG~
FLAGS_COMPLETE  = RSYNC_CENTOS_REPO  SKIP_UPDATERPMS~ SKIP_SW~ BUILD_LUSTRE_FLAG
FLAGS_OFF	= $(foreach f,$(FLAGS),$(f)~)
FLAGS_ON	= $(foreach f,$(FLAGS),$(f))

PROVISION_FLAGS_QUICK    = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_QUICK))
PROVISION_FLAGS_NORMAL   = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_NORMAL))
PROVISION_FLAGS_COMPLETE = $(addprefix $(PROVISION_FLAG_D)/,$(FLAGS_COMPLETE))

INGESTSTATE	= ingestvagrantstate.sh
UNPROVISION	= unprovision.sh
MARKPROVISIONED	= markprovisioned.sh
VERIFYLOCALENV	= verifylocalenv.sh

MARK_PROVISIONED = $(PROVISION_BIN)/$(MARKPROVISIONED)
INGEST_STATE	 = $(shell $(PROVISION_BIN)/$(INGESTSTATE))
VERIFY_LOCAL_ENV = $(shell $(PROVISION_BIN)/$(VERIFYLOCALENV))

# match entries in the directories defined by $(STATE_D)/<state>
S_LIST		        = nonexistent poweroff running provisioned
NODES_STATE		= $(subst $(STATE_D)/,,$(foreach s,$(S_LIST),$(wildcard $(STATE_D)/$(s)/*)))

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

HUMANFRIENDLY_FLAGS = $(QUICK_HUMANFRIENDLY_FLAG_NAMES) \
		$(NORMAL_HUMANFRIENDLY_FLAG_NAMES) \
		$(COMPLETE_HUMANFRIENDLY_FLAG_NAMES)

HUMANFRIENDLY_TARGETS = clean clean-state compare-cc-cksum doc help \
				ingest-state pkg show show-state show-vars status \
				todo verifylocalenv copyright

.PHONY: $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

PHONY	:= $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

### .DELETE_ON_ERROR: 

all:	show

copyright:
	@copyright.sh

clean-state:
	@mkdir -p $(STATE_DIRS)
	@rm -f $(RUNNING_D)/* $(PROVISIONED_D)/* $(POWEROFF_D)/* $(NONEXISTENT_D)/*
	@vagrant global-status --prune >/dev/null 2>&1 &

clean: $(NONEXISTENT_FLAGS)
	@rm -f $(DOXYGEN_OUT)
	@find . -name ._\* -type f -exec rm -f \{\} \;

show-state: show

status: show

show-vars:
	@echo
	@echo FLAGS:		$(FLAGS)
	@echo FLAGS_OFF:	$(FLAGS_OFF)
	@echo FLAGS_ON:		$(FLAGS_ON)
	@echo FLAGS_QUICK:	$(FLAGS_QUICK)
	@echo FLAGS_COMPLETE:	$(FLAGS_COMPLETE)
	@echo

### XXX foreach...
show:	ingest-state $(STATE_DIRS)
ifneq ($(NODES_STATE_PROVISIONED),)
	$(info		provisioned: $(NODES_STATE_PROVISIONED))
endif
ifneq ($(NODES_STATE_RUNNING),)
	$(info		booting: $(NODES_STATE_RUNNING))
endif
ifneq ($(NODES_STATE_POWEROFF),)
	$(info		powered off: $(NODES_STATE_POWEROFF))
endif
ifneq ($(NODES_STATE_NONEXISTENT),)
	$(info		nonexistent: $(NODES_STATE_NONEXISTENT))
endif
	@echo -n

todo:
	more cc/Notes

## @todo use graphviz on Makefile to self-generate this
help:	Makefile
	@echo 
	@echo   'make [ up | provision | ready | poweroff | halt | down | nonexistent | unprovision]'
	@echo   'make [show | help]'
	@echo   'make [flag-quick | flag-complete | quick | complete | flag | show-flags]'
	@echo   'make ['$(NODES)']'
	@echo	'make doc'
	@echo
	@echo   '  provision, ready, up		= ready to run, node is running and successfully provisioned'
	@echo   '  halt, down, poweroff, off	= node is not running, halted, down, powered off'
	@echo   '  nonexistent			= node is not configured'
	@echo   '  unprovision			= node is not configured and no flags remain indicating it is'
	@echo   '			  	  This state is used internally and for debugging.'
	@echo   '  flag-quicker			= set provision flags for quicker provisioning'
	@echo   '  flag-complete			= set provision flags for (more) complete provisioning'
	@echo
	@echo   '  help				= this message'
	@echo   '  show [DEFAULT]		= show a list of individual node state'
	@echo   '  doc				= generate and view documentation'
	@echo
	@echo   ' Equivalencies:'
	@echo   '  	<node>               	= "make provision <node>"'
	@echo   '  	<node>!               	= "make destroy <node>; make provision <node>"'
	@echo   '  	<node>+               	= "make running <node>"'
	@echo   '  	<node>-               	= "make poweroff <node>"'
	@echo   '  	<node>--               	= "make unprovision <node>"'
	@echo
	@echo   'make todo			= shows the current working notes'
	@echo   'make ingest-state		= force recollection of vagrant state'
	@echo
	@echo   '"make up", "make <node>" or "make show"  will be of most use.'
	@echo
	@echo 	"Shorcuts for these commands are available if one's PATH includes: $(PROVISION_BIN)"
	@echo 	'which can be set with "[bash] . setpath.sh" or "[*csh] source setpath.csh"'
	@echo	' so that they can just be invoked as "up", "show", "unprovision" &c'
	@echo
	@sed -n '/^# ### state diagram/,/^# state diagram ###/p;/^state diagram ###/q' < Makefile | grep -v 'state diagram' | sed 's/^# / /'

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
	@ls $(PROVISION_FLAG_D)

ingest-state: $(clean-state)
	@$(INGEST_STATE)

verifylocalenv: $(STATE_DIRS)
	@$(VERIFY_LOCAL_ENV)

$(STATE_DIRS):
	@mkdir -p $@

### ### ### ###
# bulk NODE states
#  ie. all PROVISIONED, all POWEROFF, all UNPROVISION

up provision: verifylocalenv $(PROVISIONED_FLAGS)
up! provision!: unprovision up

running ready on: verifylocalenv $(RUNNING_FLAGS)

halt down poweroff off: verifylocalenv $(POWEROFF_FLAGS)

nonexistent: verifylocalenv $(NONEXISTENT_FLAGS)

unprovision: verifylocalenv $(TARGETS_UNPROVISION)

provision-quicker quicker-provision: flags-quicker provision

provision-complete complete-provision: flags-complete provision


### ### ### ###

# individual NODE states

## XXX @todo generate the following dynamically from $(NODES)
## XXX this no longer matches the actual rules - it is just an experiment that isn't complete

ccfs!: verifylocalenv $(NONEXISTENT_D)/ccfs $(PROVISIONED_D)/ccfs

ccfs--: ccfs_UNPROVISION

ccfs-: verifylocalenv $(POWEROFF_D)/ccfs

ccfs+: verifylocalenv $(RUNNING_D)/ccfs

ccfs: verifylocalenv $(PROVISIONED_D)/ccfs $(RUNNING_D)/ccfs

$(RUNNING_D)/ccfs: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccfs/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccfs ] ; then					   \
	  vagrant up --no-provision ccfs || exit 1				 ; \
										   \
	elif [ -f $(POWEROFF_D)/ccfs ] ; then					   \
	  vagrant up --no-provision ccfs || exit 2				 ; \
										   \
	elif [ ! -f $(PROVISIONED_D)/ccfs -a ! -f $(NONEXISTENT_D)/ccfs ] ; then   \
	    vagrant destroy -f ccfs || exit 3					 ; \
	fi

$(PROVISIONED_D)/ccfs: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccfs/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 4								; \
	  fi									; \
	done									; \
	if [ -f "$(RUNNING_D)/ccfs" -a ! -f "$(PROVISIONED_D)/ccfs" ] ; then	  \
	  vagrant destroy -f ccfs || exit 5					; \
	fi									; \
	if [ ! -f "$(PROVISIONED_D)/ccfs" ] ; then				  \
	  vagrant up --provision ccfs || exit 6					; \
	  $(MARK_PROVISIONED)							; \
	fi

$(POWEROFF_D)/ccfs: 
	@vagrant halt ccfs

$(NONEXISTENT_D)/ccfs: $(POWEROFF_D)/ccfs
	@vagrant destroy -f ccfs

# unprovision may be necessary even if provisioning failed, leaving node in RUNNING state
ccfs_UNPROVISION: $(NONEXISTENT_D)/ccfs
	@$(UNPROVISION) ccfs

# --- 

ccsvc!: verifylocalenv $(NONEXISTENT_D)/ccsvc $(PROVISIONED_D)/ccsvc

ccsvc--: ccsvc_UNPROVISION

ccsvc-: verifylocalenv $(POWEROFF_D)/ccsvc

ccsvc+: verifylocalenv $(RUNNING_D)/ccsvc

ccsvc: verifylocalenv $(PROVISIONED_D)/ccsvc $(RUNNING_D)/ccsvc

$(RUNNING_D)/ccsvc: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccsvc/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccsvc ] ; then				   \
	  vagrant up --no-provision ccsvc || exit 11				 ; \
										   \
	elif [ -f $(POWEROFF_D)/ccsvc ] ; then					   \
	  vagrant up --no-provision ccsvc || exit 12				 ; \
										   \
	elif [ ! -f $(PROVISIONED_D)/ccsvc -a ! -f $(NONEXISTENT_D)/ccsvc ] ; then \
	    vagrant destroy -f ccsvc || exit 13					 ; \
	fi

$(PROVISIONED_D)/ccsvc: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccsvc/requires/*)))
	@for prereq in $^						  ; \
        do								    \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then			    \
	    continue							  ; \
	  fi								  ; \
	  if [ ! -f "$${prereq}" ] ; then				    \
	    echo prerequisite: $${prereq} missing			  ; \
	    exit 14							  ; \
	  fi								  ; \
	done								  ; \
	if [ -f $(RUNNING_D)/ccsvc -a ! -f $(PROVISIONED_D)/ccsvc ] ; then \
	  vagrant destroy -f ccsvc || exit 15				  ; \
	fi								  ; \
	if [ ! -f $(PROVISIONED_D)/ccsvc ] ; then			    \
	  vagrant up --provision ccsvc || exit 16			  ; \
	  $(MARK_PROVISIONED)						  ; \
	fi

$(POWEROFF_D)/ccsvc:
	@vagrant halt ccsvc

$(NONEXISTENT_D)/ccsvc: $(POWEROFF_D)/ccsvc
	@vagrant destroy -f ccsvc

ccsvc_UNPROVISION: $(NONEXISTENT_D)/ccsvc
	@$(UNPROVISION) ccsvc

# --- 

ccbuild!: verifylocalenv $(NONEXISTENT_D)/ccbuild $(PROVISIONED_D)/ccbuild

ccbuild--: ccbuild_UNPROVISION

ccbuild-: verifylocalenv $(POWEROFF_D)/ccbuild

ccbuild+: verifylocalenv $(RUNNING_D)/ccbuild

ccbuild: verifylocalenv $(PROVISIONED_D)/ccbuild $(RUNNING_D)/ccbuild

$(RUNNING_D)/ccbuild: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccbuild/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccbuild ] ; then				       \
	  vagrant up --no-provision ccbuild || exit 21				     ; \
										       \
	elif [ -f $(POWEROFF_D)/ccbuild ] ; then				       \
	  vagrant up --no-provision ccbuild || exit 22				     ; \
										       \
	elif [ ! -f $(PROVISIONED_D)/ccbuild -a ! -f $(NONEXISTENT_D)/ccbuild ] ; then \
	    vagrant destroy -f ccbuild || exit 23				     ; \
	fi

$(PROVISIONED_D)/ccbuild: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccbuild/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 24								; \
	  fi									; \
	done									; \
	if [ -f $(RUNNING_D)/ccbuild -a ! -f $(PROVISIONED_D)/ccbuild ] ; then    \
	  vagrant destroy -f ccbuild || exit 25				        ; \
	fi								        ; \
	if [ ! -f $(PROVISIONED_D)/ccbuild ] ; then			          \
	  vagrant up --provision ccbuild || exit 26			        ; \
	  $(MARK_PROVISIONED)						        ; \
	fi

$(POWEROFF_D)/ccbuild:
	@vagrant halt ccbuild

$(NONEXISTENT_D)/ccbuild: $(POWEROFF_D)/ccbuild
	@vagrant destroy -f ccbuild

ccbuild_UNPROVISION: $(NONEXISTENT_D)/ccbuild
	@$(UNPROVISION) ccbuild

# ---

ccdb!: verifylocalenv $(NONEXISTENT_D)/ccdb $(PROVISIONED_D)/ccdb

ccdb--: ccdb_UNPROVISION

ccdb-: verifylocalenv $(POWEROFF_D)/ccdb

ccdb+: verifylocalenv $(RUNNING_D)/ccdb

ccdb: verifylocalenv $(PROVISIONED_D)/ccdb $(RUNNING_D)/ccdb

$(RUNNING_D)/ccdb: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccdb/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccdb ] ; then					 \
	  vagrant up --no-provision ccdb || exit 31			      ;  \
										 \
	elif [ -f $(POWEROFF_D)/ccdb ] ; then					 \
	  vagrant up --no-provision ccdb || exit 32			      ;  \
										 \
	elif [ ! -f $(PROVISIONED_D)/ccdb -a ! -f $(NONEXISTENT_D)/ccdb ] ; then \
	    vagrant destroy -f ccdb || exit 33				      ;  \
	fi

$(PROVISIONED_D)/ccdb: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccdb/requires/*)))
	@for prereq in $^						; \
        do								  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then			  \
	    continue							; \
	  fi								; \
	  if [ ! -f "$${prereq}" ] ; then				  \
	    echo prerequisite: $${prereq} missing			; \
	    exit 34							; \
	  fi								; \
	done								; \
	if [ -f $(RUNNING_D)/ccdb -a ! -f $(PROVISIONED_D)/ccdb ] ; then  \
	  vagrant destroy -f ccdb || exit 35				; \
	fi								; \
	if [ ! -f $(PROVISIONED_D)/ccdb ] ; then		          \
	  vagrant up --provision ccdb || exit 36			; \
	  $(MARK_PROVISIONED)						; \
	fi

$(POWEROFF_D)/ccdb:
	@vagrant halt ccdb

$(NONEXISTENT_D)/ccdb: $(POWEROFF_D)/ccdb
	@vagrant destroy -f ccdb

ccdb_UNPROVISION: $(NONEXISTENT_D)/ccdb
	@$(UNPROVISION) ccdb

# ---

ccsched!: verifylocalenv $(NONEXISTENT_D)/ccsched $(PROVISIONED_D)/ccsched

ccsched--: ccsched_UNPROVISION

ccsched-: verifylocalenv $(POWEROFF_D)/ccsched

ccsched+: verifylocalenv $(RUNNING_D)/ccsched

ccsched: verifylocalenv $(PROVISIONED_D)/ccsched $(RUNNING_D)/ccsched

$(RUNNING_D)/ccsched: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccsched/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccsched ] ; then					  \
	  vagrant up --no-provision ccsched || exit 41		 			; \
											  \
	elif [ -f $(POWEROFF_D)/ccsched ] ; then					  \
	  vagrant up --no-provision ccsched || exit 42					; \
											  \
	elif [ ! -f $(PROVISIONED_D)/ccsched -a ! -f $(NONEXISTENT_D)/ccsched ] ; then	  \
	    vagrant destroy -f ccsched || exit 43					; \
	fi

$(PROVISIONED_D)/ccsched: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccsched/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 44								; \
	  fi									; \
	done									; \
	if [ -f $(RUNNING_D)/ccsched -a ! -f $(PROVISIONED_D)/ccsched ] ; then   \
	  vagrant destroy -f ccsched || exit 45					; \
	fi								        ; \
	if [ ! -f $(PROVISIONED_D)/ccsched ] ; then		       	          \
	  vagrant up --provision ccsched || exit 46				; \
	  $(MARK_PROVISIONED)							; \
	fi

$(POWEROFF_D)/ccsched:
	vagrant halt ccsched

$(NONEXISTENT_D)/ccsched: $(POWEROFF_D)/ccsched
	@vagrant destroy -f ccsched

ccsched_UNPROVISION: $(NONEXISTENT_D)/ccsched
	@$(UNPROVISION) ccsched

# ---
cc1!: verifylocalenv $(NONEXISTENT_D)/cc1 $(PROVISIONED_D)/cc1

cc1--: cc1_UNPROVISION

cc1-: verifylocalenv $(POWEROFF_D)/cc1

cc1+: verifylocalenv $(RUNNING_D)/cc1

cc1: verifylocalenv $(PROVISIONED_D)/cc1 $(RUNNING_D)/cc1

$(RUNNING_D)/cc1: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cc1/requires/*)))
	@if [ -f $(PROVISIONED_D)/cc1 ] ; then			       \
	  vagrant up --no-provision cc1 || exit 51		     ; \
								       \
	elif [ -f $(POWEROFF_D)/cc1 ] ; then			       \
	  vagrant up --no-provision cc1 || exit 52		     ; \
								       \
	elif [ ! -f $(PROVISIONED_D)/cc1 -a ! -f $(NONEXISTENT_D)/cc1 ] ; then \
	    vagrant destroy -f cc1 || exit 53			     ; \
	fi

$(PROVISIONED_D)/cc1: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cc1/requires/*)))
	@for prereq in $^						; \
        do								  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then			  \
	    continue							; \
	  fi								; \
	  if [ ! -f "$${prereq}" ] ; then				  \
	    echo prerequisite: $${prereq} missing			; \
	    exit 54							; \
	  fi								; \
	done								; \
	if [ -f $(RUNNING_D)/cc1 -a ! -f $(PROVISIONED_D)/cc1 ] ; then    \
	  vagrant destroy -f cc1 || exit 55				; \
	fi								; \
	if [ ! -f $(PROVISIONED_D)/cc1 ] ; then		       	          \
	  vagrant up --provision cc1 || exit 56				; \
	  $(MARK_PROVISIONED)						; \
	fi

$(POWEROFF_D)/cc1:
	@vagrant halt cc1

$(NONEXISTENT_D)/cc1: $(POWEROFF_D)/cc1
	@vagrant destroy -f cc1

cc1_UNPROVISION: $(NONEXISTENT_D)/cc1
	@$(UNPROVISION) cc1

# ---
cc2!: verifylocalenv $(NONEXISTENT_D)/cc2 $(PROVISIONED_D)/cc2

cc2--: cc2_UNPROVISION

cc2-: verifylocalenv $(POWEROFF_D)/cc2

cc2+: verifylocalenv $(RUNNING_D)/cc2

cc2: verifylocalenv $(PROVISIONED_D)/cc2 $(RUNNING_D)/cc2

$(RUNNING_D)/cc2: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cc2/requires/*)))
	@if [ -f $(PROVISIONED_D)/cc2 ] ; then				       \
	  vagrant up --no-provision cc2 || exit 61			 ;     \
									       \
	elif [ -f $(POWEROFF_D)/cc2 ] ; then				       \
	  vagrant up --no-provision cc2 || exit 62			 ;     \
									       \
	elif [ ! -f $(PROVISIONED_D)/cc2 -a ! -f $(NONEXISTENT_D)/cc2 ] ; then \
	    vagrant destroy -f cc2 || exit 63				 ;     \
	fi

$(PROVISIONED_D)/cc2: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cc2/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 64								; \
	  fi									; \
	done									; \
	if [ -f $(RUNNING_D)/cc2 -a ! -f $(PROVISIONED_D)/cc2 ] ; then		  \
	  vagrant destroy -f cc2 || exit 65					; \
	fi									; \
	if [ ! -f $(PROVISIONED_D)/cc2 ] ; then		       	        	  \
	  vagrant up --provision cc2 || exit 66					; \
	  $(MARK_PROVISIONED)							; \
	fi

$(POWEROFF_D)/cc2:
	@vagrant halt cc2

$(NONEXISTENT_D)/cc2: $(POWEROFF_D)/cc2
	@vagrant destroy -f cc2

cc2_UNPROVISION: $(NONEXISTENT_D)/cc2
	@$(UNPROVISION) cc2

# ---
cclogin!: verifylocalenv $(NONEXISTENT_D)/cclogin $(PROVISIONED_D)/cclogin

cclogin--: verifylocalenv cclogin_UNPROVISION

cclogin-: verifylocalenv $(POWEROFF_D)/cclogin

cclogin+: verifylocalenv $(RUNNING_D)/cclogin

cclogin: verifylocalenv $(PROVISIONED_D)/cclogin $(RUNNING_D)/cclogin

$(RUNNING_D)/cclogin: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cclogin/requires/*)))
	@if [ -f $(PROVISIONED_D)/cclogin ] ; then				       \
	  vagrant up --no-provision cclogin					     ; \
	  rc=$$?								     ; \
	  if [ $${rc} -ne 0 ] ; then						       \
	    rm -f $(PROVISIONED_D)/cclogin					     ; \
	    exit 71								     ; \
	  fi									     ; \
	elif [ -f $(POWEROFF_D)/cclogin ] ; then				       \
	  vagrant up --no-provision cclogin					     ; \
	  rc=$$?								     ; \
	  if [ $${rc} -ne 0 ] ; then						       \
	    rm -f $(PROVISIONED_D)/cclogin					     ; \
	    exit 72								     ; \
	  fi									     ; \
										       \
	elif [ ! -f $(PROVISIONED_D)/cclogin -a ! -f $(NONEXISTENT_D)/cclogin ] ; then \
	  vagrant destroy -f cclogin || exit 73					     ; \
	fi									     ; \
	ssh cclogin uptime >/dev/null 2>&1					     ; \
	rc=$$?									     ; \
	if [ $${rc} -ne 0 ] ; then						       \
	  rm -f $(PROVISIONED_D)/cclogin					     ; \
	  exit 74								     ; \
	fi

$(PROVISIONED_D)/cclogin: $(REPOS_TGZ) $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/cclogin/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 75								; \
	  fi									; \
	done									; \
	if [ -f $(RUNNING_D)/cclogin -a ! -f $(PROVISIONED_D)/cclogin ] ; then	  \
	  vagrant destroy -f cclogin || exit 76					; \
	fi								      	; \
	if [ ! -f $(PROVISIONED_D)/cclogin ] ; then			       	  \
	  vagrant up --provision cclogin					; \
	  rc=$$?								; \
	  if [ $${rc} -ne 0 ] ; then						  \
	    rm -f $(PROVISIONED_D)/cclogin					; \
	    exit 77								; \
	  else									  \
	    $(MARK_PROVISIONED)							; \
	  fi									; \
	fi

$(POWEROFF_D)/cclogin:
	@vagrant halt cclogin

$(NONEXISTENT_D)/cclogin: $(POWEROFF_D)/cclogin
	@vagrant destroy -f cclogin

cclogin_UNPROVISION: $(NONEXISTENT_D)/cclogin
	@$(UNPROVISION) cclogin

# ---
ccgate!: verifylocalenv $(NONEXISTENT_D)/ccgate $(PROVISIONED_D)/ccgate

ccgate--: verifylocalenv ccgate_UNPROVISION

ccgate-: verifylocalenv $(POWEROFF_D)/ccgate

ccgate+: verifylocalenv $(RUNNING_D)/ccgate

ccgate: verifylocalenv $(PROVISIONED_D)/ccgate $(RUNNING_D)/ccgate

$(RUNNING_D)/ccgate: $(REPOS_TGZ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccgate/requires/*)))
	@if [ -f $(PROVISIONED_D)/ccgate ] ; then				       \
	  vagrant up --no-provision ccgate					     ; \
	  rc=$$?								     ; \
	  if [ $${rc} -ne 0 ] ; then						       \
	    rm -f $(PROVISIONED_D)/ccgate					     ; \
	    exit 81								     ; \
	  fi									     ; \
	elif [ -f $(POWEROFF_D)/ccgate ] ; then					       \
	  vagrant up --no-provision ccgate					     ; \
	  rc=$$?								     ; \
	  if [ $${rc} -ne 0 ] ; then						       \
	    rm -f $(PROVISIONED_D)/ccgate					     ; \
	    exit 82								     ; \
	  fi									     ; \
										       \
	elif [ ! -f $(PROVISIONED_D)/ccgate -a ! -f $(NONEXISTENT_D)/ccgate ] ; then \
	  vagrant destroy -f ccgate || exit 83					     ; \
	fi									     ; \
	ssh ccgate uptime >/dev/null 2>&1					     ; \
	rc=$$?									     ; \
	if [ $${rc} -ne 0 ] ; then						       \
	  rm -f $(PROVISIONED_D)/ccgate						     ; \
	  exit 84								     ; \
	fi

$(PROVISIONED_D)/ccgate: $(REPOS_TGZ) $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/ccgate/requires/*)))
	@for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 85								; \
	  fi									; \
	done									; \
	if [ -f $(RUNNING_D)/ccgate -a ! -f $(PROVISIONED_D)/ccgate ] ; then	  \
	  vagrant destroy -f ccgate || exit 86					; \
	fi								      	; \
	if [ ! -f $(PROVISIONED_D)/ccgate ] ; then			       	  \
	  vagrant up --provision ccgate					; \
	  rc=$$?								; \
	  if [ $${rc} -ne 0 ] ; then						  \
	    rm -f $(PROVISIONED_D)/ccgate					; \
	    exit 87								; \
	  else									  \
	    $(MARK_PROVISIONED)							; \
	  fi									; \
	fi

$(POWEROFF_D)/ccgate:
	@vagrant halt ccgate

$(NONEXISTENT_D)/ccgate: $(POWEROFF_D)/ccgate
	@vagrant destroy -f ccgate

ccgate_UNPROVISION: $(NONEXISTENT_D)/ccgate
	@$(UNPROVISION) ccgate

# ---

# don't create tarball if not clean
$(TAR_GET): clean
	@echo "tar: "
	@tar $(TAR_ARGS) $(VIRTUALCLUSTER) $(TAR_ADDITIONAL_FILES)
	@echo

# cksum is conditional on the tarball
$(TAR_GET_CKSUM): $(TAR_GET)
	@cksum $(TAR_GET) > $(TAR_GET_CKSUM)
	@ln -f $(TAR_GET_CKSUM) $(CC_CKSUM)

# pkging is conditional on the tarball, cksum and other top-level files, like this one
pkg tarball:	$(CC_CKSUM) $(CC_TGZ) $(TAR_ADDITIONAL_FILES) html/index.html clean
	@ls -ltL $(CC_TGZ) $(CC_CKSUM)

$(TARBALLS):
	@mkdir $(TARBALLS)

$(TARBALL_REPOS_TGZ) $(TARBALL_VBOXADD_ISO): $(TARBALLS)

$(CC_TGZ): $(TAR_GET)
	@ln -f $< $(CC_TGZ)

$(CC_CKSUM): $(TARBALLS) $(CC_TGZ)
	@cksum $(CC_TGZ) > $(CC_CKSUM)

# The rsync is only necessary if the source and destination are on different file systems.
$(REPOS_TGZ):	$(TARBALL_REPOS_TGZ)
	@if [ -f $(REPOS_TGZ_PREV) ] ; then				  \
		ln -f $(REPOS_TGZ_PREV) $(REPOS_TGZ)			; \
		cmp $(TARBALL_REPOS_TGZ) $(REPOS_TGZ) ||		  \
			rsync -cau $(TARBALL_REPOS_TGZ) $(REPOS_TGZ)	; \
	fi
	@if [ -f $(ALT_REPOS_TGZ) ] ; then				  \
		ln -f $(ALT_REPOS_TGZ) $(REPOS_TGZ)			; \
		cmp $(ALT_REPOS_TGZ) $(REPOS_TGZ) ||			  \
			rsync -cau $(ALT_REPOS_TGZ) $(REPOS_TGZ)	; \
	fi

$(VBOXADD_ISO):	 $(TARBALL_VBOXADD_ISO)
	if [ -f $(VBOXADD_ISO) ] ; then					 \
		ln -f $(TARBALL_VBOXADD_ISO) $(VBOXADD_ISO) ||		 \
			rsync -cau $(TARBALL_VBOXADD_ISO) $@		;\
	fi

html/index.html: Doxyfile
	@doxygen
	@[ ! -s $(DOXYGEN_OUT) ] && rm $(DOXYGEN_OUT)

$(DOXYGEN_OUT): Doxyfile
	@doxygen
	@[ ! -s $(DOXYGEN_OUT) ] && rm $(DOXYGEN_OUT)

doc:	html/index.html
	@if [ -x $$(which xdg-open) ] ; then		     \
		xdg-open $<	     ;			     \
	elif [ -x $$(which open) ]   ; then		     \
		open $<		     ;			     \
	else						     \
		echo See: file:///$$\(pwd\)/html/index.html; \
	fi

$(VIRTUALCLUSTER): $(CC_TGZ) $(CC_CKSUM) $(REPOS_TGZ)

