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

check_space:
	declare -x TARGET_RAW							; \
	declare -x TARGET_NORMAL						; \
	declare -x TARGET_SPACEAVAIL						; \
	if [ ! -f target ] ; then						  \
		echo target: does not exist					; \
		exit $(PREREQ_ERROR_EXIT)					; \
	fi									; \
	TARGET_RAW=$$(cat target)						; \
	TARGET_COOKED=$$(bash -c "echo \"$${TARGET_RAW}\"")			; \
	TARGET_NORMAL=$$(realpath "$${TARGET_COOKED}")				; \
	if [ -z "$${TARGET_NORMAL}" ] ; then					  \
		echo empty TARGET_NORMAL					; \
		exit $(PREREQ_ERROR_EXIT)					; \
	fi									; \
	TARGET_SPACEAVAIL=$(shell bash -c "$(SPACE_AVAIL) -v")			; \
	AVAIL_BLKS=$$(stat -f --format="%a" "$${TARGET_SPACEAVAIL}")		; \
	AVAIL_FS=$$(stat -f --format="%i" "$${TARGET_SPACEAVAIL}")		; \
	TARGET_FS=$$(stat -f --format="%i" "$${TARGET_NORMAL}")			; \
	$(SPACE_AVAIL)								; \
	rc=$$?									; \
	if [ "$${rc}" -ne 0 ] ; then						  \
		printf "Insufficient space: $${TARGET_FS}"			; \
		if [ "$${TARGET_FS}" != "$${AVAIL_FS}" ] ; then			  \
			printf Perhaps create a symlink to			  \
				$${TARGET_SPACEAVAIL} from $${TARGET_NORMAL}	  \
				which has $${AVAIL_BLKS} available blocks.	; \
		fi								; \
	fi

