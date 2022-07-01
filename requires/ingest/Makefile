#!/usr/bin/make


VBOX_INGEST_D			= ../../requires/ingest/vbox
VBOX_SW_D					= ../../requires/sw/vbox

VBOX_VERSION_SW	 := $(shell cat $(VBOX_SW_D)/version)
VBOX_VERSION_ISO := $(VBOX_VERSION_SW)
VBOX_VERSION_RPM := $(shell echo $(VBOX_VERSION_SW) | cut -d '.' -f 1,2)
#VBOX_VERSION		 := $(shell cat ../../clusters/vc/common/provision/config/vboxadd/version)
#VBOX_VERSION		 := $(shell cat clusters/vc/common/provision/config/vboxadd/version)
VBOX_VERSION			= $(VBOX_VERSION_SW)

VBOX_GPGKEY_FILE		= oracle_vbox.asc
VBOX_GPGKEY_URL			= $(VBOX_HOST_URL)/$(VBOX_GPGKEY_FILE)
VBOX_INGEST_GPGKEY	= $(VBOX_INGEST_D)/$(VBOX_GPGKEY_FILE)
VBOX_GPGKEY					= $(VBOX_INGEST_GPGKEY)

VBOX_HOST_URL			=	https://download.virtualbox.org
VBOX_ISO					= VBoxGuestAdditions_$(VBOX_VERSION_ISO).iso
VBOX_ISO_URL			= $(VBOX_HOST_URL)/virtualbox/$(VBOX_VERSION_ISO)
VBOX_LONGNAME			=	$(shell cat $(VBOX_INGEST_D)/longname)
VBOX_RPM_PREREQ		= $(shell cd $(VBOX_INGEST_D)/prereq; echo *)
VBOX_RPM					= $(VBOX_LONGNAME)-$(VBOX_VERSION_RPM)

YUM_REPO_D				 = /etc/yum.repos.d
VBOX_REPO_F				 = vbox.repo
VBOX_INGEST_REPO_F = $(VBOX_INGEST_D)/$(VBOX_REPO_F)
VBOX_YUM_REPO_F		 = $(YUM_REPO_D)/$(VBOX_REPO_F)

VBOX_IS_INSTALLED					 := $(shell rpm -q $(VBOX_RPM))
VBOX_INSTALLED_FLAG					= VBOX_WHICH_RPM
TARBALL_VBOX_INSTALLED_FLAG = $(TARBALL_D)/$(VBOX_INSTALLED_FLAG)

ifeq ($(VBOX_IS_INSTALLED),'package $(VBOX_RPM) is not installed')
	rm -f $(TARBALL_VBOX_INSTALLED_FLAG)
endif

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
TMP_REPO_TGZ	= /tmp/$(repo_tgz)

SCHEDMD_SLURM_URL = https://download.schedmd.com/slurm/
SLURM_VERSION	 	 := $(shell cat ../../clusters/vc/cfg/slurm_version)
SLURM_TARBALL			= slurm-$(SLURM_VERSION).tar.bz2

TARBALL_D	 = ../../tarballs
TARBALL_D	:= $(realpath $(TARBALL_D))

VAGRANT_VERSION				 := $(shell cat ../sw/vagrant/version)
VAGRANT_WHICH_RPM				= vagrant_$(VAGRANT_VERSION)_x86_64.rpm
VAGRANT_URL							= https://releases.hashicorp.com/vagrant/$(VAGRANT_VERSION)/$(VAGRANT_WHICH_RPM)
VAGRANT_IS_INSTALLED	 := $(shell rpm -q vagrant)
VAGRANT_INSTALLED_FLAG	= VAGRANT_WHICH_RPM
TARBALL_VAGRANT_INSTALLED_FLAG = $(TARBALL_D)/$(VAGRANT_INSTALLED_FLAG)
ifeq ($(VAGRANT_IS_INSTALLED),'package vagrant is not installed')
	rm -f $(TARBALL_VAGRANT_INSTALLED_FLAG)
endif

TARGETS_BASE	 = \
		   $(TARBALL_VAGRANT_INSTALLED_FLAG)	\
		   $(TARBALL_D)/$(VBOX_ISO)					\
		   $(TARBALL_D)/$(SLURM_TARBALL)				\
		   $(TARBALL_D)/$(repo_cksum) $(TARBALL_D)/$(repo_tgz)		\
		   $(VBOX_INGEST_GPGKEY) $(VBOX_INGEST_REPO_F) $(VBOX_YUM_REPO_F)	\
		   $(TARBALL_VBOX_INSTALLED_FLAG)


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

# XXX http: or rsync:
REPO_HOST	 				= $(dir $(subst http://,,$(REPO_URL)))


all: $(TARGETS)

$(REPO_WORKSPACE_D): $(REPO_OS) $(REPO_UPDATES)
	@if [ ! -d "$@" ] ; then    \
		mkdir -p $@     ; \
	fi

# could be a bit more intelligent about manipulating the pattern to generate the rsync
# and incorporate an estimated space check
# depending upon where people are located on the network, outbound pings may be blocked.
# Don't consider this fatal; it merely indicates checklist-security compliance.
#
# The purpose of aligning the ; is to detect when there's one missing. In particular, the
# DOWNLOAD_URL env variable needs to be in the env for much of what follows.
#
# XXX http:// OR rsync://
$(REPO_OS) $(REPO_UPDATES):
	declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
	declare -x https_proxy=$${http_proxy}																															; \
	declare -x proxy=$${http_proxy}																																		; \
	declare -x REPO_HOST=$(subst http://,,$(REPO_URL))																								; \
	ping -c 1 -n -w 1 $${REPO_HOST}  >/dev/null 2>&1		      			   															  ; \
	rc=$$?                                                      			  															; \
	if [ "$${rc}" -ne 0 ] ; then                                 																 		   \
		echo Warning: cannot ping repository $${REPO_HOST}       																				; \
	fi																																																; \
	rm -f $(TARBALL_D)/REPO_URL																																				; \
	declare -x BEHIND_PROXY                                   			 		 						 									; \
	BEHIND_PROXY=$$(env | grep proxy)                            															 				; \
	declare -x RSYNC_PROXY                                        																	  ; \
	RSYNC_PROXY=$$(echo $$http_proxy | sed 's/http:\/\///')     			 														 		; \
  declare -x DOWNLOAD_URL=$(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/														; \
	if [[ "$(REPO_URL)" = *"rsync:"* ]] ; then																												  \
		rsync --dry-run  -4 -avz --delete --exclude=\*i686\.rpm $${DOWNLOAD_URL} $(@D)									; \
		rc=$$?																																													; \
	elif [[ "$(REPO_URL)" = *"http:"* ]] ; then																												  \
		declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
		declare -x https_proxy=$${http_proxy}																															; \
		declare -x proxy=$${http_proxy}																																		; \
		wget --spider --timeout=5 --tries=2 -e robots=off --inet4-only $(REPO_URL)/index.html						; \
		rc=$$?																																													; \
	else																																															  \
		echo " Which handler for url? $${DOWNLOAD_URL}"																									; \
		rc=1																																														; \
	fi																																														 		; \
	if [ "$${rc}" -ne 0 ] ; then                               															   			    \
		echo "Try: "                                        			 																	    ; \
		echo "  export RSYNC_PROXY=$${RSYNC_PROXY}"        			  																	    ; \
		echo "  export http_proxy=$${http_proxy}"         																			 				; \
		echo "  export proxy=$${proxy}"          																										    ; \
		echo "  rsync -4 -avz --delete --exclude=\*i686\.rpm $${DOWNLOAD_URL} $(@D)"  									; \
		echo "	or:"																																										; \
		echo "  wget --timestamping --timeout=30 --no-parent --mirror --reject "*i686.rpm,*.torrent,index.html*" -e robots=off --random-wait --inet4-only --recursive --directory-prefix=$(TARBALL_D)  $${DOWNLOAD_URL}"	 	 ; \
		echo " "                                             																						; \
		echo Cannot ingest: $${DOWNLOAD_URL} to $(@D)          																					; \
		echo Please download repository copy from, for example, 																				; \
		echo "          $(REPO_HTTP_URL)"                       																				; \
		echo "  to      $(@D) $(realpath $(@D))"               			 																		; \
		exit 99                                               																 		 			; \
	fi																																																; \
	if [[ "$(REPO_URL)" = "rsync:"* ]] ; then																													  \
		mkdir -p $(@D)                                               																 		; \
		rsync -4 -avz --delete --exclude=*i686.rpm $${DOWNLOAD_URL} $(@D)																;	\
		rc=$$?																																													; \
	elif [[ "$(REPO_URL)" = "http:"* ]] ; then																													\
		wget --timestamping --timeout=30 --no-parent --mirror --reject "*i686.rpm,*.torrent,index.html*" -e robots=off --random-wait --inet4-only --recursive --directory-prefix=$(TARBALL_D)	$${DOWNLOAD_URL}							 ; \
		rc=$$?																																													; \
		rm -f $(REPO_WORKSPACE_D)																																				; \
		ln -s $${REPO_HOST} $(REPO_WORKSPACE_D)																													; \
	fi																																																; \
  if [ "$${rc}" -ne 0 ] ; then																																				\
		echo "Remote repository: $(REPO_URL) inaccessible? "																						; \
		echo "Try setting a different repository (the final line) in $(CURDIR)/repos"										; \
		exit 99																																													; \
	fi
	# Record which one we actually used
	echo $(REPO_URL) > $(TARBALL_D)/REPO_URL
	touch $@

# use this to pull a repo and roll a tarball
$(TARBALL_D)/$(repo_tgz): $(REPO_WORKSPACE_D) $(REPO_OS) $(REPO_UPDATES)
	tar --exclude=.target -chzvf $(TMP_REPO_TGZ) -C $(TARBALL_D) `readlink repos` .
	mv $(TMP_REPO_TGZ) $(TARBALL_D)/$(repo_tgz)

$(TARBALL_D)/$(repo_cksum): $(TARBALL_D)/$(repo_tgz)
	cksum $^ > $@

$(TARBALL_D)/$(SLURM_TARBALL):
	declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
	declare -x https_proxy=$${http_proxy}																															; \
	declare -x proxy=$${http_proxy}																																		; \
	wget --timeout=60 -4 -P $(@D) $(SCHEDMD_SLURM_URL)/$(SLURM_TARBALL)

$(TARBALL_VAGRANT_INSTALLED_FLAG): $(TARBALL_D)/$(VAGRANT_WHICH_RPM)
	sudo yum -y localinstall $<
	echo $(VAGRANT_WHICH_RPM) > $@

$(TARBALL_D)/$(VAGRANT_WHICH_RPM):
	declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
	declare -x https_proxy=$${http_proxy}																															; \
	declare -x proxy=$${http_proxy}																																		; \
	wget --timeout=60 -4 -P $(@D) $(VAGRANT_URL) || rm -f $@

# set http_proxy or https_proxy if need be
$(TARBALL_D)/$(VBOX_ISO):
	declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
	declare -x https_proxy=$${http_proxy}																															; \
	declare -x proxy=$${http_proxy}																																		; \
	wget --timeout=60 -4 -P $(@D) $(VBOX_ISO_URL)/$(VBOX_ISO)

$(VBOX_INGEST_GPGKEY):
	declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
	declare -x https_proxy=$${http_proxy}																															; \
	declare -x proxy=$${http_proxy}																																		; \
	wget --timeout=15 -4 -O$@ $(VBOX_GPGKEY_URL)

$(VBOX_YUM_REPO_F): $(VBOX_INGEST_GPGKEY) $(VBOX_INGEST_REPO_F)
	sudo rpm --import - < $<
	sudo cp $(VBOX_INGEST_REPO_F) $@

$(TARBALL_VBOX_INSTALLED_FLAG): $(VBOX_YUM_REPO_F)
	sudo yum -y install $(VBOX_RPM_PREREQ)
	sudo yum -y install $(VBOX_RPM)
	echo $(VBOX_RPM) > $@

# DB selection & ingestion

# community mysql doesn't use a repo_setup script; it has a primer RPM
$(TARBALL_D)/community-mysql/RPMS/$(COMMUNITY_MYSQL_PRIMER_RPM): $(TARBALL_D)/community-mysql $(TARBALL_D)/community-mysql/RPMS
	if [ ! -f $@ ] ; then			  \
		declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
		declare -x https_proxy=$${http_proxy}																															; \
		declare -x proxy=$${http_proxy}																																		; \
		wget --timeout=1800 -4 -P $(@D) $(URL)/$(@F)	; \
	fi

$(foreach f,$(COMMUNITY_MYSQL_RPMS),$(TARBALL_D)/community-mysql/RPMS/$(f)): $(TARBALL_D)/community-mysql/RPMS/$(COMMUNITY_MYSQL_PRIMER_RPM)
	if [ ! -f $@ ] ; then			  \
		declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
		declare -x https_proxy=$${http_proxy}																															; \
		declare -x proxy=$${http_proxy}																																		; \
		wget --timeout=300 -4 -P $(@D) $(URL)/$(@F)	; \
	fi

# some db require a download token
$(DOWNLOAD_SETUP): $(DOWNLOAD_TOKEN)
	if [ ! -f $@ ] ; then			  \
		declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
		declare -x https_proxy=$${http_proxy}																															; \
		declare -x proxy=$${http_proxy}																																		; \
		wget --timeout=10 --tries=2 -4 -P $(@D) $(URL)$(@F)	; \
		rc=$$?																							; \
	fi																										;	\
	if [ "$${rc}" -ne 0 ] ; then														\
		echo "Couldn't retrieve $(URL)$(@F)"								; \
		echo " http_proxy: $${http_proxy}"									; \
		echo " https_proxy: $${https_proxy}"								; \
		exit 1																							; \
	fi

$(DOWNLOAD_GPGKEY): $(DOWNLOAD_TOKEN)
	if [ ! -f $@ ] ; then			      \
		declare -x http_proxy=http://proxyout.lanl.gov:8080																								; \
		declare -x https_proxy=$${http_proxy}																															; \
		declare -x proxy=$${http_proxy}																																		; \
		wget --timeout=10 --tries=2 -4 -P $(@D) $(GPGKEY_URL)$(@F) ; \
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


# vim: background=dark ts=2 sw=2 syntax=Makefile
