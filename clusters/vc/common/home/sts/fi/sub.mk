#!/usr/bin/make

TSTAMP		       := $(shell date +%y%m%d.%H%M)
OS			= $(shell uname -s)
PWD			= $(shell pwd)
WHERE_INVOKED		= $(basename $(dir $(PWD)))
IAM			= $(notdir $(PWD))
FILES_RAW		= $(shell find . -maxdepth 1 -type f | sed 's/\.\///')
SUBDIRS_RAW		= $(shell find . -type d | sed 's/\.\///')
SUBDIRS_NOT_IAM		= $(shell echo $(SUBDIRS_RAW) | sed 's/\. //')
SUBDIRS_WITH_MAKE	= $(shell ls $(addsuffix /Makefile,$(foreach x,$(SUBDIRS_NOT_IAM),$(x))) 2>/dev/null)
SUBDIRS_WITH_MAKE_D	= $(shell echo $(dir $(SUBDIRS_WITH_MAKE)) | sed 's/\/$$//')

all: $(IAM)

.PHONY: emit

$(IAM): $(SUBDIRS_WITH_MAKE_D) $(FILES_RAW)
	@skipped=""								  ; \
	executed=""								  ; \
	subdir_make=""								  ; \
	for f in $^								  ; \
	do									    \
	  if [ -s $${f} -a -x $${f} -a -f $${f} ] ; then			    \
		echo --- 							  ; \
		echo "$${f} output follows... "					  ; \
	        ./$${f}	|| exit 1						  ; \
		executed="$${executed} $${f}"					  ; \
		echo ---							  ; \
	  else								    \
	    if ! [[ "$${f}" =~ .* ]] ; then				    \
		skipped="$${skipped} $${f}"					  ; \
	    fi								  ; \
	  fi								  ; \
	done									  ; \
	if [ -n "$${skipped}" -o -n "$${executed}" -o -n "$${subdir_make}" ] ; then \
	  echo "dir: $${PWD}"							  ; \
	  if [ -n "$${skipped}" ] ; then					    \
	    echo "skipped: $${skipped}"						  ; \
	  fi									  ; \
	  if [ -n "$${executed}" ] ; then					    \
	    echo "executed: $${executed}"					  ; \
	  fi									  ; \
	  if [ -n "$${subdir_make}" ] ; then					    \
	    echo "subdir_make: $${subdir_make}"					  ; \
	  fi									  ; \
	fi

$(FILES_RAW):

$(SUBDIRS_WITH_MAKE_D):
	make -C $@

emit:
	@echo ' '
	@echo TSTAMP:	$(TSTAMP)
	@echo OS:	$(OS)
	@echo PWD:	$(PWD)
	@echo WHERE_INVOKED:	$(WHERE_INVOKED)
	@echo IAM:	$(IAM)
	@echo FILES_RAW:	$(FILES_RAW)
	@echo SUBDIRS_RAW:	$(SUBDIRS_RAW)
	@echo SUBDIRS_NOT_IAM:	$(SUBDIRS_NOT_IAM)
	@echo SUBDIRS_WITH_MAKE: $(SUBDIRS_WITH_MAKE)
	@echo SUBDIRS_WITH_MAKE_D: $(SUBDIRS_WITH_MAKE_D)
	@echo ' '


