#!/bin/bash

# get aliases from non-interactive shell
shopt -s expand_aliases

HPCCOLLAB_DIR=$HOME/hpc-collab
USERADD_DIR=$HPCCOLLAB_DIR/clusters/vc/cfg/provision/useradd/cmarquardt/verify/provisioned/vcfs/monitor/scripts
SCRIPT=$(realpath $0)
COLLECT_AND_VIZ=$(dirname $SCRIPT)
MAINDIR=$(dirname "$COLLECT_AND_VIZ")
MONITOR_DIR=$MAINDIR/monitor/
PROVISION_DIR=$MAINDIR/provision-outputs
HOST_MONITORMINS=140
DEFAULT_NODE=vcgate
TIMESTAMP=$(date '+%d%H%M%S')

# handle command line args
## XXX see getopt
for arg in "$@"
do
	case $arg in
		-n|--node)
		node="$2"
		shift
		shift
		;;
		-m|--mins)
		HOST_MONITORMINS="$2"
		shift
		;;
	esac
done


# assign defaults if CL args are not specified
if [ -z "$node" ]; then
	node=$DEFAULT_NODE
fi


printf "=== provisioning: $node\n"
printf "=== monitoring time: $HOST_MONITORMINS mins\n"

pushd $COLLECT_AND_VIZ > /dev/null
./setInputMins.sh
popd > /dev/null # for $COLLECT_AND_VIZ

pushd $HPCCOLLAB_DIR > /dev/null
echo "Setting path in $(pwd)"
. bin/setpath.sh
popd > /dev/null # for $HPCCOLLAB_DIR

rsync -v $MONITOR_DIR/logging.sh $USERADD_DIR/logging.sh
rsync -v $MONITOR_DIR/populateLogs.sh $USERADD_DIR/populateLogs.sh

# begin monitoring on host in background
pushd $MONITOR_DIR > /dev/null
echo "Begin monitoring in $(pwd)"
nohup ./logging.sh -e 3 -t $HOST_MONITORMINS &
popd > /dev/null # for $MONITOR_DIR

# begin vc provision
CURRENT_PROVISION_DIR=$PROVISION_DIR/provision_$TIMESTAMP
mkdir -p $CURRENT_PROVISION_DIR
pushd $CURRENT_PROVISION_DIR > /dev/null
echo "=== Begin provisioning in $(pwd)"

# following unprovisions all nodes
rm -f $HOME/hpc-collab/clusters/vc/common/._state/provisioned/*
make -C $HPCCOLLAB_DIR/clusters/vc unprovision  >> ${CURRENT_PROVISION_DIR}/unprovision.out 2>&1
show

# do something sensible if no node has been specified
node=${node:-vcsvc}

make -C $HPCCOLLAB_DIR/clusters/vc ${node} >> ${CURRENT_PROVISION_DIR}/${node}.out 2>&1

echo "=== Ending provisioning"
popd > /dev/null # for $CURRENT_PROVISION_DIR

SUFFIX_STATE_DIR=$HPCCOLLAB_DIR/clusters/vc/common/._state
MONITOR_STATE_DIR=${SUFFIX_STATE_DIR}/monitored/$node

mkdir -p $MONITOR_STATE_DIR
while [ 1 ]
do
	MOST_RECENT=$(ls -Art $MONITOR_STATE_DIR | tail -n 1)
	if [ -z  $MOST_RECENT ]; then
		MOST_RECENT=0
	fi
	if [ $MOST_RECENT -ge $TIMESTAMP ]; then
		echo "=== Monitoring for $node completed at $MOST_RECENT"
		# clean up state file
		rm $MONITOR_STATE_DIR/$MOST_RECENT
		break
	fi
	sleep 1
done


MONITOR_STATE_DIR=${SUFFIX_STATE_DIR}/monitored/$(hostname -s)

mkdir -p $MONITOR_STATE_DIR
while [ 1 ]
do
	MOST_RECENT=$(ls -Art $MONITOR_STATE_DIR | tail -n 1)
	if [ -z  $MOST_RECENT ]; then
		MOST_RECENT=0
	fi
	if [ $MOST_RECENT -ge $TIMESTAMP ]; then
		echo "=== Monitoring for $(hostname -s) completed at $MOST_RECENT"
		# clean up state file
		rm $MONITOR_STATE_DIR/$MOST_RECENT
		break
	fi
done
