#!/bin/bash
# script for running a benchmark on the vc cluster
# goal: to monitor all nodes and host while slurm job is executed

shopt -s expand_aliases
SCRIPT=$(realpath $0)
BENCH_DIR=$(dirname $SCRIPT)
BASE_DIR=$(dirname $BENCH_DIR)
COLLECT_AND_VIZ=$BASE_DIR/collect-and-visualize
LOGIN_NODE=vclogin
HPCCOLLAB_DIR=$HOME/hpc-collab
SUFFIX_STATE_DIR=$HPCCOLLAB_DIR/clusters/vc/common/._state
PROVISIONED=$(ls $HPCCOLLAB_DIR/clusters/vc/common/._state/provisioned/)
vcnodes=($PROVISIONED)
GUEST_MONITOR_DIR=/home/vagrant/common/provision/useradd/nfrumkin/verify/provisioned
TIME=1
TIMESTAMP=$(date '+%d%H%M%S')

echo "=== scp STREAM/ to $LOGIN_NODE"
scp -r $BENCH_DIR/STREAM $LOGIN_NODE:

#Starting out monitoring on all nodes before we run STREAM
_ssh_start_monitor () {
echo "=== Starting monitoring on all nodes for $TIME minutes ==="
for node in ${vcnodes[@]}
	do
		ssh $node "export PATH=$PATH:."
 		ssh $node "${GUEST_MONITOR_DIR}/${node}/monitor/scripts/logging.sh -e 2 -t $TIME" 
	done
}

# run slurm job for benchmark on vclogin
_slurm_stream_job () {
echo "=== Conducting an sbatch for STREAM on the vclogin node ==="
ssh $LOGIN_NODE 'cd STREAM && sbatch stream.sbatch'
}

_wait_for_monitor() {

local nd=$1

MONITOR_STATE_DIR=${SUFFIX_STATE_DIR}/monitored/$nd
mkdir -p $MONITOR_STATE_DIR

while [ 1 ]
do
	MOST_RECENT=$(ls -Art $MONITOR_STATE_DIR | tail -n 1)
	if [ -z  $MOST_RECENT ]; then
		MOST_RECENT=0
	fi
	if [ $MOST_RECENT -ge $TIMESTAMP ]; then
		echo "=== Monitoring for $nd completed at $MOST_RECENT"
		break
	fi
	sleep 1
done
}

main () {
_ssh_start_monitor
_slurm_stream_job
#Create a wait until collecting is done and then collect
for node in ${vcnodes[@]}; do
		echo "=== Waiting for Monitoring on $node"
		_wait_for_monitor $node
done
echo "=== Collecting data from this monitoring scenario ==="
pushd $COLLECT_AND_VIZ > /dev/null
./collectVCData.sh
popd > /dev/null

exit 0
SECONDS=0
while [ 1 ]
do
	local _max_time=$(($TIME*60))
	if [[ $SECONDS -gt $_max_time ]];
		then
			echo "=== Collecting data from this monitoring scenario ==="
			pushd $COLLECT_AND_VIZ > /dev/null
			./collectVCData.sh
			popd > /dev/null
			break
		fi
done

echo "=== Benchmark Successful! ==="
}

main
