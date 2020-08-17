#!/bin/bash

#### Introduction: This is our main script that executes all of the other scripts
#### Consider this the Parent script to all the monitoring software
#### 3 steps: 1. vcJob.sh 2. collectVCData.sh 3. multiTimestampGraph.sh

NODE=vcgate
MONITOR_MINS=140
ITERATIONS=1
while getopts "hn:m:i:" OPTION; do
        case $OPTION in
        n)
        NODE=$OPTARG
        ;;
        m)
        MONITOR_MINS=$OPTARG
        ;;
        i)
        ITERATIONS=$OPTARG
        ;;
        h)
				echo ""
        echo "Here are the potential outputs you can have for main.sh"
        echo "1. -n is the node you want want to provision up to"
        echo "2. -m is the monitor minutes you want to establish for monitoring on host"
        echo "3. -i is the amount of iterations you want the two options above to do"
        echo "NOTE: While it is not required to have these options it is recommended"
        echo ""
				exit 1
        ;;
        *)
        echo "Incorrect values please try again"
        exit 1
     esac
done

#Setting up paths to reach certain directories for data and certain scripts
SCRIPT=$(realpath $0)
MAINDIR=$(dirname $SCRIPT)
COLLECT_AND_VIZ=$MAINDIR/collect-and-visualize
DATADIR=$COLLECT_AND_VIZ/data
PROVDIR=$MAINDIR/provision-outputs

#We start to provision nodes and pass up to what node we want to reprovision and how much time each one gets
run_job () {
  echo "Running Jobs"
  printf "==== node: $1, mins: $2\n"
  pushd $COLLECT_AND_VIZ > /dev/null
  ./vcJob.sh -n $1 -m $2
  popd
}

#Once monitoring is done we want to collect all the data from the nodes and host and push it to one spot in
# the data directory, we also graph at a high for each node and on the host
grab_data_from_nodes_and_plot () {
  echo "Collecting graphs from all nodes"
  pushd $COLLECT_AND_VIZ > /dev/null
  ./collectVCData.sh
  popd
}

#Lastly, dig through the .out file in provision_outputs dir and collect the timestamps for each process on each node
#put those timestamps into a .txt doc with the rest of the data for each process to be graphed
graph_multiple_time_ranges () {
  PROVISION_OUT=$PROVDIR/$(ls -Art $PROVDIR | tail -n 1)
  MOST_RECENT_PROV_OUT=$PROVISION_OUT/$(ls -Art $PROVISION_OUT | tail -n 1)
  DATA_TIMESTAMP_DIR=$DATADIR/$(ls -Art $DATADIR | tail -n 1)
  pushd $DATA_TIMESTAMP_DIR > /dev/null
  ALL_DATADIRS=($(ls -d */))
	popd > /dev/null # for COLLECT_AND_VIZ

  #The data on each node will be passed through for a closer look with graphing
  for i in "${ALL_DATADIRS[@]}"
    do
     i=${i%/}
     echo $i
     echo "Data: $DATA_TIMESTAMP_DIR/$i"
		 pushd $COLLECT_AND_VIZ > /dev/null
     ./multiTimestampGraph.sh -p $MOST_RECENT_PROV_OUT -f $DATA_TIMESTAMP_DIR/$i
		 popd > /dev/null # for COLLECT_AND_VIZ
   done
}

main () {

#This is the order of operations taking place for monitoring
for i in $(seq 1 $ITERATIONS)
do
	run_job "$NODE" "$MONITOR_MINS"
	grab_data_from_nodes_and_plot
  graph_multiple_time_ranges
done

}

main
