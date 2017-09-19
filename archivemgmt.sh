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
MAXTHREADS=$(($(nproc)*1))
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
AMDNAME=""

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
			techo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			techo "*** FATAL: argument -$OPTARG requires parameter."
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
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`][$AMDNAME]: $1" 
}

tstart=`date -u +%s`
techo "rtmarchive Archive Management Script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2016"
techo "Starting"

pidfifo=$(mktemp --dry-run)
mkfifo --mode=0700 $pidfifo
exec 3<>$pidfifo
rm -f $pidfifo
running=0
debugecho "MAXTHREADS: [$MAXTHREADS]"

#list contents of BASEDIR for 
for DIR in "$BASEDIR"/*; do

	while (( running >= $MAXTHREADS )) ; do
		if read -u 3 cpid ; then
			wait $cpid
			(( --running ))
		fi
	done
	debugecho "running threads: [$running]"

	(
	echo $BASHPID 1>&3
	# only interested if it has got AMD data in it
	if [ ! -r "$DIR/prevdir.lst" ]; then continue; fi
	AMDNAME=`echo $DIR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
	techo "Processing AMD: $AMDNAME"
	
	# recurse year/month/day directory structure
	for YEAR in "$DIR"/*; do
		if [ ! -d "$YEAR" ]; then continue; fi
		for MONTH in "$YEAR"/*; do
			if [ ! -d "$MONTH" ]; then continue; fi
			for DAY in "$MONTH"/*;  do
				if [ ! -d "$DAY" ]; then debugecho "Skipping non-folder [$DAY]", 3; continue; fi
				if [[ ${DAY} =~ DDD[0-9]+$ ]]; then debugecho "skipping folder in delete phase [$DAY]", 2; continue; fi

				debugecho "Processing directory DAY: [$DAY]" 2
				DATADATE=`echo $YEAR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $MONTH | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $DAY | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
				debugecho "Processing date: DATADATE: [$DATADATE]" 2

				# process zdata files if found (if not probably archived already)
				ZCOUNT=0
				set +e
				ZCOUNT=$(ls "$DAY"/zdata_* 2> /dev/null | wc -l)
				set -e
				updated=0
				# if there is zdata (already archived) and it is not todays date (incomplete data), then archvie it
				nowtime=$($DATE -u +"%s")
				datatime=$($DATE -u -d "$DATADATE" +"%s")
				archivedelay=$(($nowtime-$datatime))
				debugecho "archivedelay: [$archivedelay] seconds" 2
				if [ $ZCOUNT -ne 0 ]; then if [ $archivedelay -gt 86400 ]; then

					# check for existing archive, skip if found - don't want to overwrite archived data.
					ARCNAME=$AMDNAME-$DATADATE.tar.bz2
					if [ ! -w "$MONTH"/$ARCNAME ] && [ -f "$MONTH"/$ARCNAME ]; then
						techo "\e[33m***WARNING:\e[0m Archive [$MONTH/$ARCNAME] already exists or can't write, skipping."
						continue
					fi

					debugecho "Processing: ZDATA: [$DAY/zdata_*]"
					ESCDIR=$(printf '%q' "$DAY")
					debugecho "ESCDIR: [$ESCDIR]" 2		

					#test available file types
					ZDATA=0; VOLDATA=0; IPDATA=0; NDATA=0
					set +e
					ZDATA=$(ls -1 "$DAY"/zdata_*_t 2> /dev/null | wc -l)
					VOLDATA=$(ls -1 "$DAY"/zdata_*_t_vol 2> /dev/null | wc -l)
					IPDATA=$(ls -1 "$DAY"/zdata_*_t_ip 2> /dev/null | wc -l)
					NDATA=$(ls -1 "$DAY"/ndata_*_t_rtm 2> /dev/null | wc -l)
					set -e
					debugecho "ZDATA: [$ZDATA], VOLDATA: [$VOLDATA], IPDATA: [$IPDATA], NDATA: [$NDATA]" 1

					# grab version from non HS AMD zdata						
					if [ $ZDATA -ne 0 ]; then $AWK -F" " '$1=="V" { printf("%s.%s.%s.%s", $2,$3,$4,$5) }' "$DAY"/zdata_*_t >> "$DAY"/versions.lst.tmp; fi
					# grab version from HS AMD zdata
					if [ $VOLDATA -ne 0 ]; then $AWK -F" " '$1=="#Producer:" { sub("ndw.","" , $2); print $2 }' "$DAY"/zdata_*_t_vol >> "$DAY"/versions.lst.tmp; fi

					#grab server/client/port details from zdata 'U' and 'h' records
					if [ $ZDATA -ne 0 ]; then
						FILEEXT="$DAY/zdata_*_t"
						$AWK -F" " '$1 ~/^[Uh]/ { a[$7]++ } END { for (b in a) {print b} }' $FILEEXT | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$2]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$3]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$6]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverports.lst.tmp
					fi
					if [ $VOLDATA -ne 0 ]; then
						FILEEXT="$DAY/zdata_*_t_vol"
						$AWK -F" " '$1 ~/^[Uh]/ { a[$7]++ } END { for (b in a) {print b} }' $FILEEXT | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$2]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$3]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$6]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverports.lst.tmp
					fi
					if [ $IPDATA -ne 0 ]; then
						FILEEXT="$DAY/zdata_*_t_ip"
						$AWK -F" " '$1 ~/^[Uh]/ { a[$7]++ } END { for (b in a) {print b} }' $FILEEXT | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$2]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$3]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1 ~/^[Uh]/ { a[$6]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverports.lst.tmp
					fi

					#grab server/client/port details from ndata
					if [ $NDATA -ne 0 ]; then
						#ndata 'C' record is a little different, handle appropriately
						FILEEXT="$DAY/ndata_*_t_rtm"
						$AWK -F" " '$1 ~/^[C]/ { a[$5]++ } END { for (b in a) {print b} }' $FILEEXT | 
							$AWK -vRS='%[0-9a-fA-F]{2}' 'RT{sub("%","0x",RT);RT=sprintf("%c",strtonum(RT))}{gsub(/\+/," ");printf "%s", $0 RT}' >> "$DAY"/softwareservice.lst.tmp
						$AWK -F" " '$1 ~/^[C]/ { a[$2]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverips.lst.tmp
						$AWK -F" " '$1 ~/^[C]/ { a[$3]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/clientips.lst.tmp
						$AWK -F" " '$1 ~/^[C]/ { a[$4]++ } END { for (b in a) {print b} }' $FILEEXT >> "$DAY"/serverports.lst.tmp
					fi


					# Grab timestamp from file name			
					ls -1 $FILEEXT | $AWK -F"_" ' { print strftime("%F %T",strtonum("0x"$2),1); }' >> "$DAY"/timestamps.lst.tmp
					updated=1

					if [ $updated -ne 0 ]; then
						# de-dupe and sort list files
						for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst versions.lst; do
							if [ -f "$DAY"/$file ]; then chmod +w "$DAY"/$file; fi
							$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$DAY"/$file.tmp > "$DAY"/$file
							chmod -w "$DAY"/$file
							rm "$DAY"/$file.tmp
						done
					fi

					# archive it all
					techo "Compressing $DAY"
					$TAR -cjf "$MONTH"/$ARCNAME -C "$DAY" . >&2
					if [ $? -eq 0 ]; then
						#succesful, checksum the archive and clean up data files
						$SHA512SUM $MONTH/$ARCNAME > $MONTH/$ARCNAME.sha512
						chmod -w $MONTH/$ARCNAME $MONTH/$ARCNAME.sha512
						#rm -f "$DAY"/*data_* "$DAY"/vdataidx_* "$DAY"/page2transmap_*
						#rm -rf "$DAY"/conf
						DDAY=${MONTH}/DDD${DAY##*/}
						debugecho "DDAY: [$DDAY]", 2
						mv "$DAY" "$DDAY"
						mkdir -p "$DAY"
						cp "$DDAY"/*.lst "$DAY"
						EDIR=`mktemp -d`
						rsync -a --delete "$EDIR/" "$DDAY/"
						rm -rf "$DDAY"
						rm -rf "$EDIR"
					else
						#failed
						techo "\e[33m***WARNING:\e[0m Couldn't archive data files in: $DAY, will try again next time."
					fi
				else
					debugecho "DATADATE: [$DATADATE] = today, not archiving yet."
				fi
				else
					#no zdata files found, test to see if truely empty, or already archived.
					if [ ! -r "$DAY/softwareservice.lst" ]; then
						debugecho "\e[33m***WARNING:\e[0m No zdata files in: DAY: [$DAY]." 2
					else
						debugecho "Already archived: DAY: [$DAY]" 2
					fi
				fi

			done
		done 
	done
	techo "Processing AMD: $AMDNAME complete."
	) &	
	(( ++running ))

	if [ $? -ne 0 ]; then
		techo "\e[33m***WARNING:\e[0m $AMDNAME failed archive management."
	fi
done
wait

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "rtmarchive Archive Management Script"
techo "Completed in $tdur seconds"



