#!/bin/bash

#DATAFOLDER time for that specific node
#PROV_OUT is in provision_outputs for vcgate.out
# handle command line args
while getopts "p:f:t:g:" OPTION; do
    case $OPTION in
    f)
        DATAFOLDER=$OPTARG
        ;;
    p)
        PROV_OUT=$OPTARG
        ;;

    g)
        GRAPHDIR=$OPTARG
        ;;
    *)
        echo "Incorrect options provided"
        exit 1
        ;;
    esac
done

#function to populate the txt file
genProcessTimestamps () {

#Checking what nodes were being provisioned to collect timestamps
node_array=()
while IFS= read -r line; do
        node=${line%:}
        node_array+=( "$node" )
done < <( cat $PROV_OUT | grep UserAdd | awk '{print $1}' )
printf "=== Provision Outfile: $PROV_OUT\n"
printf "=== nodes provisioned: ${node_array[*]}\n"

#Now we want to loop through and add time stamps for each node
for i in ${node_array[@]};
 do
  #Start-Finish part 0-4
  Start=$(cat ${PROV_OUT} | grep Flags: | grep $i | head -1 | awk '{print $2}')
  End=$(cat $PROV_OUT | grep TimeStamp | grep $i | tail -1 | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$Start" "$End" "${i}_provisioning"

  #InstallEarlyRpms part 1 of 4
  InstallEarlyRpmsStart=$(cat ${PROV_OUT} | grep InstallEarlyRPMS | grep $i | awk '{print $2}')
  InstallEarlyRpmsEnd=$(cat $PROV_OUT | grep ConfigureLocalRepos | grep $i | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$InstallEarlyRpmsStart" "$InstallEarlyRpmsEnd" "${i}_InstallEarlyRPMS"

  #InstallRpms method part 2 of 4
  InstallRpmsStart=$(cat $PROV_OUT | grep InstallRPMS | grep $i | awk '{print $2}')
  InstallRpmsEnd=$(cat $PROV_OUT | grep BuildSW | grep $i | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$InstallRpmsStart" "$InstallRpmsEnd" "${i}_InstallRPMS"

  #BuildSW method part 3 of 4
  BuildSWStart=$(cat $PROV_OUT | grep BuildSW | grep $i | awk '{print $2}')
  BuildSWEnd=$(cat $PROV_OUT | grep UserAdd | grep $i | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$BuildSWStart" "$BuildSWEnd" "${i}_BuildSW"

  #UserAdd method part 4 of 5
  UserAddStart=$(cat $PROV_OUT | grep UserAdd | grep $i | awk '{print $2}')
  UserAddEnd=$(cat $PROV_OUT | grep VerifySW | grep $i | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$UserAddStart" "$UserAddEnd" "${i}_UserAdd"

  #VerifySW method part 5 of 5
  VerifySWStart=$(cat $PROV_OUT | grep VerifySW | grep $i | awk '{print $2}')
  VerifySWEnd=$(cat $PROV_OUT | grep TimeStamp | grep $i | tail -1 | awk '{print $2}')
  printf "%s\t%s\t%s\t\n" "$VerifySWStart" "$VerifySWEnd" "${i}_VerifySW"
done > $TIMESTAMPS_FILE
}

genTimestampGraphs () {
  GRAPHDIR=${GRAPHDIR:-$DATAFOLDER/graphs}

  mkdir -p $GRAPHDIR

  #where we read the text file as an array to create graphs
  while IFS=$'\t' read -r -a myArray
   do
        printf "start: ${myArray[0]}, end: ${myArray[1]}, description: ${myArray[2]}\n"
        ./graph.sh  -t -f $DATAFOLDER -s "${myArray[0]}" -e "${myArray[1]}" -d "$GRAPHDIR/${myArray[2]}"
   done < "$TIMESTAMPS_FILE"
}


#setting up pathing and directories
SCRIPT=$(realpath $0)
MAINDIR=$(dirname $SCRIPT)
#Setting up proper Directory paths to call
PROV_OUT_DIR=$MAINDIR/../provision-outputs
RECENT_DATA_DIR=$(ls -Art $MAINDIR/data | tail -n 1)
RECENT_OUT=$(ls -Art $PROV_OUT_DIR | tail -n 1)
NODE_RECENT_OUTFILE=$(ls -Art $PROV_OUT_DIR/$RECENT_OUT | tail -n 1)
PROV_OUT=${PROV_OUT:-$PROV_OUT_DIR/$RECENT_OUT/$NODE_RECENT_OUTFILE}
TIMESTAMPS_FILE=$MAINDIR/data/$RECENT_DATA_DIR/timestamps.txt
touch $TIMESTAMPS_FILE

main () {

	#check to see if we passed in a correct data timestamp folder
  if [[ -z $DATAFOLDER ]]; then
        echo "ERROR: Missing DATAFOLDER"
        exit 1
  fi
	genProcessTimestamps
	genTimestampGraphs

}

main
