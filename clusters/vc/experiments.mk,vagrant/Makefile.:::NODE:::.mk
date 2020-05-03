
#
# Makefile to programmatically
#  - report on the current state of the virtual cluster's nodes
#  - codification of the dependencies between nodes
#  - perform node state changes including necessary bookkeeping as they transition among states
#
# This Makefile is a convenience, mostly. The direct vagrant tools remain accessible.
# It does enforce discipline on the state directory, which may be helpful.
#

SHELL		:= bash
.SHELLFLAGS	:= -eu -o pipefail -c
MAKEFLAGS	+= --warn-undefined-variables
#HUSH		 =
HUSH		 = @


PWD		= $(shell pwd)
WHERE_INVOKED	= $(basename $(dir $(PWD)))
IAM		= $(notdir $(PWD))

VIRTUALCLUSTER  = $(IAM)
CFG	        = $(PWD)/cfg

NODES  	        = $(filter $(VC)%, $(notdir $(wildcard $(CFG)/*)))
TSTAMP	       := $(shell date +%y%m%d.%H%M)
OS	        = $(shell uname -s)

export VAGRANT_CWD = $(PWD)
export PATH	  := $(shell echo $${PATH}):$(PWD)/$(CFG)/provision/bin

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
COMMON_D	  = common
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
XFR		= xfr
XFR_PREV	= ~/xfr
DOXYGEN_OUT	= Doxygen.out

repos_tgz		= repos.tgz
XFR_REPOS_TGZ		= $(XFR)/$(repos_tgz)
XFR_REPOS_TGZ_PREV	= $(XFR_PREV)/$(repos_tgz)

PROVISION_D      = $(CFG)/provision
PROVISION_FLAG_D = $(PROVISION_D)/flag
PROVISION_ENV	 = $(PROVISION_D)/env
PROVISION_BIN	 = $(PROVISION_D)/bin

TARBALLS	     = tarballs
TARBALLS_D	     = ../../$(TARBALLS)
TARBALL_REPOS_TGZ    = $(TARBALLS_D)/$(repos_tgz)
TAR_EXCLUDE_ARGS     = --exclude=$(repos_tgz) --exclude=$(TARBALLS) --exclude=._\* \
			--exclude=.ssh --exclude=.vagrant

TAR_GET		     = $(TARBALLS_D)/$(VIRTUALCLUSTER),$(TSTAMP).tgz
TAR_GET_CKSUM	     = $(TARBALLS_D)/$(VIRTUALCLUSTER),$(TSTAMP).cksum

TAR_CHECKPOINT_ARGS  =
ifeq ($(OS),Linux)
TAR_CHECKPOINT_ARGS := --checkpoint-action=dot --checkpoint=4096
endif
TAR_VERBOSE_ARGS     = $(TAR_EXCLUDE_ARGS) -cvzf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ARGS	     = $(TAR_EXCLUDE_ARGS) -czf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ADDITIONAL_FILES = Makefile README Doxyfile setpath.csh setpath.sh
#TAR_ADDITIONAL_FILES = Makefile README Doxyfile $(PROVISION_D)/Modules/*

vc_tgz		= $(VIRTUALCLUSTER).tgz
vc_cksum	= $(VIRTUALCLUSTER).cksum
VC_TGZ		= $(TARBALLS_D)/$(vc_tgz)
VC_CKSUM	= $(TARBALLS_D)/$(VIRTUALCLUSTER).cksum
TMP_VC_CKSUM	= $(TMP)/$(VIRTUALCLUSTER).cksum

VBOX_VERSION		= $(shell cat $(PROVISION_D)/config/vboxadd/version)
VBOXADD_ISO_SUF		= VBoxGuestAdditions_$(VBOX_VERSION).iso
XFR_VBOXADD_ISO		= $(XFR)/$(VBOXADD_ISO_SUF)
XFR_VBOXADD_ISO_PREV	= $(XFR_PREV)/$(VBOXADD_ISO_SUF)
TARBALL_VBOXADD_ISO	= $(TARBALLS_D)/$(VBOXADD_ISO_SUF)
XFR_PREREQ		= $(XFR_VBOXADD_ISO) $(XFR_REPOS_TGZ)

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
STATE_LIST	 = nonexistent poweroff running provisioned
NODES_STATE	 = $(subst $(STATE_D)/,,$(foreach s,$(STATE_LIST),$(wildcard $(STATE_D)/$(s)/*)))
NODES_INC	:= $(addsuffix .mk,$(addprefix INC_,$(foreach n,$(NODES),$(n))))

# generate per-node make include makefile
NODE_PATTERN		= :::NODE:::
NODE_PATTERN_INC	= $(NODE_PATTERN).mk

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

HUMANFRIENDLY_TARGETS = clean clean-state compare-vc-cksum doc help \
				ingest-state pkg show show-state show-vars status \
				todo verifylocalenv copyright

.PHONY: $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

PHONY := $(HUMANFRIENDLY_TARGETS) $(HUMANFRIENDLY_FLAGS)

### .DELETE_ON_ERROR:

all:	show

copyright:
	$(HUSH)copyright.sh

clean-state:
	$(HUSH)mkdir -p $(STATE_DIRS)
	$(HUSH)rm -f $(RUNNING_D)/* $(PROVISIONED_D)/* $(POWEROFF_D)/* $(NONEXISTENT_D)/*
	$(HUSH)vagrant global-status --prune >/dev/null 2>&1 &

clean: $(NONEXISTENT_FLAGS)
	$(HUSH)rm -f $(DOXYGEN_OUT)
	$(HUSH)find . -name ._\* -type f -exec rm -f \{\} \;

show-state: show

status: show

show-vars:
	$(HUSH)echo
	$(HUSH)echo FLAGS:		$(FLAGS)
	$(HUSH)echo FLAGS_OFF:	$(FLAGS_OFF)
	$(HUSH)echo FLAGS_ON:		$(FLAGS_ON)
	$(HUSH)echo FLAGS_QUICK:	$(FLAGS_QUICK)
	$(HUSH)echo FLAGS_COMPLETE:	$(FLAGS_COMPLETE)
	$(HUSH)echo

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
	$(HUSH)echo -n

todo:
	more $(VC)/../Notes

## @todo use graphviz on Makefile to self-generate this
help:	Makefile
	$(HUSH)echo 
	$(HUSH)echo   'make [ up | provision | ready | poweroff | halt | down | nonexistent | unprovision]'
	$(HUSH)echo   'make [show | help]'
	$(HUSH)echo   'make [flag-quick | flag-complete | quick | complete | flag | show-flags]'
	$(HUSH)echo   'make ['$(NODES)']'
	$(HUSH)echo	'make doc'
	$(HUSH)echo
	$(HUSH)echo   '  provision, ready, up		= ready to run, node is running and successfully provisioned'
	$(HUSH)echo   '  halt, down, poweroff, off	= node is not running, halted, down, powered off'
	$(HUSH)echo   '  nonexistent			= node is not configured'
	$(HUSH)echo   '  unprovision			= node is not configured and no flags remain indicating it is'
	$(HUSH)echo   '			  	  This state is used internally and for debugging.'
	$(HUSH)echo   '  flag-quicker			= set provision flags for quicker provisioning'
	$(HUSH)echo   '  flag-complete			= set provision flags for (more) complete provisioning'
	$(HUSH)echo
	$(HUSH)echo   '  help				= this message'
	$(HUSH)echo   '  show [DEFAULT]		= show a list of individual node state'
	$(HUSH)echo   '  doc				= generate and view documentation'
	$(HUSH)echo
	$(HUSH)echo   ' Equivalencies:'
	$(HUSH)echo   '  	<node>               	= "make provision <node>"'
	$(HUSH)echo   '  	<node>!               	= "make destroy <node>; make provision <node>"'
	$(HUSH)echo   '  	<node>+               	= "make running <node>"'
	$(HUSH)echo   '  	<node>-               	= "make poweroff <node>"'
	$(HUSH)echo   '  	<node>--               	= "make unprovision <node>"'
	$(HUSH)echo
	$(HUSH)echo   'make todo			= shows the current working notes'
	$(HUSH)echo   'make ingest-state		= force recollection of vagrant state'
	$(HUSH)echo
	$(HUSH)echo   '"make up", "make <node>" or "make show"  will be of most use.'
	$(HUSH)echo
	$(HUSH)echo 	"Shorcuts for these commands are available if one's PATH includes: $(PROVISION_BIN)"
	$(HUSH)echo 	'which can be set with "[bash] . setpath.sh" or "[*csh] source setpath.csh"'
	$(HUSH)echo	' so that they can just be invoked as "up", "show", "unprovision" &c'
	$(HUSH)echo
	$(HUSH)sed -n '/^# ### state diagram/,/^# state diagram ###/p;/^state diagram ###/q' < Makefile | grep -v 'state diagram' | sed 's/^# / /'

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

ingest-state: $(clean-state)
	$(HUSH)$(INGEST_STATE)

verifylocalenv: $(STATE_DIRS)
	$(HUSH)$(VERIFY_LOCAL_ENV)

$(STATE_DIRS):
	$(HUSH)mkdir -p $@

### ### ### ###
# bulk NODE states
#  ie. all PROVISIONED, all POWEROFF, all UNPROVISION

up provision: $(NODES_INC) verifylocalenv $(PROVISIONED_FLAGS)
up! provision!: unprovision up

running ready on: $(NODES_INC) verifylocalenv $(RUNNING_FLAGS)

halt down poweroff off: $(NODES_INC) verifylocalenv $(POWEROFF_FLAGS)

nonexistent: $(NODES_INC) verifylocalenv $(NONEXISTENT_FLAGS)

unprovision: $(NODES_INC) verifylocalenv $(TARGETS_UNPROVISION) ingest-state

provision-quicker quicker-provision: $(NODES_INC) flags-quicker provision

provision-complete complete-provision: $(NODES_INC) flags-complete provision

$(TARBALLS):

$(TARBALL_REPOS_TGZ) $(TARBALL_VBOXADD_ISO): $(TARBALLS_D)
	$(HUSH)for _f in $@				;\
	do						 \
	  if [ ! -f $${_f} ] ; then			 \
	    echo missing prerequisite: $${_f}		;\
	    exit 104					;\
	  fi						;\
	done

$(VC_TGZ): $(TAR_GET)
	$(HUSH)ln -f $< $(VC_TGZ)

$(VC_CKSUM): $(TARBALLS_D) $(VC_TGZ)
	$(HUSH)cksum $(VC_TGZ) > $(VC_CKSUM)

# Attempt to ln to conserve disk space
$(XFR_REPOS_TGZ): $(TARBALL_REPOS_TGZ)
	$(HUSH)if [ -d $(VIRTUALCLUSTER)~ -a -d $(XFR_PREV) -a $(XFR_REPOS_TGZ_PREV) ] ; then	  \
	  ln -f $(XFR_REPOS_TGZ_PREV) $(XFR_REPOS_TGZ)						; \
	fi											; \
	if [ -f $(TARBALL_REPOS_TGZ) ] ; then							  \
	  echo validating prerequisite: $(XFR_REPOS_TGZ)					; \
	  rsync -cau $(TARBALL_REPOS_TGZ) $(XFR_REPOS_TGZ)					; \
	fi

# attempt to use ln to avoid running out of space on the partition holding $(XFR_...)
$(XFR_VBOXADD_ISO): $(TARBALL_VBOXADD_ISO)
	$(HUSH)if [ -f $(XFR_VBOXADD_ISO_PREV) ] ; then					  \
	  ln -f $(XFR_VBOXADD_ISO_PREV) $@						; \
	else										  \
	  ln -f $< $@ ||								  \
	    rsync -cau $< $@								; \
	fi

$(NODES_INC):	$(NODE_PATTERN_INC)
	for n in $(NODES)								  \
	do										; \
		sed "s/$(NODE_PATTERN)/$$(n)/" < $(NODE_PATTERN_INC) > INC_$$(n).mk	; \
	done

### ### ### ###
include $(NODES_INC)
