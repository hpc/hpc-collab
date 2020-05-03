ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)
	$(HUSH)env VC=$(VC) $(SAVE_LOGSDB)

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

