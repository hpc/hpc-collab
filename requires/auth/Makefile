
TARGETS			 = sudo-auth sudo-modify-exports modify-exports
TARGETS_OPTIMISTIC	 = modify-exports sudo-auth sudo-modify-exports

SUDO_CHECK		:= $(shell sudo id -n -u)
SUDO_NEED		 = root

EXPORTS_UNPRIV		 = $(shell touch $(ETC_EXPORTS) 2>&1)

ETC_EXPORTS	 	 = /etc/exports

.PHONY: $(TARGETS)

all: $(TARGETS)

modify-exports:
ifneq ($(EXPORTS_UNPRIV),"") 
  $(warning Unprivileged access failed, will try using sudo)
endif

sudo-auth:
ifneq ($(SUDO_CHECK), $(SUDO_NEED))
  $(error insufficient authorization: $(SUDO_CHECK) != $(SUDO_NEED))
endif

sudo-modify-exports:
	sudo touch $(ETC_EXPORTS)

