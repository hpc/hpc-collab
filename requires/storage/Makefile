#!/usr/bin/make

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

## @todo if CentOS vs Ubuntu, etc:

SUBDIRS_WITH_NEED_SPACE	= $(wildcard */need_space)
SUBDIRS			= $(dir $(SUBDIRS_WITH_NEED_SPACE))

IAM			= $(notdir ${CURDIR})
TSTAMP	       	       := $(shell date +%y%m%d.%H%M)

.PHONY: all $(SUBDIRS)

all: $(SUBDIRS)

$(SUBDIRS):
	$(HUSH)$(MAKE) -C $@

