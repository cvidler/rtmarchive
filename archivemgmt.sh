#!/bin/bash
# rtmarchive management script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process and compress downloaded AMD archive data.
#
#

# Config
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=~/rtmarchive
AWK=`which awk`

# Script below do not edit

#list contents of BASEDIR for 
for DIR in "$BASEDIR"/*; do
	# only interested if it's got AMD data in it (check for UUID file)
	if [ -r "$DIR/uuid.lst" ]; then
		AMDNAME=`echo $DIR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
		echo "Processing AMD: $AMDNAME"
		
		# recurse year/month/day directory structure
		# list all data files moving them into date based subfolders
		while read YEAR ; do
			while read MONTH ; do
				while read DAY ; do
					if [ "`echo ${file} | $AWK ' /[a-z0-9]+_[0-9a-f]+_[15oa]+_[tb]/ '`" == "${file}" ]; then
						#process files	
					fi
				done < <(ls -1 $DIR/$YEAR/$MONTH)
			done < <(ls -1 $DIR/$YEAR)
		done < <(ls -1 $DIR)
	fi
done


