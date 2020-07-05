
TARGETS			 = sudo-auth sudo-modify-exports modify-exports sudo-enable-nfs-through-firewall
TARGETS_OPTIMISTIC	 = modify-exports sudo-auth sudo-modify-exports

SUDO_CHECK		:= $(shell sudo id -n -u)
SUDO_NEED		 = root

FLAG_D			 = ../../clusters/common/flag
NO_NFS_FLAG		 = $(FLAG_D)/NFS_NOTAUTH

EXPORTS_UNPRIV		 = $(shell touch $(ETC_EXPORTS) 2>&1)

ETC_EXPORTS	 	 = /etc/exports

.PHONY: $(TARGETS)

all: $(TARGETS)

modify-exports:
ifneq ($(EXPORTS_UNPRIV),"") 
  $(warning Unprivileged access failed, will try using sudo)
endif

sudo-auth: sudo-modify-exports
ifneq ($(SUDO_CHECK), $(SUDO_NEED))
  $(warning Insufficient authorization for NFS: $(SUDO_CHECK) != $(SUDO_NEED))
endif

sudo-modify-exports:
	sudo touch $(ETC_EXPORTS)	; \
	rc=$$?				; \
	if [ $${rc} -ne 0 ] ; then	  \
		touch $(NO_NFS_FLAG)	; \
	fi

sudo-enable-nfs-through-firewall:
	sudo firewall-cmd --zone=trusted --add-interface=vboxnet0
	sudo firewall-cmd --zone=trusted --add-service=nfs
