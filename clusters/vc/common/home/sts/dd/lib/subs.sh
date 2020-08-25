#!/bin/bash
# vim: background=dark

set -o errexit

set -o pipefail
set -o nounset

PATH=${PATH}:$(realpath ../bin)

LOGDIR=$(realpath ../logs)
TSTAMP=$(date +%y%m%d.%H%M)
PWD=$(pwd)
IAM=$(basename ${PWD})
JOBNAME=${IAM}-
TSTAMP=$(date +%y%m%d.%H%M)

QSTATS_PARAMETERS="-V -c -b -B -P -R"
QSTATS_STDOUT_PARAMETERS="-D ${QSTATS_PARAMETERS}"

prepOut() {
  mkdir -p ${LOGDIR}/${TSTAMP}
  touch "${LOGDIR}/${TSTAMP}/${IAM}"
}

dumpStats() {
  logger -t "${IAM}" -- "dump queue stats: begin"
  echo "Output: ${LOGDIR}/${TSTAMP}/${IAM}"
  qstats.sh ${QSTATS_STDOUT_PARAMETERS} | tee ${LOGDIR}/${TSTAMP}/${IAM}
  qstats.sh ${QSTATS_PARAMETERS}
  logger -t "${IAM}" -- "dump queue stats: end"
}

checkIdle() {
  queueLength=$(squeue --noheader | wc -l)
  if [ ${queueLength} -ne 0 ] ; then
    echo "Queue is not idle; queue length=${queueLength}" | tee "${LOGDIR}/${TSTAMP}/${IAM}"
  fi
}

ensureIdle() {
  queueLength=$(squeue --noheader | wc -l)
  if [ ${queueLength} -ne 0 ] ; then
    sleep ${TIMEOUT:-2}
  fi
}



