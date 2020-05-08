# vx.mk

# ### ### ###
### ### ### ###
# vx-specific cluster config
### ### ### ###

# used to search for sources for tarballs, etc
ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)

# @todo programmatical determine that vcdb is the data base host, perhaps DBDPORT config in firewall?
# ls all requires/* nodes, find those which end in "db", pick one
# if it isn't in this cluster, issue 'delete cluster' command
#
# at present the following assumes that /etc/hosts has target cluster nodes set up
#
# @todo XXX tear down the cluster data base in our required external db cluster when we are unprovisioned


$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

### ### ### ###
