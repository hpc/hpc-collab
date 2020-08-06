ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)
	$(HUSH)env VC=$(VC) $(SAVE_LOGSDB)

common/etc/hosts:
	cd $(CLUSTERS_DIR)/$(VC) ; env VC=$(VC) $(GENERATE_PROVIDER_FILES)

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

