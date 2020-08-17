#!/bin/bash

VERBOSE="false"
THRESHOLD="false"

#Commands that are read to setup graphing for certain timestamps
while getopts "htvf:s:e:d:" OPTION; do
    case $OPTION in
    f)
        FOLDER=$OPTARG
        ;;
    v)
				VERBOSE="true"
				;;
    t)
        THRESHOLD="true"
        ;;
    s)
        TSTARTDATE=$OPTARG
        ;;
    e)
        TENDDATE=$OPTARG
        ;;
    d)
        DASHBOARD_NAME="${OPTARG}.png"
        ;;
    h)
        echo ""
        echo "Here are the potential outputs you can have for graph.sh"
        echo "1. -f is the folder name from where you want to graph"
        echo "2. -v is for a more verbose output to the terminal"
        echo "3. -t is a threshold in between the global timestamps of a file"
				echo "4. -s if you have established a threshold graph this would be the start timestampi in the format dd-HH-MM-SS.NNNNNN"
				echo "5. -e if you have established a threshold graph this would be the end timestamp in the format dd-HH-MM-SS.NNNNNN"
				echo "6. -d is to give the graph .png a name e.g dashboard"
        echo "NOTE: While it is not required to have most of these options it is recommended" 
        echo ""
        exit 1
        ;;

    *)
        echo "Incorrect options provided"
        exit 1
        ;;
    esac
done

FOLDER=$(realpath $FOLDER)
GRAPHDIR=$FOLDER/graphs
IFACE_FILE=$FOLDER/netstat/InterfaceLog.txt
MEM_FILE=$FOLDER/memAlloc/memAllocLog.txt
IO_FILE=$FOLDER/iostat/iostatLog.txt
IP_FILE=$FOLDER/netstat/IPLog.txt
TCP_FILE=$FOLDER/netstat/TCPLog.txt
UDP_FILE=$FOLDER/netstat/UDPLog.txt
VMSTAT_FILE=$FOLDER/vmstat/vmstatLog.txt
FOLDER_TIMESTAMP=${FOLDER##*_}
DASHBOARD_NAME=$FOLDER/"dashboard.png"
STARTDATE=$(head -n 1 $IFACE_FILE | sed 's/,.*//')		# first timestamp in file
ENDDATE=$(tail -n 1 $IFACE_FILE | sed 's/,.*//')			# last timestamp in file

if [[ "$VERBOSE" == "true" ]]; then
  printf "=== Graphing from $STARTDATE to $ENDDATE\n"
	printf "dashboard name: $DASHBOARD_NAME\n"
 	if [[ "$THRESHOLD" == "true" ]]; then
 		printf "start: $TSTARTDATE end: $TENDDATE\n"
	fi
fi

#	determine time range
if [[ "$THRESHOLD" == "true" ]]; then

  # verify time range has the same number of digits
	K_DATE_DIGITS=18
  if [[ "${#TSTARTDATE}" != "$K_DATE_DIGITS" || "${#TENDDATE}" != "$K_DATE_DIGITS" ]]; then
    echo "Incorrect Length: Start or End dates are not correct length"
    exit 1
  fi

  #Set up dates for comparision and trim out the "-"
	Gstart=$(echo $STARTDATE | tr -d '-')
	Gend=$(echo $ENDDATE | tr -d '-')
  Tstart=$(echo $TSTARTDATE | tr -d '-')
  Tend=$(echo $TENDDATE | tr -d '-' )
  # verify if timestamps are within data time range
  if (( $(echo "$Gstart > $Tstart" | bc -l) )) || (( $(echo "$Gend < $Tend" | bc -l) )); then
                echo "ERROR: Incorrect Threshold for start and end date"
                exit 1
  fi

	#Finalizing the spots we want to record for graphing
  STARTDATE="${TSTARTDATE}"
  ENDDATE="${TENDDATE}"

fi

# ensure that graph directory exists
mkdir $GRAPHDIR 2> /dev/null

function graph {
local _outfile="$1"
local _y_format="$2"
local _title="$3"
local _ylabel="$4"
local _dat_file="$5"
local OFFSET="$6"

local _tmp_dat=tmp_data.txt
local _tmp_file=tmp.txt
cp $_dat_file $_tmp_dat # copy to temp for modifying
if [[ "$VERBOSE" == "true" ]];
then
 printf "=== CREATING PLOT: $TITLE\n"
fi
local _plotline="plot "
for i in ${!lines[@]};
do
 if [ "$_plotline" != "plot " ]
 then
   _plotline="$_plotline,"
 fi
 if [[ "$OFFSET" == "true" ]] ; then
	# find columns that need differencing
		local _awk_in="awk -F, '{print \$${lines[$i]}"
		local _awk_in="$_awk_in; exit}' ${_dat_file}"
		eval $_awk_in > $_tmp_file
		offset=$(cat $_tmp_file)
	# awk to find the first value in each column
		local _awk_in2="awk -F, '{OFS = \",\"; (\$${lines[$i]}=\$${lines[$i]}-$offset)\"\$\"; print}' $_tmp_dat > $_tmp_file"
		eval $_awk_in2
		mv $_tmp_file $_tmp_dat
	# awk to subtract the first value from all other values
  _plotline="$_plotline '${_tmp_dat}' using 1:${lines[$i]} w linespoints title '$i'"
 else
  _plotline="$_plotline '${_dat_file}' using 1:${lines[$i]} w linespoints title '$i'"
 fi

done

# generate plot and save as $_outfile
gnuplot <<- EOF
 set datafile separator ','
 set xdata time
 set timefmt '%d-%H-%M-%S'
 set xrange ['${STARTDATE}':'${ENDDATE}']
 set format x '%d-%H-%M-%S.%6N'
 set xtics rotate by 60 right
 set term png
 set xlabel 'Timestamp'
 set ytics format '${_y_format}'
 set output "${_outfile}"
 set title '${_title}'
 set ylabel '${_ylabel}'
 ${_plotline}
EOF

# remove files if they exist
rm -f $_tmp_dat
rm -f $_tmp_file

}

LINE1_FILE=$GRAPHDIR/line1.png
rm -f $LINE1_FILE
# Interfaces Graphs
NUMINTERFACES=$(head -n 1 ${IFACE_FILE} | awk --field-separator="," "{ print NF }")
NUMINTERFACES=$((($NUMINTERFACES-2)/3 ))
for i in $(seq 1 $NUMINTERFACES);
do
IND=$((3*$i-1))
INTERFACE=$(head -n 1 ${IFACE_FILE} | awk -F "," -v ind=$IND '{print $ind}')
OUTFILE="$GRAPHDIR/plot_${INTERFACE}.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="${INTERFACE}"
YLABEL="Packets"
DATAFILE=$IFACE_FILE
OFFSET="true"
declare -A lines=( ["RX"]=$(($IND+1)) ["TX"]=$(($IND+2)))
graph $OUTFILE $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines
if [ -f $LINE1_FILE ]
then
  gm convert +append $OUTFILE $LINE1_FILE $LINE1_FILE
else
  mv $OUTFILE $LINE1_FILE
fi
done

# Memory Graph
MEM_PNG="$GRAPHDIR/plot_mem.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="RAM_Usage"
YLABEL="RAM"
DATAFILE=${MEM_FILE}
OFFSET="false"
declare -A lines=(["MemFree"]=3)
graph $MEM_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# SDA IO Graph
IO_WAIT_PNG="$GRAPHDIR/plot_wait_steal.png"
YTICS_FORMAT="%.2f"
PLOT_TITLE="IO_%_Wait_and_Steal"
YLABEL="Percentage"
DATAFILE=$IO_FILE
OFFSET="false"
declare -A lines=(["wait"]=4 ["steal"]=5)
graph $IO_WAIT_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# SDA IO Graph
IO_RW_PNG="$GRAPHDIR/plot_io_rw.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="SDA_r/w_Bandwidth"
YLABEL="kB_per_sec"
DATAFILE=$IO_FILE
OFFSET="false"
declare -A lines=(["read"]=2 ["write"]=3)
graph $IO_RW_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# VMSTAT System Graph
VM_SYS_PNG="$GRAPHDIR/plot_vm_sys.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="VMSTAT_System"
YLABEL="number_per_sec"
DATAFILE=$VMSTAT_FILE
OFFSET="false"
declare -A lines=(["interrupts_per_sec"]=2 ["context_switches"]=3)
graph $VM_SYS_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# VMSTAT CPU Graph
VM_CPU_PNG="$GRAPHDIR/plot_vm_cpu.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="VMSTAT_CPU"
YLABEL="time"
DATAFILE=$VMSTAT_FILE
OFFSET="false"
declare -A lines=(["non-kernel"]=4 ["kernel"]=5 ["idle"]=6 ["io_wait"]=7 ["stolen_from_vm"]=8)
graph $VM_CPU_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# IP Graph
IP_PNG="$GRAPHDIR/plot_ip.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="IP_Packets"
YLABEL="Packets"
DATAFILE=$IP_FILE
OFFSET="true"
declare -A lines=(["sent"]=2 ["recvd"]=3)
graph $IP_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

#UDP Graph
UDP_PNG="$GRAPHDIR/plot_udp.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="UDP_Segments"
YLABEL="Segments"
DATAFILE=$UDP_FILE
OFFSET="true"
declare -A lines=(["sent"]=2 ["recvd"]=3)
graph $UDP_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

#TCP Graph
TCP_PNG="$GRAPHDIR/plot_tcp.png"
YTICS_FORMAT="%.0f"
PLOT_TITLE="TCP_Packets"
YLABEL="Packets"
DATAFILE=$TCP_FILE
OFFSET="true"
declare -A lines=(["sent"]=2 ["recvd"]=3)
graph $TCP_PNG $YTICS_FORMAT $PLOT_TITLE $YLABEL $DATAFILE $OFFSET $lines

# create dashboard by combining pngs
pushd $GRAPHDIR > /dev/null
gm convert $MEM_PNG $IO_RW_PNG $IO_WAIT_PNG +append line2.png
gm convert $IP_PNG $TCP_PNG $UDP_PNG $VM_SYS_PNG $VM_CPU_PNG +append line3.png
gm convert -append line1.png line2.png line3.png dashboard.png
rm -f line*.png
popd > /dev/null
printf "=== CREATING DASHBOARD: $DASHBOARD_NAME\n"
mv $GRAPHDIR/dashboard.png $DASHBOARD_NAME
#rm -rf $GRAPHDIR
