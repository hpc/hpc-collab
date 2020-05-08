

VBOX_ISO	 = VBoxGuestAdditions_6.1.6.iso
VBOX_ISO_URL	 = https://download.virtualbox.org/virtualbox/6.1.6/

repo_tgz	 = repos.tgz
repo_cksum	 = repos.cksum
TARGETS		 = $(TARBALL_D)/$(repo_cksum) $(TARBALL_D)/$(repo_tgz) $(TARBALL_D)/$(VBOX_ISO)
TARBALL_D	 = ../../tarballs
REPO_PREFIX	 = centos/7
REPO_WORKSPACE_D = $(TARBALL_D)/repos
REPO_OS		 = $(REPO_WORKSPACE_D)/centos/7/os/.target
REPO_UPDATES	 = $(REPO_WORKSPACE_D)/centos/7/updates/.target
REPO_URL	 = rsync://linux.mirrors.es.net

# collect from ../../common/inc/ingestfs.h.sh
#	"rsync://centos.sonn.com/CentOS"
#	"rsync://mirrors.ocf.berkeley.edu"
#	rsync://rsync.gtlib.gatech.edu"
#	rsync://mirrors.kernel.org"
#	rsync://mirror.math.princeton.edu/pub"
#	rsync://mirror.cc.columbia.edu"
#	rsync://mirror.es.its.nyu.edu"
#	rsync://mirrors.rit.edu"
#	rsync://mirrors.cat.pdx.edu"

all: $(TARGETS)

$(TARGETS):

$(REPO_WORKSPACE_D): $(REPO_OS) $(REPO_UPDATES)
	@if [ ! -d $@ ] ; then	  \
		mkdir -p $@	; \
	fi

# could be a bit more intelligent about manipulating the pattern to generate the rsync
# and incorporate an estimated space check
$(REPO_OS) $(REPO_UPDATES):
	mkdir -p $(@D)
	rsync --dry-run  -4 -avz --delete --exclude=\*i686\.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D)
	rsync            -4 -avz --delete --exclude=\*i686\.rpm $(REPO_URL)$(subst $(REPO_WORKSPACE_D),,$(@D))/ $(@D)
	touch $@

# use this to pull a repo and roll a tarball
$(TARBALL_D)/$(repo_tgz): $(REPO_WORKSPACE_D) $(REPO_OS) $(REPO_UPDATES)
	tar --exclude=.target -czvf $(TARBALL_D)/repos.tgz -C $(TARBALL_D) repos

$(TARBALL_D)/$(repo_cksum): $(TARBALL_D)/$(repo_tgz)
	cksum $^ > $@


# set http_proxy or https_proxy if need be
$(TARBALL_D)/$(VBOX_ISO):
	wget -4 $(VBOX_ISO_URL)/$(VBOX_ISO)
	mv $(@F) $@

force:
	rm -f $(REPO_OS) $(REPO_UPDATES)

clean:
	rm -fr $(REPO_WORKSPACE_D)
