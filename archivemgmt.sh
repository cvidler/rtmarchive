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
DEBUG=${1:-0}
AWK=`which awk`
CAT=`which cat`
TAR=`which tar`
BZIP2=`which bzip2`
DATE=`which date`
MD5SUM=`which md5sum`

#DEBUG=1



# Script below do not edit
set -euo pipefail
IFS=$',\n\t'

function debugecho {
        if [ $DEBUG -ne 0 ]; then echo -e "$@"; fi
}


echo -e "rtmarchive Archive Management Script"
echo -e "Starting"

#list contents of BASEDIR for 
for DIR in "$BASEDIR"/*; do
	# only interested if it's got AMD data in it
	if [ ! -r "$DIR/prevdir.lst" ]; then continue; fi
	AMDNAME=`echo $DIR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
	echo -e "Processing AMD: $AMDNAME"
	
	# recurse year/month/day directory structure
	for YEAR in "$DIR"/*; do
		if [ ! -d "$YEAR" ]; then continue; fi
		for MONTH in "$YEAR"/*; do
			if [ ! -d "$MONTH" ]; then continue; fi
			for DAY in "$MONTH"/*;  do
				if [ ! -d "$DAY" ]; then continue; fi
				debugecho "$DAY"
				DATADATE=`echo $YEAR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $MONTH | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $DAY | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
				debugecho "$DATADATE"

				# process zdata files if found (if not probably archived already)
				set +e
				ZCOUNT=$(ls $DAY/zdata_* 2> /dev/null | wc -l)
				set -e
				updated=0
				if [ $ZCOUNT -ne 0 ]; then 
					for ZDATA in $DAY/zdata_*; do
						debugecho $ZDATA
						$AWK -F" " '$1=="U" { a[$7]++ } END { for (b in a) {print b} }' $ZDATA >> $DAY/softwareservice.lst.tmp
						$AWK -F" " '$1=="U" { a[$2]++ } END { for (b in a) {print b} }' $ZDATA >> $DAY/serverips.lst.tmp
						$AWK -F" " '$1=="U" { a[$3]++ } END { for (b in a) {print b} }' $ZDATA >> $DAY/clientips.lst.tmp
						$AWK -F" " '$1=="U" { a[$6]++ } END { for (b in a) {print b} }' $ZDATA >> $DAY/serverports.lst.tmp
						updated=1
					done

					if [ $updated -ne 0 ]; then
						# de-dupe data files
						for file in softwareservice.lst serverips.lst clientips.lst serverports.lst; do
							$AWK '!seen[$0]++' $DAY/$file.tmp > $DAY/$file
							rm $DAY/$file.tmp
						done
					fi

					# archive it all, if not todays data (assumes incomplete, finish it tomorrow)
					if [ `$DATE +%Y%m%d` -gt `$DATE -d $DATADATE +%Y%m%d` ]; then 
						ARCNAME=$AMDNAME-$DATADATE.tar.bz2
						$TAR -cjf $MONTH/$ARCNAME $DAY/* >&2
						if [ $? -eq 0 ]; then
							#succesful
							$MD5SUM $MONTH/$ARCNAME > $MONTH/$ARCNAME.md5
							rm -f $DAY/*data_* $DAY/page2transmap_*
						else
							#failed
							echo -e "\e[33m***WARNING:\e[0m Couldn't archive data files in: $DAY, will try again next time."
						fi
					else
						debugecho "$DATADATE = today, not archiving"
					fi
				else
					debugecho "\e[33m***WARNING:\e[0m No zdata files in: $DAY."
				fi

			done
		done 
	done
done

echo -e "rtmarchive Archive Management Script"
echo -e "Complete"



