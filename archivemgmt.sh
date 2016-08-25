#!/usr/bin/env bash
# rtmarchive management script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process and compress downloaded AMD archive data.
#
#

# Config
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=/opt/rtmarchive
MAXTHREADS=4
DEBUG=0




# Script below do not edit
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
CAT=`which cat`
TAR=`which tar`
BZIP2=`which bzip2`
DATE=`which date`
SHA512SUM=`which sha512sum`
JOBS=`which jobs`
WC=`which wc`

# command line arguments
OPTS=1
while getopts ":dhb:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		b)
			BASEDIR=$OPTARG
			;;
		\?)
			OPTS=0 #show help
			echo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			echo "*** FATAL: argument -$OPTARG requires parameter."
			;;
	esac
done

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-b basearchivedir]"
	echo -e "-h This help. Optional"
	echo -e "-b basearchivedir Archive directory path. Optional. Default: $BASEDIR"
	exit 0
fi



function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then echo -e "*** DEBUG[$dbglevel]: $1"; fi
}

echo -e "rtmarchive Archive Management Script"
echo -e "Starting"

#list contents of BASEDIR for 
for DIR in "$BASEDIR"/*; do
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	(
	# only interested if it has got AMD data in it
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
				# if there is zdata (already archived) and it is not todays date (incomplete data), then archvie it
				nowtime=$($DATE -u +"%s")
				datatime=$($DATE -u -d "$DATADATE" +"%s")
				archivedelay=$(($nowtime-$datatime))
				debugecho "***DEBUG: archivedelay=$archivedelay" 
				if [ $ZCOUNT -ne 0 ]; then if [ $archivedelay -gt 86400 ]; then
					for ZDATA in $DAY/zdata_*; do
						debugecho "***DEBUG: Processing: $ZDATA", 2
						# Grab timestamp from zdata contents (doesn't work on HS AMD zdata, so disabling)
						#$AWK -F" " '$1=="#TS:" { print $2", "strftime("%c",strtonum("0x"$2),1); }' "$ZDATA" >> "$DAY"/timestamps.lst.tmp
						# Grab timestamp from file name						
						`echo $ZDATA | $AWK -F"_" ' { print strftime("%F %T",strtonum("0x"$2),1); }' >> "$DAY"/timestamps.lst.tmp`
						# grab version from non HS AMD zdata						
						$AWK -F" " '$1=="V" { printf("%s.%s.%s.%s", $2,$3,$4,$5) }' "$ZDATA" >> "$DAY"/versions.lst.tmp
						# grab version from HS AMD zdata
						$AWK -F" " '$1=="#Producer:" { sub("ndw.","" , $2); print $2 }' "$ZDATA" >> "$DAY"/versions.lst.tmp 
						$AWK -F" " '$1 ~/^[Uh]/ { a[$7]++ } END { for (b in a) {print b} }' "$ZDATA" | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$2]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$3]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$6]++ } END { for (b in a) {print b} }' "$ZDATA" >> "$DAY"/serverports.lst.tmp
						updated=1
					done

					if [ $updated -ne 0 ]; then
						# de-dupe and sort list files
						for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst versions.lst; do
							chmod +w "$DAY"/$file
							$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$DAY"/$file.tmp > "$DAY"/$file
							chmod -w "$DAY"/$file
							rm "$DAY"/$file.tmp
						done
					fi

					# archive it all
					ARCNAME=$AMDNAME-$DATADATE.tar.bz2
					if [ ! -w $ARCNAME ]; then
						echo -e "\e[33m***WARNING:\e[0m Archive [$ARCNAME] already exists or can't write, skipping."
						continue
					fi
					$TAR -cjf "$MONTH"/$ARCNAME -C "$DAY" . >&2
					if [ $? -eq 0 ]; then
						#succesful, checksum the archive and clean up data files
						$SHA512SUM $MONTH/$ARCNAME > $MONTH/$ARCNAME.sha512
						chmod -w $MONTH/$ARCNAME $MONTH/$ARCNAME.sha512
						rm -f "$DAY"/*data_* "$DAY"/vdataidx_* "$DAY"/page2transmap_*
						rm -rf "$DAY"/conf
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
	echo -e "Processing AMD: $AMDNAME complete."
	) &	
done; wait

echo -e "rtmarchive Archive Management Script"
echo -e "Complete"



