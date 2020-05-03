

:::NODE:::!: verifylocalenv $(NONEXISTENT_D)/:::NODE::: $(PROVISIONED_D)/:::NODE:::

:::NODE:::--: :::NODE:::_UNPROVISION

:::NODE:::-: verifylocalenv $(POWEROFF_D)/:::NODE:::

:::NODE:::+: verifylocalenv $(RUNNING_D)/:::NODE:::

:::NODE:::: verifylocalenv $(PROVISIONED_D)/:::NODE:::

$(RUNNING_D)/:::NODE:::: $(XFR_PREREQ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/:::NODE:::/requires/*)))
	$(HUSH)if [ -f $(PROVISIONED_D)/:::NODE::: ] ; then				   \
	  vagrant up --no-provision :::NODE::: || exit 1				 ; \
										   \
	elif [ -f $(POWEROFF_D)/:::NODE::: ] ; then					   \
	  vagrant up --no-provision :::NODE::: || exit 2				 ; \
										   \
	elif [ ! -f $(PROVISIONED_D)/:::NODE::: -a ! -f $(NONEXISTENT_D)/:::NODE::: ] ; then   \
	    vagrant destroy -f :::NODE::: || exit 3					 ; \
	fi

$(PROVISIONED_D)/:::NODE:::: $(XFR_PREREQ) ingest-state $(addprefix $(PROVISIONED_D)/, $(notdir $(wildcard $(CFG)/:::NODE:::/requires/*)))
	$(HUSH)for prereq in $^							; \
        do									  \
	  if [[ "$(PHONY)" =~ $${prereq} ]] ; then				  \
	    continue								; \
	  fi									; \
	  if [ ! -f "$${prereq}" ] ; then					  \
	    echo prerequisite: $${prereq} missing				; \
	    exit 4								; \
	  fi									; \
	done									; \
	if [ -f "$(RUNNING_D)/:::NODE:::" -a ! -f "$(PROVISIONED_D)/:::NODE:::" ] ; then	  \
	  vagrant destroy -f :::NODE::: || exit 5					; \
	fi									; \
	if [ ! -f "$(PROVISIONED_D)/:::NODE:::" ] ; then				  \
	  vagrant up --provision :::NODE::: || exit 6					; \
	  $(MARK_PROVISIONED)							; \
	fi

$(POWEROFF_D)/:::NODE:::: 
	$(HUSH)vagrant halt :::NODE:::

$(NONEXISTENT_D)/:::NODE:::: $(POWEROFF_D)/:::NODE:::
	$(HUSH)vagrant destroy -f :::NODE:::

# unprovision may be necessary even if provisioning failed, leaving node in RUNNING state
:::NODE:::_UNPROVISION: $(NONEXISTENT_D)/:::NODE::: ingest-state
	$(HUSH)$(UNPROVISION) :::NODE:::

