#!/usr/bin/make

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

## @todo if CentOS vs Ubuntu, etc:

SUBDIRS_WITH_NEED_SPACE	= $(wildcard */need_space)
SUBDIRS			= $(dir $(SUBDIRS_WITH_NEED_SPACE))

IAM			= $(notdir ${CURDIR})
TSTAMP	       	       := $(shell date +%y%m%d.%H%M)

SPACE_AVAIL		= ../bin/space_avail

PREREQ_ERROR_EXIT	= 99

.PHONY: all $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	declare -x TARGET_RAW							; \
	declare -x TARGET_NORMAL						; \
	declare -x TARGET_SPACEAVAIL						; \
	TARGET_RAW=$$(cd $@; cat target)					; \
	TARGET_NORMAL=$$(bash -c "cd $@; cd \"$${TARGET_RAW}\"; pwd")		; \
	TARGET_SPACEAVAIL=$(cd $@; shell $(SPACE_AVAIL) -v)			; \
	(cd $@; $(SPACE_AVAIL)) ||						  \
	$(error Insufficient space: try creating a symlink to 			  \
		$(shell bash -c "cd $@; $(SPACE_AVAIL) -v") from		  \
		$(shell bash -c "cd $@; cat \"$${TARGET_RAW}\"")		  \
		which has the largest block of available space)

