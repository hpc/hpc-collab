#!/bin/bash

#Introduction: Reads in a .txt file to allocate a certian amount of time each one should monitor on there own host
#This gets pushed over to another .txt file that gets rsynced to that node and is read by 1.driver.sh

HPCCOLLAB_DIR=$HOME/hpc-collab
MASTER_MINS_FILE=nodeMins.txt
USERADD_DIR=$HPCCOLLAB_DIR/clusters/vc/cfg/provision/useradd/cmarquardt/verify/provisioned

main () {
while IFS=$'\t' read -r -a myArray
do

	node=${myArray[0]}
	mins=${myArray[1]}
	inputFile=$USERADD_DIR/$node/monitor/inputMins.txt
	echo $mins > $inputFile

done < "$MASTER_MINS_FILE"
}

main
