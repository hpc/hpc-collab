# Current Issues/To Dos

Below is a list of known issues

##  logging.sh & populateLogs.sh

* monitoring on the same machine more than once may cause them to get clobbered
		* this may be fixed already, but needs testing

## main.sh

* does not throw error when provisioning fails, will continue running forever

## collectVCData.sh

* scp to all nodes regardless if they are up or not. fix: use show to determine if node is up, then scp if true.

## graph.sh

* if data is not in correct format, it will not display proper error
* incorrect command line args will still execute, just with incorrect behavior
* add functionality to skip first values for vmstat system and vmstat cpu

## vcJob.sh

* waits for only the last node to finish monitoring, should check for all nodes to finish before grabbing data

## Overall

* watch out for system-specific folder references. Hard coded locations for virtual machine filesystems
* scripts are referenced within other scripts as stand-alone units, not specific functions as in most object oriented frameworks. This is not a problem, just a note.

## Nice to haves

* better logging functionality. Logging is currently in terms of echos & printfs instead of a framework
