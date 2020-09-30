# contains cluster-specific make rules
# for example, since vc provides home dir storage for itself and vx, add SAVELOGS and SYNCHOME rule
ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)
	$(HUSH)env VC=$(VC) $(SAVE_LOGSDB)

$(SYNCHOME_TARGETS): $(PROVISIONED_D)/$(VC)fs
	$(HUSH)env VC=$(VC) $(SYNC_HOME)

$(COMMON_ETC_HOSTS):
	cd $(CLUSTERS_DIR)/$(VC) ; env VC=$(VC) $(GENERATE_PROVIDER_FILES)

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

