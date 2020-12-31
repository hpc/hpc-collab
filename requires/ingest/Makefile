

VBOX_VERSION	:= $(shell cat ../../clusters/vc/common/provision/config/vboxadd/version)

VBOX_ISO	 = VBoxGuestAdditions_$(VBOX_VERSION).iso
VBOX_ISO_URL	 = https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/



COMMUNITY_MYSQL_URL		= https://dev.mysql.com/get/
COMMUNITY_MYSQL_PRIMER_RPM	= mysql80-community-release-el7-3.noarch.rpm
COMMUNITY_MYSQL_RPMS		= 					\
	mysql-community-client-8.0.21-1.el7.x86_64.rpm			\
	mysql-community-common-8.0.21-1.el7.x86_64.rpm			\
	mysql-community-devel-8.0.21-1.el7.x86_64.rpm			\
	mysql-community-libs-8.0.21-1.el7.x86_64.rpm			\
	mysql-community-libs-compat-8.0.21-1.el7.x86_64.rpm		\
	mysql-community-server-8.0.21-1.el7.x86_64.rpm			\
	mysql-connector-python-2.0.4-1.el7.noarch.rpm			\
	mysql-connector-python-8.0.21-1.el7.x86_64.rpm			\
	mysql-connector-python-cext-8.0.21-1.el7.x86_64.rpm		\
	mysql-ref-manual-8.0-en-html-chapter-1-20200617.noarch.rpm	\
	mysql-ref-manual-8.0-en-pdf-1-20200617.noarch.rpm		\
	mysql-shell-8.0.21-1.el7.x86_64.rpm				\
	mysql-utilities-1.6.5-1.el7.noarch.rpm

COMMUNITY_MYSQL_GPGKEY_URL	= https://repo.mysql.com/
COMMUNITY_MYSQL_GPGKEY		= RPM-GPG-KEY-mysql

MARIADB_REPO_SETUP_URL		= https://downloads.mariadb.com/MariaDB/
MARIADB_REPO_SETUP		= mariadb_repo_setup

MARIADB_GPGKEY_URL		= https://yum.mariadb.org/
MARIADB_GPGKEY			= RPM-GPG-KEY-mariaDB

MARIADB_ES_REPO_SETUP_URL	= https://dlm.mariadb.com/enterprise-release-helpers/
MARIADB_ES_REPO_SETUP		= mariadb_es_repo_setup

MARIADB_ES_GPGKEY_URL		= https://downloads.mariadb.com/MariaDB/
MARIADB_ES_GPGKEY		= MariaDB-Enterprise-GPG-KEY

WHICH_DB		= $(shell cat ../../clusters/common/flag/WHICH_DB)
previous_which_db	= $(shell [ -s $(TARBALL_D)/WHICH_DB/which_db ] && \
			  		cat $(TARBALL_D)/WHICH_DB/which_db || \
				echo "")

repo_tgz		= repos.tgz
repo_cksum	= repos.cksum

SCHEDMD_SLURM_URL = https://download.schedmd.com/slurm/
SLURM_VERSION	 	 := $(shell cat ../../clusters/vc/cfg/vcbuild/build/slurm/version)
SLURM_TARBALL			= slurm-$(SLURM_VERSION).tar.bz2

TARBALL_D	 = ../../tarballs
TARBALL_D	:= $(realpath $(TARBALL_D))

TARGETS_BASE	 = $(TARBALL_D)/$(repo_cksum) $(TARBALL_D)/$(repo_tgz)		\
		   $(TARBALL_D)/$(VBOX_ISO)					\
		   $(TARBALL_D)/$(SLURM_TARBALL)				\

TARGETS_FINAL	 =								\
		   $(TARBALL_D)/WHICH_DB					\
		   $(TARBALL_D)/WHICH_DB/url $(TARBALL_D)/WHICH_DB/repo_setup	\
		   $(TARBALL_D)/WHICH_DB/which_db


# Which DB? 
# if presently flagged option (WHICH_DB), differs from previously configured option, previous_which_db
# include a target to remove the previous settings
ifeq ($(previous_which_db),$(WHICH_DB))
	x	:= $(shell rm -rf $(TARBALL_D)/WHICH_DB)
endif

# default to mariadb-community
ifeq ($(WHICH_DB),)
	WHICH_DB = mariadb-community
endif	

#   MariaDB Enterprise version
#     -- requires download token obtained from them
ifeq ($(WHICH_DB),enterprise-mariadb)
	WHICH_DB = mariadb-enterprise
endif
ifeq ($(WHICH_DB),mariadb-enterprise)
	GPGKEY					:= $(MARIADB_ES_GPGKEY)
	DOWNLOAD_GPGKEY	 = $(TARBALL_D)/$(WHICH_DB)/$(MARIADB_ES_GPGKEY)
	DOWNLOAD_RPMS		 =
	DOWNLOAD_SETUP	 = $(TARBALL_D)/$(WHICH_DB)/$(MARIADB_ES_REPO_SETUP)
	DOWNLOAD_TOKEN	 = $(TARBALL_D)/$(WHICH_DB)/download_token
	GPGKEY_URL			:= $(MARIADB_ES_GPGKEY_URL)/
	URL							:= $(MARIADB_ES_REPO_SETUP_URL)
	SETUP						:= $(MARIADB_ES_REPO_SETUP)
	TARGETS_DOWNLOAD =  $(DOWNLOAD_TOKEN) $(DOWNLOAD_SETUP)
endif

ifeq ($(WHICH_DB),community-mariadb)
	WHICH_DB = mariadb-community
endif
ifeq ($(WHICH_DB),mariadb)
	WHICH_DB = mariadb-community
endif
ifeq ($(WHICH_DB),mariadb-community)
	GPGKEY			:= $(MARIADB_GPGKEY)
	DOWNLOAD_GPGKEY		= $(TARBALL_D)/$(WHICH_DB)/$(MARIADB_GPGKEY)
	DOWNLOAD_RPMS 		=
	DOWNLOAD_SETUP		= $(TARBALL_D)/$(WHICH_DB)/$(MARIADB_REPO_SETUP)
	DOWNLOAD_TOKEN		=
	GPGKEY_URL 		 		= $(MARIADB_GPGKEY_URL)
	URL	    	   	 	 := $(MARIADB_REPO_SETUP_URL)
	SETUP					 	 := $(MARIADB_REPO_SETUP)
	TARGETS_DOWNLOAD	=  $(DOWNLOAD_SETUP)
endif

ifeq ($(WHICH_DB),mysql)
	WHICH_DB = community-mysql
endif
ifeq ($(WHICH_DB),mysql-community)
	WHICH_DB = community-mysql
endif
ifeq ($(WHICH_DB),community-mysql)
	GPGKEY					:= $(COMMUNITY_MYSQL_GPGKEY)
	DOWNLOAD_GPGKEY	 = $(TARBALL_D)/$(WHICH_DB)/$(COMMUNITY_MYSQL_GPGKEY)
	DOWNLOAD_RPMS		 = $(foreach f,$(COMMUNITY_MYSQL_RPMS), $(TARBALL_D)/$(WHICH_DB)/RPMS/$(f))
	DOWNLOAD_SETUP	 =
	DOWNLOAD_TOKEN	 =
	GPGKEY_URL 			 = $(COMMUNITY_MYSQL_GPGKEY_URL)
	URL							:= $(COMMUNITY_MYSQL_URL)
	SETUP						:= $(COMMUNITY_MYSQL_PRIMER_RPM)
	TARGETS_DOWNLOAD = $(DOWNLOAD_GPGKEY) $(DOWNLOAD_RPMS)
endif

TARGETS	:= $(TARGETS_BASE) $(TARGETS_DOWNLOAD) $(TARGETS_FINAL)

DEFAULT_PREFERRED_REPO_URL = $(shell tail -1 $(CURDIR)/repos)
PREFERRED_REPO_URL				 = $(shell echo $${PREFERRED_REPO_URL})

ifeq (,$(PREFERRED_REPO_URL),)
$(error PREFERRED_REPO_URL is unset (""))
endif

#if the PREFERRED_REPO_URL contains rsync://, use it, otherwise use default
ifeq (,$(findstring rsync://,$(PREFERRED_REPO_URL)))
	REPO_URL	 				= $(DEFAULT_PREFERRED_REPO_URL)
else
	REPO_URL	 				= $(PREFERRED_REPO_URL)
endif


REPO_PREFIX	 			= centos/7
REPO_WORKSPACE_D	= $(TARBALL_D)/repos
REPO_OS		 				= $(REPO_WORKSPACE_D)/centos/7/os/.target
REPO_UPDATES	 		= $(REPO_WORKSPACE_D)/centos/7/updates/.target
REPO_HTTP_URL	 		= $(subst rsync,http,$(REPO_URL))
REPO_HOST	 				= $(dir $(subst rsync://,,$(REPO_URL)))


all: $(TARGETS)

$(REPO_WORKSPACE_D): $(REPO_OS) $(REPO_UPDATES)
	@if [ ! -d "$@" ] ; then    \
		mkdir -p $@     ; \
	fi

# could be a bit more intelligent about manipulating the pattern to generate the rsync
# and incorporate an estimated space check
# depending upon where people are located on the network, outbound pings may be blocked.
# Don't consider this fatal; it merely indicates checklist-security compliance.
$(REPO_OS) $(REPO_UPDATES):
	ping -c 1 -n -w 1 $(REPO_HOST) 			            ; \
	rc=$$?                                                          ; \
	if [ "$${rc}" -ne 0 ] ; then                                      \
		echo Warning: cannot ping repository $(REPO_HOST)       			; \
	fi
	rm -f $(TARBALL_D)/REPO_URL
	declare -x BEHIND_PROXY                                         ; \
	BEHIND_PROXY=$$(env | grep proxy)                               ; \
	declare -x RSYNC_PROXY                                          ; \
	RSYNC_PROXY=$$(echo $$http_proxy | sed 's/http:\/\///')         ; \
	mkdir -p $(@D)                                                  ; \
	rsync --dry-run  -4 -avz --delete --exclude=\*i686\.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D) ; \
	rc=$$?								; \
	if [ "$${rc}" -ne 0 ] ; then                                        \
		echo "Try: "                                            ; \
		echo "  export RSYNC_PROXY=$${RSYNC_PROXY}"             ; \
		echo "  rsync -4 -avz --delete --exclude=\*i686\.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D)"  ; \
		echo " "                                                                                ; \
		echo Cannot ingest: $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ to $(@D)            ; \
		echo Please download repository copy from, for example,                                 ; \
		echo "          $(REPO_HTTP_URL)"                                                       ; \
		echo "  to      $(@D) $(realpath $(@D))"                                                ; \
		exit 99                                                                                 ; \
	fi
	rsync -4 -avz --delete --exclude=*i686.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D)
	echo $(REPO_URL) > $(TARBALL_D)/REPO_URL
	touch $@

# use this to pull a repo and roll a tarball
$(TARBALL_D)/$(repo_tgz): $(REPO_WORKSPACE_D) $(REPO_OS) $(REPO_UPDATES)
	tar --exclude=.target -czvf $(TARBALL_D)/repos.tgz -C $(TARBALL_D) repos

$(TARBALL_D)/$(repo_cksum): $(TARBALL_D)/$(repo_tgz)
	cksum $^ > $@

$(TARBALL_D)/$(SLURM_TARBALL):
	wget -4 -P $(@D) $(SCHEDMD_SLURM_URL)/$(SLURM_TARBALL)

# set http_proxy or https_proxy if need be
$(TARBALL_D)/$(VBOX_ISO):
	wget -4 -P $(@D) $(VBOX_ISO_URL)/$(VBOX_ISO)


# DB selection & ingestion

# community mysql doesn't use a repo_setup script; it has a primer RPM
$(TARBALL_D)/community-mysql/RPMS/$(COMMUNITY_MYSQL_PRIMER_RPM): $(TARBALL_D)/community-mysql $(TARBALL_D)/community-mysql/RPMS
	if [ ! -f $@ ] ; then			  \
		wget -4 -P $(@D) $(URL)/$(@F)	; \
	fi

$(foreach f,$(COMMUNITY_MYSQL_RPMS),$(TARBALL_D)/community-mysql/RPMS/$(f)): $(TARBALL_D)/community-mysql/RPMS/$(COMMUNITY_MYSQL_PRIMER_RPM)
	if [ ! -f $@ ] ; then			  \
		wget -4 -P $(@D) $(URL)/$(@F)	; \
	fi

# some db require a download token
$(DOWNLOAD_SETUP): $(DOWNLOAD_TOKEN)
	if [ ! -f $@ ] ; then			  \
		wget -4 -P $(@D) $(URL)$(@F)	; \
	fi

$(DOWNLOAD_GPGKEY): $(DOWNLOAD_TOKEN)
	if [ ! -f $@ ] ; then			      \
		wget -4 -P $(@D) $(GPGKEY_URL)$(@F) ; \
	fi

$(DOWNLOAD_TOKEN):
	$(info )
	$(info The mariadb data base vendor, mariadb.com, requires registration to obtain a download token.)
	$(info To obtain a download token: https://mariadb.com/docs/deploy/token/)
	$(info Emplace the token into $@)
	$(info Alternatively, use a data base configuration of "mariadb-community" or "community-mysql")
	$(info )
	$(error )

$(TARBALL_D)/WHICH_DB $(TARBALL_D)/$(WHICH_DB) $(TARBALL_D)/community-mysql/RPMS:
	mkdir -p $@

# These are dependent upon TARGETS_DOWNLOAD so they are not set until after the download.
# These WHICH_DB/... are breadcrumbs for the in-cluster provisioners.
$(TARBALL_D)/WHICH_DB/which_db: $(TARBALL_D)/WHICH_DB $(TARGETS_DOWNLOAD)
	 echo $(WHICH_DB) > $@

$(TARBALL_D)/WHICH_DB/repo_setup: $(TARBALL_D)/WHICH_DB/which_db $(TARGETS_DOWNLOAD)
	 echo $(SETUP) > $@

$(TARBALL_D)/WHICH_DB/url: $(TARBALL_D)/WHICH_DB/which_db $(TARGETS_DOWNLOAD)
	 echo $(URL) > $@




clean:
	rm -fr $(TARBALL_D)/WHICH_DB

force: clean
	rm -f $(REPO_OS) $(REPO_UPDATES)


dist-clean: clean
	rm -fr $(TARBALL_D)/$(WHICH_DB)


# vim: background=dark ts=2 sw=2 syntax
