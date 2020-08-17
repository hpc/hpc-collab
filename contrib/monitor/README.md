# A Virtual Cluster Monitoring Toolkit for Bottleneck Analysis
### Date: 7/29/2020
### Created By:
   - Natasha Frumkin
   - Christian Marquardt (Cmarquardt17)

## Introduction:

The goal of this project is to monitor virtualized computing clusters and detect potential bottlenecks. In particular we are looking at a computing cluster called hpc-collab which the github repo is referenced below. On this cluster have 10 different nodes that different jobs to completely provision the cluster. Our goal is to collect useful metrics during the provisioning process such as network traffic, IO patterns, and memory usage.

## What's Featured?

  - Easy to see file hierarchy with a main script that runs all other scripts
  - Well documented scripts
  - Use of getopts for easier standard input into the script files
  - Utilization of visual graphs over a certain timeframe
  - Benchmark tools widely used across compute systems
        - iostat
        - netstat
        - /proc/meminfo (Looking at MEMFREE and MEMAVAIL)
        - Finding the top 3 processes
				- mpstat
				- vmstat

## What is still ongoing?
- We are still trying to implement more benchmarking tools and compare to tools that are already being used
    - bonnie++
    - linpack
    - collectd
    - sar
    - df
- A look into comparing using VirtualBox and Libvert
    - Which one reduces provisioning time?
    - Which one has better performance?
    - What one is better to use for later implementation?
- Transitioning over to a containerized environment
    - Do the drawbacks of containers hold back the goal this cluster is trying to achieve?
        - And if it doesn't?
- Would we see similar monitoring on a larger cluster with many more nodes?
- There are still areas that we need to cover with monitor that could potentially have bottlenecks

## How to run?
This is ran by going into the home directory this is in and going to test-hpc-collab-monitor and executing `./main.sh -n $NODE -t $MONITORMINS -i $ITERATIONS`. Afterwards, you will see that the graphs that were created will be located in the latest timestamp(s) you created and you can scp yourself to your local workspace.

- `$NODE`: Means which node you want to reprovision up to
- `$MONITORMINS`: The total amount of time you want to monitor on the host. It is recommended to put atleast 120 minutes to get good data
- `$ITERATIONS`: How many times you want to conduct the reprovisioning set in the last two options
- Note: `-h` will give you more clarity if need be
## What does each folder mean?

#### benchmarks
- This is where benchmark scripts can be put and so far we only have STREAM. Ideally more would go in here given more time.

#### monitor
- This is where our two main monitoring scripts are and get rysynced to the useradd directory for the nodes to gets these scripts. This can be ran on host as well so you are measuring the physical host aside from the virtual nodes.

#### provision-outputs
- Everytime there is a provision an .out file is created telling you where it is at and if there was any errors during the provisioning. Something nice is you can tail -f vcgat.out so you can see realtime outputs. This file is used to create the timestamps.txt for creating indepth graphs.
#### collect-and-visualize
- This is where all of the children scripts are for main.sh. These can all run independant from eachother if need be especially for debugging and the need to not reprovision.

## What does each script mean?

#### main.sh
- This is our parent script that eexecutes children scrips discussed below when it is their turn.
It is good to note that you can pass in arguments or not. If you dont it will automatically full reprovision one time for 140 minutes. Whereas you can e.g (./main.sh -n vc1 -m 100 -i 2) which means reprovision up to vc1 and monitor for 100 minutes and do this twice

#### collect-and-visualize/vcJob.sh
- This is the first child script that is being executed within main.sh where our main data collecting files are updated using rsync (logging.sh and populate.sh) we then direct to setInputMins.sh to pass to each node how long their own monitoring script should monitor and this is pushed to a text file that is read on the node. In here we also start monitoring on host as well. Will also notify when monitoring is done on guest and host

#### collect-and-visualize/collectVCData.sh
- The second child scripts executes when vcJob is done and all monitoring has seized. We then pull from each node their latest logs folder and push it onto the hosts /tmp so we can directly manipulate it. We also create graphs from graph.sh by passing in the the node data for each node. A .png is made. This is also done on host as well.

#### collect-and-visualize/multiTimestampGraph.sh
- Lastly we have our final child script and this is for a closer look at the processes happening within the provision within a specific node. The start, finish, and description are stored in a timestamps.txt that is tabbed by value which can be found in data/{latest one}. We then use the graph.sh to graph each one of these. Once this is complete the main.sh should be done.

#### collect-and-visualize/graph.sh
- This core script does all the visualization using gnuplot and graphMagik by grabbing directories and making sure the timestamps are correctly in line so a graph can be created. Currently the process that has happened is when the graphs are made and are within the data/{TIMESTAMP} along with timestamps.txt you must scp that directory to make it easier on yourself. One nice thing would be to automate this so the graphs get pulled to your personal workspace as you can look at them on the virtual cluster.

#### collect-and-visualize/setInputMins.txt
- This is a small script that sets the minutes of monitoring for each node before it gets pushed to the node.

#### monitor/logging.sh
- This script discated how long monitoring will happen and what type of monitoring. This is automated when using main.sh but you can use this on its own by typing in ./logging -e 3 -t 4 and this means monitor for 4 minutes and then terminate or terminate by keypress. -e 1 means to die only on keypress and -e 2 is to die only when the time is over. This runs populateLogs.sh in the background where all the meat is for monitoring the cluster with tools. This wait for a file to be terminated in /tmp so it knows populateLogs.sh is done and it can end as well.

#### monitor/populateLogs.sh
- This one runs for how ever long logging.sh was set to and saves the tools data every 30 seconds to its logs directory via an array. All files that have data are .txt files and they are that way for graph.sh to easily use and manipulate them. We use vmstat and mpstat on intervals so they had to separate and some exttra lines of code was needed for them to be accurate when pulling the data later on. The rest (iostat, netstat, /proc/meminfo) are ran in the forground of this script even though this script is also in the background. For a better view of processes logging.sh (foreground) > populateLogs.sh (background from logging.sh) > mpstat.data/vmstat.data (background from populateLogs.sh) > collect.data (foreground of populateLogs.sh). Once these are all done we rm the state file showing that this thread is done and logging.sh can finish up.

#### benchmark/benchmark.sh
- This is a benchmark scenario using the tool STREAM on all of the nodes when they are fully provisioned and we monitor for 5 minutes on each one and then we pull all of the data and graph it. Note: STREAM is not copyright nor licensed by LANL.

### Current Conclusion
We have identified major bottlenecks so far in network bandwidth and large overhead from underlying virtualization providers. We were able to prove that neither random IO patterns of guest-to-host layered file systems nor CPU usage are bottlenecks in the provisioning process. With the work that has been done so far the cluster provisiong process has been reduced by 50%.

## References
hpc-collab: [Github](https://github.com/hpc/hpc-collab)

## Governance
This LANL 2020 Summer Institute project and all material contained in and below this directory is governed by LANL LA-UR 20-26030.

License
----
MIT
