#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/lib/copyright.sh

## @brief This library file contains a function to emit the copyright notice
## @brief so as to comply with the rules of the copyright notice.

COPYRIGHT_LOCATION=$(dirname ${BASH_SOURCE[0]})
INC_DIR=${COPYRIGHT_LOCATION}/../inc
COPYRIGHT_HEADER=${INC_DIR}/copyright.h.sh

## @fn Copyright()
## @return void
## \callgraph
## \callergraph
##
Copyright() {
  if [ ! -d ${COPYRIGHT_LOCATION} ] ; then
    ErrExit ${EX_SOFTWARE} "COPYRIGHT_LOCATION:${COPYRIGHT_LOCATION}"
  fi
  if [ ! -d ${INC_DIR} ] ; then
    ErrExit ${EX_SOFTWARE} "INC_DIR:${INC_DIR}"
  fi
  if [ -z "${COPYRIGHT_HEADER}" ] ; then
    ErrExit ${EX_SOFTWARE} "COPYRIGHT_HEADER empty"
  fi
  if [ ! -f "${COPYRIGHT_HEADER}" ] ; then
    ErrExit ${EX_SOFTWARE} "missing COPYRIGHT_HEADER:${COPYRIGHT_HEADER}"
  fi
  if [ ! -s "${COPYRIGHT_HEADER}" ] ; then
    ErrExit ${EX_SOFTWARE} "empty COPYRIGHT_HEADER:${COPYRIGHT_HEADER}"
  fi

  awk '/@page Copyright/,/^$/' < ${COPYRIGHT_HEADER}			| \
	sed 's/^##[ ]*//'						| \
	sed 's/@page /\
\
/'									| \
	sed 's/<h2>//' | sed 's/<\/h2>/\
/'									| \
	sed 's/<p>/\
/' | sed 's/<\/p>//'							| \
	sed 's/&nbsp;/ /g'
  return
}

