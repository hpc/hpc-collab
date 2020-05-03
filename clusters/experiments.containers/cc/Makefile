

VIRTUALCLUSTER = cc
CFG	       = $(VIRTUALCLUSTER)/cfg
NODES  	       = $(filter-out provision, $(notdir $(wildcard $(CFG)/*)))
TSTAMP	      := $(shell date +%y%m%d.%H%M)
OS	       = $(shell uname -s)
PWD	       = $(shell pwd)
export PATH   := $(shell echo $${PATH}):$(PWD)/cfg/provision/bin

all: $(NODES)
	@cd ..; make -s -f Makefile --no-print-directory

$(foreach n,$(NODES),$(n)-) $(foreach n,$(NODES),$(n)--):
	@cd ..; make -s -f Makefile --no-print-directory \!*

