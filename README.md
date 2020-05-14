# hpc-collab (sometimes: hpc-colab)

This project provides provisioned HPC cluster models using underlying virtualization mechanisms. In short, "clusters as cattle, not pets."

Its purpose is to provide a common baseline for repeatable HPC experiments. This has been used for education, distributed collaboration, tool development colaboration, failure signature discovery, local HPC debugging and cluster configuration comparisons.

The initial release requires local enablers: gmake, vagrant and virtualbox. Lighterweight and multi-node mechanisms, such as containers, jails and pods, are planned.

Two representative HPC cluster recipes are included. At present, recipes generate clusters local to the installation host. Cluster recipes are in the clusters directory. At present, two representative cluster recipes are provided.

 <b>vc</b> is a virtual machine-based cluster, configured with the service-factored following nodes:
 <UL>
 <LI><EM>vcfs</EM>		- provides file storage to other cluster nodes, including common configuration and logs (slurm, rsyslog)</LI>
 <LI><EM>vcsvc</EM>		- provides common in-bound services such as DNS, NTP, SYSLOG</LI>
 <LI><EM>vcbuild</EM>	- configured with a larger share of RAM and cpu cores,
  		  compilation HPC partition
  builds software as it is brought up, if necessary</LI>
 <LI><EM>vcdb</EM>		- provides mysql/mariadb service, holds the slurm scheduling database daemon</LI>
 <LI><EM>vcsched</EM>	- provides the slurm controller and scheduler service</LI>
 <LI><EM>vc[1-2]</EM>	- computational nodes</LI>
 <LI><EM>vclogin</EM>	- front-end/login node, provides vc-cluster job submission services</LI>
 <LI><EM>vcgate</EM>	- externally-accessible node via bridged 3rd interface</LI>
 </UL>

 <b>vx</b> is a minimal, conjoined virtual-machine cluster, dependent upon "vc"
 <UL>
 <LI><EM>vxsched</EM>	- provides the slurm controller and scheduler service, dependent upon vcdb, vcbuild, vcsvc, vcfs</LI>
 <LI><EM>vx[1-2]</EM>	- computational nodes</LI>
 <LI><EM>vxlogin</EM>	- front-end/login node, provides vx-cluster job submission services</LI>
 </UL>

To start:<BR>
Set the BASE directory in bin/setpath.{c}. The default setting is $HOME/hpc-collab.</BR>
~~~
 [csh] % source bin/setpath.csh
 [bash/zsh] $ . bin/setpath.sh
~~~

Cluster recipes are driven by configuration stored in skeleton file systems. Vagrant Vagrantfile and GNU make rules ingest the settings from the cfg/<nodenames> directories.

In the interest of documentation that matches actual code, makefile rules are included graphviz, doxygen and bash-doxygen.sed.

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
<UL>
 <LI><EM>provision</EM>	= 'make provision'</LI>
 <LI><EM>show</EM>		= 'make show'</LI>
 <LI><EM>up</EM>		= 'make up'</LI>
 <LI><EM>unprovision</EM>	= 'make unprovision'</LI>
 <LI><EM>savelogs</EM> = 'make savelogs'</LI>
</UL>

~~~
<nodename>	  = equivalent to 'cd clusters/<CL>; make nodename' - only provisions as needed
<nodename>--	  = equivalent to 'cd clusters/<CL>; make nodename_UNPROVISION' - unprovision existing node
<nodename>!	  = equivalent to 'cd clusters/<CL>; make nodename_UNPROVISION ; make nodename' - unprovision and force reprovisioning of a node
~~~

Components such as clusters, nodes and filesystems are standalone. Each includes code and configuration to establish prerequisites, configure, install, and verify. Common configuration implementations, such as ansible, are planned.
