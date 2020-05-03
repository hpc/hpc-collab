#!/usr/bin/make

TSTAMP	       := $(shell date +%y%m%d.%H%M)
OS		= $(shell uname -s)
PWD		= $(shell pwd)
WHERE_INVOKED	= $(basename $(dir $(PWD)))
IAM		= $(notdir $(PWD))

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

# potential clusters contain a Makefile
# disabled clusters do not contain a Vagrantfile and a Makefile
#   ie. "mv Vagrantfile Vagrantfile.ASIDE" or "mv Makefile Makefile.ASIDE" to disable

Makefile	= */Makefile
Vagrantfile	= */Vagrantfile

SUBDIRS_CONTAINING_MAKEFILE_RAW		= $(wildcard $(Makefile))
SUBDIRS_CONTAINING_MAKEFILE		= $(dir $(SUBDIRS_CONTAINING_MAKEFILE_RAW))
SUBDIRS_CONTAINING_MAKEFILE_NOSLASH	= $(SUBDIRS_CONTAINING_MAKEFILE:/=)

SUBDIRS_CONTAINING_VAGRANTFILE_RAW	= $(wildcard $(Vagrantfile))
SUBDIRS_CONTAINING_VAGRANTFILE     	= $(dir $(SUBDIRS_CONTAINING_VAGRANTFILE_RAW))
SUBDIRS_CONTAINING_VAGRANTFILE_NOSLASH  = $(SUBDIRS_CONTAINING_VAGRANTFILE:/=)

DISABLED_CLUSTERS=$(filter-out $(foreach w,$(SUBDIRS_CONTAINING_VAGRANTFILE_NOSLASH),$(w)), \
						$(SUBDIRS_CONTAINING_MAKEFILE_NOSLASH))


SUBDIRS_UNIQ	 = $(sort $(SUBDIRS_CONTAINING_MAKEFILE_NOSLASH))
CLUSTERS	 = $(filter-out $(DISABLED_CLUSTERS),$(SUBDIRS_UNIQ))
CLUSTERS_NOTILDE = $(filter-out %~,$(CLUSTERS))
ENABLED_CLUSTERS = $(CLUSTERS_NOTILDE)

TARBALLS	= tarballs
TARBALLS_D	= ../$(TARBALLS)

comma	       := ,
empty	       :=
plus	       := +
space	       := $(empty) $(empty)

# in particular, not MacOS (unless gnutar is forced into the path)
TAR_CHECKPOINT_ARGS	=
ifeq ($(OS),Linux)
TAR_CHECKPOINT_ARGS    := --checkpoint-action=dot --checkpoint=8192
endif

#TAR_ADDITIONAL_FILE	= $(TAR_ADDITIONAL_FILES) $(PROVISION_D)/Modules/*

TAR_ADDITIONAL_FILES	= Makefile Notes README todo

TAR_STEM 	       := $(subst $(space),$(plus),$(ENABLED_CLUSTERS))

tgz_suffix		= .tgz
cksum_suffix		= .cksum

repos_tgz		= repos$(tgz_suffix)
vc_tgz			= $(TAR_STEM)$(tgz_suffix)
VC_TGZ			= $(TARBALLS_D)/$(vc_tgz)
VC_CKSUM		= $(TARBALLS_D)/$(TAR_STEM)$(cksum_suffix)

TAR_EXCLUDE_ARGS	= --exclude=\*$(tgz_suffix)	\
				--exclude=$(TARBALLS)	\
				--exclude=._\*		\
				--exclude=.ssh		\
				--exclude=.vagrant	\
				--exclude=.Trash	\
				--exclude=*NOT\ MOUNTED.

TAR_STAMP		= $(TAR_STEM),$(TSTAMP)
TAR_GET			= $(TARBALLS_D)/$(TAR_STAMP)$(tgz_suffix)
TAR_GET_CKSUM		= $(TARBALLS_D)/$(TAR_STAMP)$(cksum_suffix)

TAR_ARGS		= $(TAR_EXCLUDE_ARGS) -czf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_VERBOSE_ARGS	= $(TAR_EXCLUDE_ARGS) -cvzf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)
TAR_ARGS		= $(TAR_EXCLUDE_ARGS) -czf $(TAR_GET) $(TAR_CHECKPOINT_ARGS)

TARBALL_REPOS_TGZ	= $(TARBALLS_D)/$(repos_tgz)

TARGETS		= clusters show-vars show_vars vars show all

# VC_TARGETS are passed through to enabled clusters
VC_TARGETS	= up ready provision				\
		  poweroff					\
		  down unprovision				\
		  clean-state clean				\
		  show						\
		  save-logs savelogs save-log savelog		\
		  collect-logs collectlogs collect-log collectlog

PKG_TARGETS =	pkg tarball

.PHONY: $(TARGETS) $(VC_TARGETS) $(PKG_TARGETS)

export VC VIRTUALCLUSTER

## if not a known (to us) target, assume it may be a node name, look for a subdirectory that includes that node
## assumes: 1st two characters of target name may be a cluster name
## @todo XXX could look for ${_VC}/cfg/$
.DEFAULT:
	$(HUSH)export _NODE=$(@F)											; \
	export _VC=$${_NODE:0:2}											; \
	if [ -n "$(VC)" ] ; then											  \
	  if [ -z "$${_NODE}" ]	; then											  \
	    echo CURDIR:$(CURDIR): _NODE: empty										; \
	    exit 99													; \
	  fi														; \
	  if [ -z "$${_VC}" ] ; then											  \
	    echo CURDIR:$(CURDIR): _VC: empty										; \
	    exit 99													; \
	  fi														; \
	  export _VC=$(VC)												; \
	fi														; \
	if [ -n "$${_VC}" ] ; then											  \
	  if [ -n "$${_NODE}" ] ; then											  \
	    if [ -d $${_VC} ] ; then											  \
	      if [ -d $${_VC}/cfg/$${_NODE} ] ; then									  \
	        if [ ! -f "$${_VC}/common/._state/provisioned/$${_NODE}" ] ; then					  \
	          env VC=$${_VC} VIRTUALCLUSTER=$${_VC} $(MAKE) --quiet -s VC=$${_VC} -C $${_VC} $(@F)			; \
	        else													  \
	          if [ -z "$(HUSH)" ] ; then										  \
		    echo provisioned: $${_NODE}										; \
	          fi													; \
	        fi													; \
	      fi													; \
	    fi														; \
	  fi														; \
	fi

$(VC_TARGETS):
	$(HUSH)for _c in $(ENABLED_CLUSTERS)										; \
	do														  \
		env VC=$${_c} VIRTUALCLUSTER=$${_c} $(MAKE) --quiet -s VC=$${_c} -C $${_c} $(MAKECMDGOALS)		; \
	done

show_vars show-vars vars: clusters
	$(HUSH)echo "TAR_STEM:$(TAR_STEM)"

clusters:
	$(HUSH)if [ -z "$(HUSH)" ] ; then	  \
	  $(info + $(ENABLED_CLUSTERS))	:	; \
	  $(info - $(DISABLED_CLUSTERS)):	; \
	fi


### tarball

$(TARBALLS_D):
	$(HUSH)mkdir $(TARBALLS_D)

$(TAR_GET): unprovision
	$(HUSH)echo "tar: "
	$(HUSH)tar $(TAR_ARGS) $(ENABLED_CLUSTERS) $(TAR_ADDITIONAL_FILES)
	$(HUSH)echo

# cksum is conditional on the tarball
$(TAR_GET_CKSUM): $(TAR_GET)
	$(HUSH)cksum $(TAR_GET) > $(TAR_GET_CKSUM)
	$(HUSH)ln -f $(TAR_GET_CKSUM) $(VC_CKSUM)

# pkging was conditional on the tarball, cksum and other top-level files, like this one
# pkging is now done by our parent, not at this level
#$(PKG_TARGETS):	$(VC_CKSUM) $(VC_TGZ) $(TAR_ADDITIONAL_FILES)

$(PKG_TARGETS):	 $(TAR_ADDITIONAL_FILES)
	$(HUSH)ls -ltL $^

$(TARBALL_REPOS_TGZ): $(TARBALLS_D)
	$(HUSH)for _f in $@				;\
	do						 \
	  if [ ! -f $${_f} ] ; then			 \
	    echo missing prerequisite: $${_f}		;\
	    exit 104					;\
	  fi						;\
	done

$(VC_TGZ): $(TARBALLS_D) $(TAR_GET)
	$(HUSH)ln -f $(TAR_GET) $@

$(VC_CKSUM): $(TARBALLS_D) $(VC_TGZ)
	$(HUSH)cksum $(VC_TGZ) > $(VC_CKSUM)

