# contains cluster-specific make rules
# for example, since vc provides home dir storage for itself and vx, add SAVELOGS and SYNCHOME rule
ALTERNATE_VC_D	= ../vc~

$(SAVELOGS_TARGETS): $(wildcard $(PROVISIONED_D)/*)
	$(HUSH)env VC=$(VC) $(SAVE_LOGSDB)

$(SYNCHOME_TARGETS):
	-$(HUSH)ping -c 1 -w 1 -n -q $(VC)fs >/dev/null 2>&1	; \
	rc=$$?							; \
	if [ $${rc} -eq 0 ] ; then				  \
		if [ -f $(PROVISIONED_D)/$(VC)fs ] ; then	  \
			env VC=$(VC) $(SYNC_HOME)		; \
		fi						; \
	fi

$(COMMON_ETC_HOSTS):
	cd $(CLUSTERS_DIR)/$(VC) ; env VC=$(VC) MODE="host" $(GENERATE_PROVIDER_FILES)

$(STATE_DIRS_ALL):
	$(HUSH)mkdir -p $@

