#!/bin/bash

if [ -f /.docker.env ] ; then
  export VAGRANT_DEFAULT_PROVIDER=${VAGRANT_DEFAULT_PROVIDER:-docker}
fi
