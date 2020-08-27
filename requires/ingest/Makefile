

VBOX_VERSION	:= $(shell cat ../../clusters/vc/common/provision/config/vboxadd/version)

VBOX_ISO	 = VBoxGuestAdditions_$(VBOX_VERSION).iso
VBOX_ISO_URL	 = https://download.virtualbox.org/virtualbox/$(VBOX_VERSION)/

SCHEDMD_SLURM_URL = https://download.schedmd.com/slurm/

repo_tgz	 = repos.tgz
repo_cksum	 = repos.cksum
SLURM_VERSION	:= $(shell cat ../../clusters/vc/cfg/vcbuild/build/slurm/version)
SLURM_TARBALL	 = slurm-$(SLURM_VERSION).tar.bz2
TARGETS		 = $(TARBALL_D)/$(repo_cksum) $(TARBALL_D)/$(repo_tgz) $(TARBALL_D)/$(VBOX_ISO) $(TARBALL_D)/$(SLURM_TARBALL)
TARBALL_D	 = ../../tarballs
TARBALL_D	:= $(realpath $(TARBALL_D))
REPO_PREFIX	 = centos/7
REPO_WORKSPACE_D = $(TARBALL_D)/repos
REPO_OS		 = $(REPO_WORKSPACE_D)/centos/7/os/.target
REPO_UPDATES	 = $(REPO_WORKSPACE_D)/centos/7/updates/.target
REPO_URL	 = rsync://linux.mirrors.es.net
REPO_HTTP_URL	 = $(subst rsync,http,$(REPO_URL))
REPO_HOST	 = $(subst rsync://,,$(REPO_URL))

# collect from ../../common/inc/ingestfs.h.sh
#       "rsync://centos.sonn.com/CentOS"
#       "rsync://mirrors.ocf.berkeley.edu"
#       "rsync://rsync.gtlib.gatech.edu"
#       "rsync://mirrors.kernel.org"
#       "rsync://mirror.math.princeton.edu/pub"
#       "rsync://mirror.cc.columbia.edu"
#       "rsync://mirror.es.its.nyu.edu"
#       "rsync://mirrors.rit.edu"
#       "rsync://mirrors.cat.pdx.edu"

all: $(TARGETS)

$(TARGETS):

$(REPO_WORKSPACE_D): $(REPO_OS) $(REPO_UPDATES)
	@if [ ! -d "$@" ] ; then    \
		mkdir -p $@     ; \
	fi

# could be a bit more intelligent about manipulating the pattern to generate the rsync
# and incorporate an estimated space check
# depending upon where people are located on the network, outbound pings may be blocked.
# Don't consider this fatal; it merely indicates checklist-security compliance.
$(REPO_OS) $(REPO_UPDATES):
	ping -c 1 -n -w 1 $(REPO_HOST) >/dev/null 2>&1                  ; \
	rc=$$?                                                          ; \
	if [ "$${rc}" -ne 0 ] ; then                                        \
		echo Warning: cannot ping repository $(REPO_HOST)       ; \
	fi
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
	rsync -4 -avz --delete --exclude=\\\*i686\.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D)
	touch $@

# use this to pull a repo and roll a tarball
$(TARBALL_D)/$(repo_tgz): $(REPO_WORKSPACE_D) $(REPO_OS) $(REPO_UPDATES)
	tar --exclude=.target -czvf $(TARBALL_D)/repos.tgz -C $(TARBALL_D) repos

$(TARBALL_D)/$(repo_cksum): $(TARBALL_D)/$(repo_tgz)
	cksum $^ > $@

$(TARBALL_D)/$(SLURM_TARBALL):
	wget -4 $(SCHEDMD_SLURM_URL)/$(SLURM_TARBALL)
	mv $(@F) $@

# set http_proxy or https_proxy if need be
$(TARBALL_D)/$(VBOX_ISO):
	wget -4 $(VBOX_ISO_URL)/$(VBOX_ISO)
	mv $(@F) $@

force:
	rm -f $(REPO_OS) $(REPO_UPDATES)

clean:
	rm -fr $(REPO_WORKSPACE_D)


# vim: background=dark
