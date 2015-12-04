#!/bin/bash
# rtmarchive management script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process and compress downloaded AMD archive data.
#
#

# Config
export BASEDIR=/var/spool/rtmarchive
export SCRIPTDIR=~/rtmarchive
export AWK=`which awk`

# Script below do not edit

#list contents of BASEDIR for 
for DIR in $BASEDIR/*; do
	# only interested if it's got AMD data in it (check for UUID file)
	if [ -r $DIR/uuid.lst ]; then
		export AMDNAME=`echo $DIR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
		echo $AMDNAME
		
	fi
done


