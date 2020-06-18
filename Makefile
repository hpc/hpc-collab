#!/usr/bin/make

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

## @todo if CentOS vs Ubuntu, etc:

SUBDIRS_WITH_MAKEFILE_RAW	= $(wildcard */Makefile)
SUBDIRS				= $(dir $(SUBDIRS_WITH_MAKEFILE_RAW))

IAM				= $(notdir ${CURDIR})
TSTAMP	       		       := $(shell date +%y%m%d.%H%M)

HUMAN_FRIENDLY			= prereq prerequisites
TARGETS				= all clean clean-state show up down unprovision provision savelogs

REQUIRES_D			= requires
PREREQ_SW_D			= $(REQUIRES_D)/sw
PREREQ_INGEST_D			= $(REQUIRES_D)/ingest
PREREQ_STORAGE_D		= $(REQUIRES_D)/storage

PREREQ_SW			= $(wildcard $(PREREQ_SW_D)/*)
PREREQ_INGEST			= $(wildcard $(PREREQ_INGEST_D)/*)
PREREQ_STORAGE			= $(wildcard $(PREREQ_STORAGE_D)/*)
PREREQ_LIST			= $(notdir $(PREREQ_SW))
PREREQ				= $(PREREQ_LIST)

PREREQ_ERROR_EXIT		= 99

.PHONY: $(PREREQ) $(SUBDIRS) $(HUMAN_FRIENDLY) $(TARGETS)

$(HUMAN_FRIENDLY): $(PREREQ) $(basename $(PREREQ_LIST))

$(TARGETS): $(PREREQ) $(SUBDIRS)

all:	$(HUMAN_FRIENDLY) $(TARGETS) $(SUBDIRS) pkg

$(PREREQ):

TAR_ADDITIONAL_FILES = Makefile README INSTALL.tarball requires bin
TAR_ARGS = --ignore-failed-read --one-file-system --checkpoint-action=dot --checkpoint=16384 -czf
TAR_EXCLUDE = --exclude=\*repos.tgz\* --exclude=\*.iso --exclude=tarballs
TAR_D = tarballs
TAR_PKG = $(IAM).$(TSTAMP).tgz
TAR_GET = $(TAR_D)/$(TAR_PKG)
TAR_CKSUM = $(IAM).$(TSTAMP).cksum
TAR_GET_CKSUM = $(TAR_D)/$(TAR_CKSUM)

.DELETE_ON_ERROR = $(TAR_GET) $(TAR_D)/$(IAM).$(TSTAMP).cksum

pkg:
	$(MAKE) -C clusters pkg
	tar $(TAR_EXCLUDE) $(TAR_ARGS) $(TAR_GET) $(TAR_ADDITIONAL_FILES) clusters
	$(info )
	cksum $(TAR_GET) > $(TAR_GET_CKSUM)
	ls -l $(TAR_GET) $(TAR_GET_CKSUM)
	
$(PREREQ_INGEST): $(PREREQ_STORAGE)

# @todo => gmake function, also fuzzier match
# @todo move to subsidiary Makefile
prerequisites prereq: $(PREREQ_LIST)
	$(MAKE) -C requires/storage
	$(MAKE) -C requires/ingest
	$(HUSH)set first=""											; \
	for f in $(sort $^)											; \
        do													  \
		is=$$(requires/sw/$$f/cmd)									; \
		requires=$$(cat requires/sw/$$f/version)							; \
		if [ -z "$${is}" ] ; then									  \
		  echo "$$f version: empty"									; \
		  exit $(PREREQ_ERROR_EXIT)									; \
		fi												; \
		if [ -z "$${requires}" ] ; then									  \
		  echo "$$f requires: empty"									; \
		  exit $(PREREQ_ERROR_EXIT)									; \
		fi												; \
		is_maj=$$(echo $${is} | cut -d. -f1,1)								; \
		requires_maj=$$(echo $${requires} | cut -d. -f1,1)						; \
		if [ "$${is_maj}" != "$${requires_maj}" ] ; then						  \
		  warn=""											; \
		  if [ -f "requires/sw/$$f/warning-only" ] ; then						  \
		    warn=" (warning)"										; \
		  fi												; \
		  printf "\n$$f: mismatch: version required:$${requires} != found:$${is}$(warn)\n"		; \
	          if [ -z "${warn}" ] ; then									  \
	           exit $(PREREQ_ERROR_EXIT)									; \
	          fi												; \
	        else                                                                   		                  \
	          if [ -n "$(HUSH)" ] ; then									  \
	            echo -n "$$first$$f"									; \
		    first=" "											; \
	          fi												; \
	        fi												; \
	done													; \
	echo ''

$(SUBDIRS): $(PREREQ)
	$(HUSH)$(MAKE) -s -C $@ $(MAKECMDGOALS)

help:
	make -s -C clusters/vc $@
