#!/usr/bin/make

ifneq (,$(findstring "--quiet",$(MAKEFLAGS)))
  HUSH ?= @
endif

define add
	$(shell expr $$1 + $$2)
endef

## @todo if CentOS vs Ubuntu, etc:

CLUSTERS_D		= ../../clusters
CLUSTERS_RAM		= $(notdir $(wildcard $(CLUSTERS_D)/*/cfg/*/attributes/memory/*))

IAM			= $(notdir ${CURDIR})
TSTAMP	       	       := $(shell date +%y%m%d.%H%M)

.PHONY: all checkram

all:  checkram

## @todo push this into Makefile directly
checkram:
	needed=$$(cum=0; for x in $(CLUSTERS_RAM); do cum=$$(expr $${cum} + $$x); done; echo $$cum)	; \
	have=$$(expr $$(grep MemAvailable /proc/meminfo | awk '{print $$2}') / 1024)			; \
	if [ $${needed} -gt $${have} ] ; then								  \
		echo "Need: $${needed} RAM, Available: $${have}"					; \
		echo "	Reduce the values in cluster recipe node attributes, if possible"		; \
		echo "	"$(CLUSTERS_D)/*/cfg/*/attributes/memory/*					; \
		exit 99											; \
	fi
	exit 0
