#/bin/bash

#Setting up paths and directories
SCRIPT=$(realpath $0)
MONITOR_DIR=$(dirname $SCRIPT)
HPCCOLLAB=$HOME/hpc-collab
MONITOR_STATE_DIR=/vc/common/._state/monitored
TIMETOCOMPLETE_FILE=/tmp/ttc_$(date +%M%S).txt
GLOBAL_MAX_TIME=0

#Read in options to execute this script and its child script
while getopts "he:t:" OPTION; do
  case $OPTION in
  e)
		echo "exec type"
    EXE_TYPE=$OPTARG
    case $EXE_TYPE in

    1)
      KEYPRESS=1
      TIMESTOP=0
      echo "Executing keypress disruption only..."
      ;;
    2)
      KEYPRESS=0
      TIMESTOP=1
      echo "Executing time monitor only.."
      ;;
    3)
      DUAL_EXE=3
      KEYPRESS=1
      TIMESTOP=1
      echo " Executing user and time monitor..."
      ;;
    *)
      echo "Incorrect input please try again"
      exit 1
      ;;

    esac
    ;;
  t)
    TIMEIN=$OPTARG
    echo "TIMEIN:$TIMEIN"
    ;;
  h)
    echo ""
    echo "Here are the potential outputs you can have for main.sh"
    echo "1. -e 1 execute log but with only key interruption"
    echo "2. -e 2 execute log but with only time interruption that is set"
    echo "3. -e 3 execute log but with key and time interruption (recommended)"
    echo "4. -t <TIME> the minutes you want this script to execute"
    echo "NOTE: This is required for this script"
    echo ""
		exit 1
    ;;
  *)
    echo "Incorrect Options Provided"
    exit 1
    ;;
  esac
done
echo "Keypress: $KEYPRESS and TIMEstop: $TIMESTOP"

#Main script that goes from setup to execute and thread completion
main () {
_timed_timeset $TIMESTOP $TIMEIN
_keypress_timeset $KEYPRESS $DUAL_EXE
_collect_data $KEYPRESS $TIMESTOP
_verify_threads_complete $KEYPRESS
}

#Setup if we have a timestop and timin for this execution
_timed_timeset () {
if [[ "$1" == "1" ]]; then
  if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo -n "Sorry integers only re-run driverInput.sh"
  fi
  echo "Time that will be executed: $2"
  local _max_time=$(($2 * 60))
  GLOBAL_MAX_TIME=$_max_time
  echo $GLOBAL_MAX_TIME
  local _timestamp_var=$(date '+%Y-%m-%d %T' -d "$end_time+$_max_time seconds")
  echo "$(date +%s -d "${_timestamp_var}")" >$TIMETOCOMPLETE_FILE
fi
}

#Setup if we have a keypress for this execution
_keypress_timeset () {
if [[ "$1" == "1" ]]; then
  if [ -t 0 ]; then
    SAVED_STTY="$(stty --save)"
    stty -echo -icanon -icrnl time 0 min 0
    local keypress=''
  fi
  if [[ "$2" != "3" ]]; then
    local _timestamp=$(date '+%Y-%m-%d %T' -d "$end_date+1 days")
    echo "$(date +%s -d "${_timestamp}")" >$TIMETOCOMPLETE_FILE
  fi
fi
}

#The main execution portion of this script that checks for process killing and executes child script
_collect_data () {
local _stopper=0
SECONDS=0
#A boolean to kill the script
while [ 1 ]; do
  if [[ "$_stopper" == "0" ]]; then
    #Execute file in background
    pushd $MONITOR_DIR > /dev/null
    ./populateLogs.sh &
    popd $MONITOR_DIR > /dev/null
    local _populate_PID=$!
    _stopper=1
  fi
  if [[ "$1" == "1" ]]; then
    local keypress="$(cat -v)"
    if [ "x$keypress" != "x" ]; then
      echo "$(date +%s)" >$TIMETOCOMPLETE_FILE
      break
    fi
  fi
	if [[ "$2" == "1" ]]; then
 		if [ "$SECONDS" -gt "$GLOBAL_MAX_TIME" ]; then
      echo "ITS ABOUT THAT TIME"
			echo "$(date +%s)" >$TIMETOCOMPLETE_FILE
      break
    fi
  fi
done
echo "7. Exiting while loop and waiting for other threads"
}

#There is a file that the parent and child script talk to and communicate
#If it doesn't exist then that thread is is complete and this script can finish
_verify_threads_complete () {
VERIFY_POPULATE_FILE=/tmp/$(ls -t /tmp | grep state_ | head -n 1)
while [ -f "$VERIFY_POPULATE_FILE" ]; do
  echo "Waiting for PopulateDataLogs.sh to complete"
  sleep 1
done
echo "==== $VERIFY_POPULATE_FILE"
# reset keypress logic
if [[ "$1" == "1" ]]; then
  if [ -t 0 ]; then stty "$SAVED_STTY"; fi
fi
stty sane			# handle stty so it resets terminal output

echo "8. Script Complete, check data logs for more"

if [[ ${HOSTNAME:0:2} != "vc"* ]]; then
  MONITOR_STATE_DIR=$HPCCOLLAB/clusters${MONITOR_STATE_DIR}
fi

mkdir $MONITOR_STATE_DIR
MONITOR_STATE_DIR=${MONITOR_STATE_DIR}/$(hostname -s)
local _state_file=${MONITOR_STATE_DIR}/$(date '+%d%H%M%S')
mkdir $MONITOR_STATE_DIR
chmod 0777 $MONITOR_STATE_DIR
touch $_state_file
chmod 0777 $_state_file
echo "New state file created: ${_state_file}"
}

main
exit 0
