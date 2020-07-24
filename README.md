# hpc-collab (sometimes: hpc-colab)

This project provides provisioned HPC cluster models using underlying virtualization mechanisms. 

The purpose of this project is to provide a common baseline for repeatable HPC experiments. This has been
used for education, distributed collaboration, tool development colaboration, failure signature discovery,
local HPC debugging and cluster configuration comparisons, enabled by construction and use of short-lived
and common baseline hpc cluster models. In short, extend the "systems as cattle not pets" 
<A HREF="http://www.pass.org/eventdownload.aspx?suid=1902">[1]</A> 
<A HREF="http://cloudscaling.com/blog/cloud-computing/the-history-of-pets-vs-cattle/">[2]</A> analogy into
the realm of "clusters as cattle, not pets."

The initial release requires local enablers: gmake, vagrant and virtualbox and, if specified,
<A HREF="https://libvirt.org/">libvirt</A>, and its accompanying
<A HREF="https://github.com/vagrant-libvirt/vagrant-libvirt">vagrant-libvirt plugin</A>.
<A HREF="https://graphviz.org/">Graphviz</A>, <A HREF="https://www.doxygen.nl/index.html">doxygen</A>
and <A HREF="https://github.com/hoytech/vmtouch">vmtouch</A> are recommended, but not required. A
local copy of the clever <A HREF="https://github.com/Anvil/bash-doxygen">bash-doxygen</A> sed filter
is included.  Lighterweight and multi-node mechanisms are planned.

Two representative HPC cluster recipes are provided.
Cluster recipes are in the <EM>clusters</EM> directory.
Presently, recipes generate clusters local to the installation host, only.

 <b>vc</b> is a virtual machine-based cluster, configured with the service-factored following nodes:
 <UL>
 <LI><EM>vcfs</EM>     - provides file storage to other cluster nodes, including common configuration and logs (slurm, rsyslog)</LI>
 <LI><EM>vcsvc</EM>    - provides common in-bound services such as DNS, NTP, SYSLOG</LI>
 <LI><EM>vcbuild</EM>  - configured with a larger share of RAM and cpu cores, compilation HPC partition,<br>
                       builds software (slurm, lustre) as it is brought up, if necessary</LI>
 <LI><EM>vcdb</EM>     - provides mysql service, holds the slurm scheduling database daemon</LI>
 <LI><EM>vcaltdb</EM>  - provides an alternate mysql db, configured as a replicant of the primary data base</LI>
 <LI><EM>vcsched</EM>  - provides the slurm controller and scheduler service</LI>
 <LI><EM>vc[1-2]</EM>  - computational nodes</LI>
 <LI><EM>vclogin</EM>  - front-end/login node, provides vc-cluster job submission services</LI>
 <LI><EM>vcgate</EM>   - externally-accessible node via bridged 3rd interface</LI>
 </UL>

 <b>vx</b> is a minimal, conjoined virtual-machine cluster, dependent upon "vc"
 <UL>
 <LI><EM>vxsched</EM>  - provides the slurm controller and scheduler service, dependent upon vcdb, vcbuild, vcsvc, vcfs</LI>
 <LI><EM>vx[1-2]</EM>  - computational nodes</LI>
 <LI><EM>vxlogin</EM>  - front-end/login node, provides vx-cluster job submission services</LI>
 </UL>

<H5>Security Note</H5>
<P>
This software constructs models of production clusters which include enabled and enforcing security features.
However, since the cluster models are constructed to automate and compare cluster experiments,
<b>these cluster recipes are not in themselves secure</b>.</em> Different cluster recipes would be required
to construct cluster images with security guarantees.
</P>

<H5>To start</H5>
<P>
 Set the BASE directory in <EM>bin/setpath.{c}sh</EM>. The default setting is the output of pwd, often
<EM>$HOME/hpc-collab</EM> or <EM>$HOME/hpc-collab-&lt;branch-name&gt</EM>.

~~~
         cd hpc-collab
 [csh] % source bin/setpath.csh
 [bash/zsh] $ . bin/setpath.sh
~~~

<P>
Consider setting the value <EM>clusters/common/flag/PREFERRED_REPO</EM> to your nearest <EM>rsync</EM>
reposistory.
<P>
Then <EM>make prereq</EM> to sanity check that there is sufficient storage to host this set of
cluster recipes and to construct the appropriate <EM>Vagrantfile</EM>s for the local environment.
Point <EM>hpc-collab/tarballs</EM>, <EM>$HOME/VirtualBox VMs</EM> and <EM>/var/lib/libvirt/images</EM>
at a separate partition with more storage, if needed. Examine <EM>requires/sw/*</EM> to determine
whether additional software needs to be installed onto the host, such as the vagrant 
<A HREF="https://github.com/vagrant-libvirt/vagrant-libvirt">libvirt</A>
<A HREF="https://github.com/hashicorp/vagrant/wiki/Available-Vagrant-Plugins">plugin</A>.
The <A HREF="https://github.com/tmatilai/vagrant-proxyconf">vagrant-proxyconf</A> plugin may be
necessary if individual nodes require a proxy server to establish yum installation connections.
</P>

<P>
The virtualization provider is set in <EM>clusters/common/Vagrantfile.d/cfg.vm.providers/default_provider</EM>.
By default it is <EM>virtualbox</EM>. and the configuration flag <EM>clusters/common/flag/NO_NFS</EM>
is set. This combination requires no elevated privileges and has the fewest installation and
compatibility issues.</P>
<P>
Virtualbox can be slower than libvirt provisioning although it is
<A HREF="https://github.com/hpc/hpc-collab/issues/158">more consistent</A> and
<A HREF="https://github.com/hpc/hpc-collab/issues/159">reliable</A> and does not require administrative
privileges for a <A HREF="https://www.vagrantup.com/docs/synced-folders/nfs.html">local NFS server</A>.
</P>
<P>
Cluster recipes are driven by configuration stored in skeleton file systems. <A HREF="https://www.vagrantup.com/">Vagrant</A> <A HREF="https://www.vagrantup.com/docs/vagrantfile">Vagrantfile</A> and GNU make rules ingest the settings from the <EM>cfg/&lt;nodenames&gt;</EM> directories.</P>
<P>
In the interest of documentation that matches actual code, preliminary work has been done with <A HREF="https://github.com/Anvil/bash-doxygen">bash-doxygen.sed</A>.</P>

<P>
Make systematizes dependencies and invocations.
 <UL>
  <LI><EM>cd clusters/vc; make Vagrantfile</EM>	- to construct initial Vagrantfile<BR></LI>
  <LI><EM>make prereq</EM>      - simplistic check of underlying prerequisites</LI>
  <LI><EM>make provision</EM>   - identical to 'make up'</LI>
  <LI><EM>make show</EM>        - shows virtual cluster nodes and their state</LI>
  <LI><EM>make up</EM>          - provisions virtual cluster nodes</LI>
  <LI><EM>make unprovision</EM> - destroys virtual clusters, their nodes and underlying resources</LI>
 </UL>
</P>
<P>
Aliases are provided by the setpath helper. If using them, the appropriate Makefile is set so that one need not be in a cluster directory.<BR>
<TABLE>
 <TR><TD><EM>provision</EM></TD>   <TD>make provision</TD></TR>
 <TR><TD><EM>show</EM></TD>		      <TD>make show</TD></TR>
 <TR><TD><EM>up</EM></TD>          <TD>make up</TD></TR>
 <TR><TD><EM>unprovision</EM></TD> <TD>make unprovision</TD></TR>
 <TR><TD><EM>savelogs</EM>         <TD>make savelogs</TD></TR>
</TABLE>
</P>

~~~
for <nodename>:
<nodename>	  = equivalent to 'cd clusters/<CL>; make nodename' - provisions as needed
<nodename>--	  = equivalent to 'cd clusters/<CL>; make nodename_UNPROVISION' - unprovision node
<nodename>!	  = equivalent to 'cd clusters/<CL>; make nodename_UNPROVISION ; make nodename' - unprovision and force reprovisioning

for all nodes in the cluster:
<CL>		  = equivalent to 'make up'
<CL>--		  = equivalent to 'make nodename_UNPROVISION'
<CL>!		  = equivalent to 'make nodename_UNPROVISION; make nodename' - unprovision and force reprovisioning
~~~
</P>
<P>
Components such as clusters, nodes and filesystems are standalone. Each includes code and configuration to establish prerequisites, configure, install, and verify. Common configuration implementations, <A HREF="https://github.com/hpc/hpc-collab/issues/9">such as ansible</A>, are planned.
</P>

<H4>Resource Usage</H4>
<P>
Virtualbox, in particular, requires substantial RAM (>32Gb) and storage (~36Gb) for the default cluster recipe's run-time. During ingestion of prerequisites, ~20Gb storage is needed for a temporary local copy of a CentOS repository.</P>
<P>
The <EM>vc</EM> and <EM>vx</EM> clusters build in ~90 minutes on an Intel core i5 laptop with 64Gb RAM, assuming that the initial repository rsync and tarball creation of <EM>tarballs/repos.tgz</EM> is complete and successful.</P>
<P>
Use <EM>make prereq</EM> to validate the known storage space issues. Monitoring virtual memory footprints of the cluster images is also necessary.</P>


