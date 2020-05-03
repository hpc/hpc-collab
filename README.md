# hpc-collab (sometimes: hpc-colab)

This project provides provisioned HPC cluster models using underlying virtualization mechanisms.

Its purpose is to provide a common baseline for repeatable HPC experiments. This has been used for education, distributed collaboration, tool development colaboration, failure signature discovery, local HPC debugging and cluster configuration comparisons.

The initial release requires local enablers: gmake, vagrant and virtualbox. Lighterweight and multi-node mechanisms, such as containers, jails and pods, are planned.

Two representative HPC cluster recipes are included. At present, recipes generate clusters local to the installation host. Cluster recipes are in the clusters directory. At present, two representative cluster recipes are provided.

 vc is a virtual machine-based cluster, configured with the service-factored following nodes:
  vcfs		- provides file storage to other cluster nodes, including common configuration and logs (slurm, rsyslog)
  vcsvc		- provides common services such as DNS, NTP, SYSLOG
  vcbuild	- configured with a larger share of RAM and cpu cores,
  		  compilation HPC partition
  		  builds software as it is brought up, if necessary
  vcdb		- provides mysql/mariadb service, holds the slurm scheduling database daemon
  vcsched	- provides the slurm controller and scheduler service
  vc[1-2]	- computational nodes
  vclogin	- front-end/login node, provides vc-cluster job submission services
  vcgate	- externally-accessible node via bridged 3rd interface

 vx is a minimal, conjoined virtual-machine cluster, dependent upon "vc"
  vxsched	- provides the slurm controller and scheduler service, dependent upon vcdb, vcbuild, vcsvc, vcfs
  vx[1-2]	- computational nodes
  vxlogin	- front-end/login node, provides vx-cluster job submission services

To start:
Set the BASE directory in bin/setpath.{c}. The default setting is $HOME/hpc-collab.
 [csh] % source bin/setpath.csh
 [bash/zsh] $ . bin/setpath.sh

Cluster recipes are driven by configuration stored in skeleton file systems. Vagrant Vagrantfile and GNU make rules ingest the settings from the cfg/<nodenames> directories.

In the interest of documentation that matches actual code, makefile rules are included graphviz, doxygen and bash-doxygen.sed.

Make systematizes dependencies and invocations.
 make prereq      - simplistic check of underlying prerequisites
 make provision   - identical to 'make up'
 make show        - shows virtual cluster nodes and their state
 make up          - provisions virtual cluster nodes
 make unprovision - destroys virtual clusters, their nodes and underlying resources

Aliases are provided by the setpath helper.
  prereq	= 'make prereq'
  provision	= 'make provision'
  show		= 'make show'
  up		= 'make up'
  unprovision	= 'make unprovision'

  <nodename>	= equivalent to 'cd clusters/<CL>; make nodename' - only provisions as needed
  <nodename>--	= equivalent to 'cd clusters/<CL>; make nodename_UNPROVISION' - unprovision existing node
  <nodename>!	= equivalent to 'cd clusters/<CL>; make nodename' - unprovision and force reprovisioning of a node

Components such as clusters, nodes and filesystems are standalone. Each includes code and configuration to establish prerequisites, configure, install, and verify. Common configuration implementations, such as ansible, are planned.
