#!/bin/bash

### Introduction: This is the 2nd Child script that is being executed from main.sh
### We are collecting data from from different areas one being the node and the host
###   and we funnel that into a specific directory called data
### Step 1: Check if node is provisioned and scp from from that directory onto host in /tmp
### Step 2: cp from /tmp in data
### Step 3: graph the data
### Step 4: repeat 2-3 for host data

#Setting up directories for scp'ing and graphing
HPCCOLLAB_DIR=$HOME/hpc-collab
NODE_PROVISION_SHAREDFS=/home/vagrant/common/provision/useradd/$(whoami)/verify/provisioned
SCRIPT=$(realpath $0)
COLLECT_AND_VIZ=$(dirname $SCRIPT)
MAINDIR=$(dirname "$COLLECT_AND_VIZ")
MONITOR_DIR=$MAINDIR/monitor
DATADIR=$COLLECT_AND_VIZ/data
#where we check the state of each node and store into an array
PROVISIONED=$(ls $HPCCOLLAB_DIR/clusters/vc/common/._state/provisioned/)
vcnodes=($PROVISIONED)

#setting up paths
HOSTLOGS="$MONITOR_DIR/logs"
TIMESTAMP=$(ls -Art $HOSTLOGS | tail -n 1)
RECENTDIR="$DATADIR/$TIMESTAMP"
mkdir -p ${RECENTDIR}
echo "Made a directory with graphs in data/${TIMESTAMP}"

#create directories if need be to store logs for graphing
for node in ${vcnodes[@]}
do
        #Where logs are being stored on each node
        NODE_LOGDIR=$NODE_PROVISION_SHAREDFS/$node/monitor/logs

        # grab all data from VC logdir
	echo "SCP to $node"
        scp -r $node:$NODE_LOGDIR /tmp/$node

        #Want to grab the latest log and copy it to our master_log folder
        MOST_RECENT_LOG=$(ls -Art /tmp/$node/logs | tail -n 1)
        printf "Grabbing most recent folder: $node/$MOST_RECENT_LOG\n"
	NODEDIR=${RECENTDIR}/${node}_${MOST_RECENT_LOG}
	printf "=== Making $NODEDIR\n"
        cp -r /tmp/$node/logs/$MOST_RECENT_LOG $NODEDIR

    #Graph to get png's for the current node
		printf "=== Graphing $NODEDIR\n"
   	./graph.sh -f $NODEDIR

        #Check to see if there is a existent dashboard.png for that node to avoid overwrite
      if [ -f $NODEDIR/dashboard.png ];
     	then
            #copy the current node dashboard.png to be wrapped up for sending to local workspace
       	    cp $NODEDIR/dashboard.png ${RECENTDIR}/${node}_dashboard.png
   		fi
done

echo "Done Copying Virtual Nodes"

#Same thing as above but for strictly the host since it is "separate" from $node
HOSTNAME=$(hostname -s)
printf "We are in host grabbing ${TIMESTAMP}\n"
HOSTDIR="${RECENTDIR}/$HOSTNAME_${TIMESTAMP}"
cp -r $HOSTLOGS/${TIMESTAMP} $HOSTDIR

pushd $COLLECT_AND_VIZ > /dev/null
./graph.sh -f $HOSTDIR
popd # collect and viz

cp $HOSTDIR/dashboard.png ${RECENTDIR}/$HOSTNAME_${TIMESTAMP}_dashboard.png

