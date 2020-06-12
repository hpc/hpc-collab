# hpc-collab (sometimes: hpc-colab)

This project provides provisioned HPC cluster models using underlying virtualization mechanisms. 

The purpose of this project is to provide a common baseline for repeatable HPC experiments. This has been used for education, distributed collaboration, tool development colaboration, failure signature discovery, local HPC debugging and cluster configuration comparisons, enabled by construction and use of short-lived and common baseline hpc cluster models. In short, extend the "systems as cattle not pets" <A HREF="http://www.pass.org/eventdownload.aspx?suid=1902">[1]</A> <A HREF="http://cloudscaling.com/blog/cloud-computing/the-history-of-pets-vs-cattle/">[2]</A> analogy into the realm of "clusters as cattle, not pets."

The initial release requires local enablers: gmake, vagrant and virtualbox. Lighterweight and multi-node mechanisms, such as containers, jails and pods, are planned.

Two representative HPC cluster recipes are provided. Cluster recipes are in the <EM>clusters</EM> directory.  Presently, recipes generate clusters local to the installation host. 

 <b>vc</b> is a virtual machine-based cluster, configured with the service-factored following nodes:
 <UL>
 <LI><EM>vcfs</EM>     - provides file storage to other cluster nodes, including common configuration and logs (slurm, rsyslog)</LI>
 <LI><EM>vcsvc</EM>    - provides common in-bound services such as DNS, NTP, SYSLOG</LI>
 <LI><EM>vcbuild</EM>  - configured with a larger share of RAM and cpu cores, compilation HPC partition,<br>
                       builds software (slurm, lustre) as it is brought up, if necessary</LI>
 <LI><EM>vcdb</EM>     - provides mysql service, holds the slurm scheduling database daemon</LI>
 <LI><EM>vcaltdb</EM>  - provides an alternate mysql db, configured as a slave replicant of the primary data base</LI>
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

To start:<BR>
Set the BASE directory in bin/setpath.{c}sh. The default setting is $HOME/hpc-collab.</BR>
~~~
 [csh] % source bin/setpath.csh
 [bash/zsh] $ . bin/setpath.sh
~~~
Then ```make prereq``` to sanity check that there is sufficient storage to host this set of cluster recipes. Be prepared to point ```hpc-collab/tarballs``` and ```$HOME/VirtualBox VMs``` at a separate partition with more storage.

Cluster recipes are driven by configuration stored in skeleton file systems. <A HREF="https://www.vagrantup.com/">Vagrant</A> <A HREF="https://www.vagrantup.com/docs/vagrantfile">Vagrantfile</A> and GNU make rules ingest the settings from the <EM>cfg/&lt;nodenames&gt;</EM> directories.

In the interest of documentation that matches actual code, makefile rules are included for graphviz, doxygen and <A HREF="https://github.com/Anvil/bash-doxygen">bash-doxygen.sed</A>.

<P>Make systematizes dependencies and invocations.
 <UL>
  <LI><EM>make prereq</EM>      - simplistic check of underlying prerequisites</LI>
  <LI><EM>make provision</EM>   - identical to 'make up'</LI>
  <LI><EM>make show</EM>        - shows virtual cluster nodes and their state</LI>
  <LI><EM>make up</EM>          - provisions virtual cluster nodes</LI>
  <LI><EM>make unprovision</EM> - destroys virtual clusters, their nodes and underlying resources</LI>
 </UL>
 <P>
Aliases are provided by the setpath helper. If using them, the appropriate Makefile is set so that one need not be in a cluster directory.<BR>
<TABLE>
 <TR><TD><EM>provision</EM></TD>   <TD>make provision</TD></TR>
 <TR><TD><EM>show</EM></TD>		      <TD>make show</TD></TR>
 <TR><TD><EM>up</EM></TD>          <TD>make up</TD></TR>
 <TR><TD><EM>unprovision</EM></TD> <TD>make unprovision</TD></TR>
 <TR><TD><EM>savelogs</EM>         <TD>make savelogs</TD></TR>
</TABLE>

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

Components such as clusters, nodes and filesystems are standalone. Each includes code and configuration to establish prerequisites, configure, install, and verify. Common configuration implementations, <A HREF="https://github.com/hpc/hpc-collab/issues/9">such as ansible</A>, are planned.

<H4>Resource Usage</H4>

Virtualbox, in particular, requires substantial RAM (>32Gb) and storage (~36Gb) for the default cluster recipe's run-time. During ingestion of prerequisites, ~20Gb storage is needed for a temporary local copy of a CentOS repository.

The <EM>vc</EM> and <EM>vx</EM> clusters build in ~90 minutes on an Intel core i5 laptop with 64Gb RAM, assuming that the initial repository rsync and tarball creation of <EM>tarballs/repos.tgz</EM> is complete and successful.

