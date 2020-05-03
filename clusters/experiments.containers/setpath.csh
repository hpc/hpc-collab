#!/bin/csh

set provisionbin=cc/cfg/provision/bin
set PWD=`pwd`

set present=""
foreach p ($path)
  if ( "${p}" == "${provisionbin}" )  then
    present=true
  endif
end
if ( "${present}" != "true" ) then
  switch ($PATH)
    case *${provisionbin}*:
  	breaksw
  default:
	set path=($path $PWD/${provisionbin})
	breaksw
  endsw
endif

