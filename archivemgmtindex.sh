#!/bin/bash
# rtmarchive management search indexer script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process the daily data lists from the AMDs and build monthly/yearly lists for search optimisation.
#
#

# Config
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=~/rtmarchive
MAXTHREADS=4


# Script below do not edit
set -euo pipefail
IFS=$',\n\t'
DEBUG=${1:-0}
AWK=`which awk`
CAT=`which cat`
DATE=`which date`
JOBS=`which jobs`
WC=`which wc`
TOUCH=`which touch`


function debugecho {
	if [ $DEBUG -ne 0 ]; then echo -e "$@"; fi
}

echo -e "rtmarchive Archive Search Indexer Script"
echo -e "Starting"

#determine yesterday (UTC)
today=$($DATE -u +"%s")
yesterday=$(($today - 86400))
tgtyear=$($DATE -u -d "@$yesterday" +"%Y")
tgtmonth=$($DATE -u -d "@$yesterday" +"%m")
tgtday=$($DATE -u -d "@$yesterday" +"%d")

#list contents of BASEDIR for 
for AMD in "$BASEDIR"/*; do
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	(
	    # only interested if it has got AMD data in it
	    if [ ! -r "$AMD/prevdir.lst" ]; then continue; fi
	    AMDNAME=`echo $AMD | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
	    echo -e "Processing AMD: $AMDNAME"

		# recurse year/month/day directory structure
	    for YEAR in "$AMD"/*; do
	        if [ ! -d "$YEAR" ]; then continue; fi
			if [ ! $YEAR == $AMD"/"$tgtyear ]; then continue; fi
	        for MONTH in "$YEAR"/*; do
				if [ ! -d "$MONTH" ]; then continue; fi
				if [ ! $MONTH == $YEAR"/"$tgtmonth ]; then continue; fi
				for DAY in "$MONTH"/*;  do
					if [ ! -d "$DAY" ]; then continue; fi
					if [ ! $DAY == $MONTH"/"$tgtday ]; then continue; fi
					#debugecho "***DEBUG: Processing directory $DAY"
					# target year and month, process it

					# concatenate yesterdays list files into months ones (create as needed)
					# then de-dupe and sort list files
					for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst; do
						if [ ! -r "$DAY/$file" ]; then continue; fi
						$TOUCH "$MONTH"/$file
						$CAT "$MONTH/$file" "$DAY/$file" >> "$MONTH/$file.tmp"
						rm -f "$MONTH"/$file
						$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$MONTH"/$file.tmp > "$MONTH"/$file
						chmod -w "$MONTH/$file"
						rm "$MONTH"/$file.tmp
					done

				done

				# concatenate monthly list files into year ones (create as needed)
				# then de-dupe and sort list files
				for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst; do
					if [ ! -r "$MONTH/$file" ]; then continue; fi
					$TOUCH "$YEAR"/$file
					$CAT "$YEAR/$file" "$MONTH/$file" >> "$YEAR/$file.tmp"
					rm -f "$YEAR"/$file
					$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$YEAR"/$file.tmp > "$YEAR"/$file
					chmod -w "$YEAR/$file"
					rm "$YEAR"/$file.tmp
				done

			done
		done
	)
done

