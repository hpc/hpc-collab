#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/requires.sh
## @author LANL/HPC/ENV/WLM/sts Steven Senator sts@lanl.gov

## @page Copyright
## <h2>© 2019. Triad National Security, LLC. All rights reserved.</h2>
## &nbsp;
## <p>This program was produced under U.S. Government contract 89233218CNA000001
## for Los Alamos National Laboratory (LANL), which is operated by Triad National Security, LLC
## for the U.S. Department of Energy/National Nuclear Security Administration.</p>
## <p>All rights in the program are reserved by Triad National Security, LLC, and the
## U.S. Department of Energy/National Nuclear Security Administration. The US federal Government
## is granted for itself and others acting on its behalf a nonexclusive, paid-up, irrevocable
## worldwide license in this material to reproduce, prepare derivative works, distribute copies
## to the public, perform publicly and display publicly, and to permit others to do so.</p>
## <p>The public may copy and use this information without charge, provided that this Notice
## and any statement of authorship are reproduced on all copies. Neither the Government
## nor Triad National Security, LLC makes any warranty, express or implied, or assumes any
## liability or responsibility for the use of this information.</p>
## <p>This program has been approved for release from LANS by LA-CC Number 10-066, being part of
## the HPC Operational Suite.</p>
## &nbsp;
##

## @brief This library file defines parameters and functions to load and execute requirements and prerequisites.

## @see WaitForPrerequisites()
## each test will be tried REQUIREMENT_RETRY_LIMIT with a pause of REQUIREMENT_RETRY_SLEEP seconds between them
declare -x REQUIREMENT_RETRY_LIMIT=20
declare -x REQUIREMENT_RETRY_SLEEP=3

