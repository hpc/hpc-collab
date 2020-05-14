#!/usr/bin/make

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

## @todo if CentOS vs Ubuntu, etc:

IAM			= $(notdir ${CURDIR})
TSTAMP	       	       := $(shell date +%y%m%d.%H%M)

SPACE_AVAIL		= ../bin/space_avail

PREREQ_ERROR_EXIT	= 99

.PHONY: all check_space

all: check_space

# XXX @todo fix TARGET_NORMAL parsing
check_space:
	declare -x TARGET_RAW							; \
	declare -x TARGET_NORMAL						; \
	declare -x TARGET_SPACEAVAIL						; \
	TARGET_RAW=$(shell cat target)						; \
	TARGET_NORMAL=$(realpath $${TARGET_RAW})				; \
	TARGET_SPACEAVAIL=$(shell bash -c "$(SPACE_AVAIL) -v")			; \
	$(SPACE_AVAIL) ||							  \
	printf Insufficient space: perhaps create a symlink to			  \
		$(shell bash -c "$(SPACE_AVAIL) -v") from			  \
		$(shell bash -c "$${TARGET_NORMAL}")				  \
		which has the largest block of available space.

