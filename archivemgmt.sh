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



# Script below do not edit
set -euo pipefail
IFS=$',\n\t'
DEBUG=${1:-0}
AWK=`which awk`
CAT=`which cat`
TAR=`which tar`
BZIP2=`which bzip2`
DATE=`which date`
SHA512SUM=`which sha512sum`




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
				debugecho "***DEBUG: Processing directory $DAY"
				DATADATE=`echo $YEAR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $MONTH | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $DAY | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
				debugecho "***DEBUG: Processing date: $DATADATE"

				# process zdata files if found (if not probably archived already)
				set +e
				ZCOUNT=$(ls "$DAY"/zdata_* 2> /dev/null | wc -l)
				set -e
				updated=0
				#if there's zdata (already archived) and it's not todays date (incomplete data), then archvie it
				nowtime=$($DATE -u +"%s")
				datatime=$($DATE -u -d "$DATADATE" +"%s")
				archivedelay=$(($nowtime-$datatime))
				debugecho "***DEBUG: archivedelay=$archivedelay" 
				if [ $ZCOUNT -ne 0 ]; then if [ $archivedelay -gt 86400 ]; then
					for ZDATA in $DAY/zdata_*; do
						debugecho "***DEBUG: Processing: $ZDATA"
						$AWK -F" " '$1=="#TS:" { print $2","strftime("%c",strtonum("0x"$2),1); }' "$ZDATA" >> "$DAY"/timestamps.lst.tmp
						$AWK -F" " '$1=="U" { a[$7]++ } END { for (b in a) {print b} }' "$ZDATA" | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1=="U" { a[$2]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1=="U" { a[$3]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1=="U" { a[$6]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/serverports.lst.tmp
						updated=1
					done

					if [ $updated -ne 0 ]; then
						# de-dupe data files
						for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst; do
							$AWK '!seen[$0]++' "$DAY"/$file.tmp > "$DAY"/$file
							rm "$DAY"/$file.tmp
						done
					fi

					# archive it all
					ARCNAME=$AMDNAME-$DATADATE.tar.bz2
					$TAR -cjf "$MONTH"/$ARCNAME "$DAY"/* >&2
					if [ $? -eq 0 ]; then
						#succesful, checksum the archive and clean up data files
						$SHA512SUM $MONTH/$ARCNAME > $MONTH/$ARCNAME.sha512
						chmod -w $MONTH/$ARCNAME $MONTH/$ARCNAME.sha512
						rm -f "$DAY"/*data_* "$DAY"/vdataidx_* "$DAY"/page2transmap_*
					else
						#failed
						echo -e "\e[33m***WARNING:\e[0m Couldn't archive data files in: $DAY, will try again next time."
					fi
				else
					debugecho "***DEBUG: $DATADATE = today, not archiving yet."
				fi
				else
					if [ ! -r "$DAY/softwareservice.lst" ]; then
						debugecho "\e[33m***WARNING:\e[0m No zdata files in: $DAY."
					else
						debugecho "***DEBUG: Already archived: $DAY"
					fi
				fi

			done
		done 
	done
done

echo -e "rtmarchive Archive Management Script"
echo -e "Complete"



