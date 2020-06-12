#!/bin/bash

## $Header: $
## Source:
## @file cfg/provision/inc/requires.h.sh

## @brief This header file contains limits for timeouts for requirements to be checked

declare -x REQUIREMENT_RETRY_LIMIT=20
declare -x REQUIREMENT_RETRY_SLEEP=3
