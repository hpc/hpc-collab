#!/usr/bin/python3

"""
This script pokes the pending jobs in the queue so that they will update 
themselves, made in particular to update the Reason field.
Can be run manually or by a separate mechanism (interstate, cron, etc).
"""

from subprocess import getstatusoutput

# get list of jobs to poke
# pending jobs not with Resources or Priority reason
cmd = "squeue -t PD -O JobId,Reason -h | grep -Ev '(Resources|Priority)' | awk '{ print $1 }'"
rc, out = getstatusoutput(cmd)
if (rc !=0):
    print("Error getting jobid's from squeue!")
    print(out)

jobids=out.splitlines()

# loop through jobids
for job in jobids:
    # verify ExcNodeList is null
    cmd = "scontrol show job %s | grep -Po 'ExcNodeList=\K.*'"%(job)
    rc, out = getstatusoutput(cmd)
    if (rc !=0):
        print("Error getting ExcNodeList from scontrol!")
        print(out)
    if (out != "(null)"): # ExcNodeList is populated
        # poke job and preserve ExcNodeList
        cmd = "scontrol update job %s ExcNodeList=%s"%(job,out)
        rc, out = getstatusoutput(cmd)
        if (rc !=0):
            print("Error setting preserved ExcNodeList from scontrol!")
            print(out)
    else :
        # poke job
        cmd = 'scontrol update job %s ExcNodeList=""'%(job)
        rc, out = getstatusoutput(cmd)
        if (rc !=0):
            print("Error setting ExcNodeList from scontrol!")
            print(out)      

print("Pending jobs have been poked")