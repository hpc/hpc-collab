# vx.mk

# ### ### ###
### ### ### ###
# vx-specific cluster config
### ### ### ###

# used to search for sources for tarballs, etc
PREREQ_VC_D	= ../vc
ALTERNATE_VC_D	= $(PREREQ_VC_D)~

PREREQ_COMMON		= $(PREREQ_VC_D)/common
PREREQ_COMMONETC	= $(PREREQ_COMMON)/etc
PREREQ_HOSTS		= $(PREREQ_COMMONETC)/hosts

COMMON			= common
COMMON_ETC		= $(COMMON)/etc
HOSTS			= $(COMMON_ETC)/hosts

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)

# @todo programmatical determine that vcdb is the data base host, perhaps DBDPORT config in firewall?
# ls all requires/* nodes, find those which end in "db", pick one
# if it isn't in this cluster, issue 'delete cluster' command
#
# at present the following assumes that /etc/hosts has target cluster nodes set up
#
# @todo XXX tear down the cluster data base in our required external db cluster when we are unprovisioned
#
#

# vx depends on its conjoined cluster vc for /etc/hosts, so IP addresses in Vagrantfile and elsewhere
$(HOSTS): $(PREREQ_HOSTS)
	$(HUSH)rsync -LHcau $< $@
	$(HUSH)env VC=$(IAM) MODE="host" ../common/bin/generateproviderfiles.sh
	$(HUSH)env VC=$(IAM) MODE="host" ../common/bin/compilevagrantfile.sh

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

### ### ### ###

# vim: background=dark

