FROM centos:7

RUN useradd vagrant \
  && echo "vagrant" | passwd --stdin vagrant \
  && usermod -a -G wheel vagrant

# allow vagrant to login
RUN cd ~vagrant \
  && mkdir .ssh \
  && echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > .ssh/authorized_keys \
  && chown -R vagrant:vagrant .ssh \
  && chmod 0700 .ssh \
&& chmod 0600 .ssh/authorized_keys \
&& mkdir -p /etc/sudoers.d \
&& touch /etc/sudoers.d/vagrant_user \
&& echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant_user

# install early RPMS
# XXX collect from cfg/<node>/rpm/early
RUN yum -y install \
	bash createrepo cronie iproute lsof net-tools openssh-clients openssh-server \
	python-deltarpm rsync rsyslog sudo tcsh which virt-what yum-utils; \
	systemctl enable sshd.service

EXPOSE 22

CMD ["/usr/sbin/init"]

