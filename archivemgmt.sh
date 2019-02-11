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
PIDFILE=/tmp/archivemgmt.pid
DEBUG=0
MAXWAITDAYS=8			# How long to wait for an incomplete collection beforce archiving it.
COMPTYPE="bzip2"		# TAR supported compression options bzip2, xz, gzip, compress, lzma, lzop, lzip



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

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u "+%Y-%m-%d %H:%M:%S"`][$AMDNAME][$BASHPID]: $1" 
}

# command line arguments
OPTS=1
TARGETDATE=""
TARGETAMD=""
TYEAR=""
TMONTH=""
TDAY=""
FORCEUPDATE=0
UPDATEARC=0
while getopts ":dhb:u:a:f" OPT; do
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
		a)
			TARGETAMD=$OPTARG
			debugecho "TARGETAMD [$TARGETAMD]"
			;;
		f)
			FORCEUPDATE=1
			;;
		u)
			date --date="$OPTARG" >&2 > /dev/null
			if [ $? -eq 0 ]; then TARGETDATE=$OPTARG; else OPTS=0 ; fi
			debugecho "TARGETDATE [$TARGETDATE]"
			TYEAR=$(date --date="$TARGETDATE" +%Y)
			TMONTH=$(date --date="$TARGETDATE" +%m)
			TDAY=$(date --date="$TARGETDATE" +%d)
			;;
		\?)
			OPTS=0 #show help
			techo "\e[31m***FATAL:\e[0m Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			techo "\e[31m***FATAL:\e[0m argument -$OPTARG requires parameter."
			;;
	esac
done

# check both required options are set
if [ "$TARGETAMD" == "" ] && [ ! "$TARGETDATE" == "" ]; then OPTS=0 ; fi
if [ ! "$TARGETAMD" == "" ] && [ "$TARGETDATE" == "" ]; then OPTS=0 ; fi

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-b basearchivedir] [-u yyyy-mm-dd -a amdname] [-f]"
	echo -e "-h This help. Optional"
	echo -e "-b basearchivedir Archive directory path. Optional. Default: $BASEDIR"
	echo -e "-u yyyy-mm-dd Update the archive for a specific date. Optional, Requires -a amdname"
	echo -e "-a amdname Update the archive for a specific AMD. Optioanl, Requires -u yyyy-mm-dd"
	echo -e "-f Force the update of already archived days, othewise archives are NOT modified. Optional, used with -u and -a"
	exit 0
fi

if [ ! -r $BASEDIR ]; then techo "\e[31m***FATAL:\e[0m Archive directory ($BASEDIR) not valid or not readable. Aborting."; exit 255; fi

tstart=`date -u +%s`
techo "rtmarchive Archive Management Script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2016"
techo "Starting"

if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	techo "\e[31m***FATAL:\e[0m archivemgmt script already running pid: `cat $PIDFILE`. Aborting."
	exit 1
fi


#prepare compression option default, if not supplied or incorrectly supplied above.
declare -A COMPTYPES
COMPTYPES=([bzip2]=1 [xz]=1 [gzip]=1 [compress]=1 [lzma]=1 [lzop]=1 [lzip]=1)
if [ "$COMPTYPE" == "" ]; then COMPTYPE="bzip2"; fi
if [[ -z "${COMPTYPES[$COMPTYPE]+_}" ]]; then COMPTYPE="bzip2"; techo "\e[33m***WARNING:\e[0m Invalid compression type specified defaulting to $COMPTYPE"; fi

debugecho "COMPTYPE: [$COMPTYPE] "

pidfifo=$(mktemp --dry-run)
mkfifo --mode=0700 $pidfifo
exec 3<>$pidfifo
rm -f $pidfifo
running=0
debugecho "MAXTHREADS: [$MAXTHREADS]" 4

#list contents of BASEDIR for 
for DIR in "$BASEDIR"/*; do

	while (( running >= $MAXTHREADS )) ; do
		if read -u 3 cpid ; then
			debugecho "running threads: [$running] [$cpid]" 4
			wait $cpid
			(( --running ))
		fi
	done

	(
	echo $BASHPID 1>&3
	debugecho "Started thread: $BASHPID" 4
	# only interested if it has got AMD data in it
	if [ ! -r "$DIR/prevdir.lst" ]; then continue; fi
	AMDNAME=`echo $DIR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
	if [ ! $AMDNAME == $TARGETAMD ]; then continue; fi
	techo "Processing AMD: $AMDNAME"
	
	# recurse year/month/day directory structure
	for YEAR in "$DIR"/*; do
		if [ ! -d "$YEAR" ]; then continue; fi
		if [ ! $TYEAR == "" ] && [ ! "$TYEAR" == "${YEAR: -4}" ]; then continue; fi
		debugecho "Procesing year: ${YEAR: -4}" 3
		for MONTH in "$YEAR"/*; do
			if [ ! -d "$MONTH" ]; then continue; fi
			if [ ! $TMONTH == "" ] && [ ! "$TMONTH" == "${MONTH: -2}" ]; then continue; fi
			debugecho "Processing month: ${MONTH: -2}" 3
			for DAY in "$MONTH"/*;  do
				if [ ! -d "$DAY" ]; then debugecho "Skipping non-folder [$DAY]", 3; continue; fi
				if [[ ${DAY} =~ DDD[0-9]+$ ]]; then debugecho "skipping folder in delete phase [$DAY]" 2; continue; fi
				debugecho "[$TDAY] [$DAY] [${DAY: -2}]" 3
				if [ ! $TDAY == "" ] && [ ! "$TDAY" == "${DAY: -2}" ]; then continue; fi

				debugecho "Processing directory DAY: [$DAY]" 2
				DATADATE=`echo $YEAR | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $MONTH | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `-`echo $DAY | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
				debugecho "Processing date: DATADATE: [$DATADATE]" 2

				# process zdata files if found (if not probably archived already)
				ZCOUNT=0
				set +e
				ZCOUNT=$(ls "$DAY"/zdata_* 2> /dev/null | wc -l)
				#INTLEN=$((16#$(ls "$DAY"/zdata_* 2> /dev/null | head -n 1 | awk 'BEGIN {FS="_"} {print $3}')))
				#debugecho "$(ls -1 $DAY/zdata_*)", 2
				INTLEN=$(ls -1 "$DAY"/zdata_* 2> /dev/null | head -n 1 | awk 'BEGIN {FS="_"} {print $3}')
				if [ "$INTLEN"=="" ]; then INTLEN=5; fi
				debugecho "INTLEN: [$INTLEN]", 2
				set -e
				updated=0
				# if there is zdata (already archived) and it is not todays date (incomplete data), then archive it
				nowtime=$($DATE -u +"%s")
				datatime=$($DATE -u -d "$DATADATE" +"%s")
				archivedelay=$(($nowtime-$datatime))
				maxwait=$((86400 * $MAXWAITDAYS))
				#expected=288
				expected=$((1440/$INTLEN))
				debugecho "ZCOUNT: [$ZCOUNT] INTLEN: [$INTLEN] expected: [$expected] archivedelay: [$archivedelay] nowtime: [$nowtime] datatime: [$datatime]" 2
				
				if ([ $ZCOUNT -gt 0 ] && [ $archivedelay -gt 86400 ]) || [ $FORCEUPDATE ]; then

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

					if [ $NDATA -gt $ZDATA ]; then INTS=$NDATA; else INTS=$ZDATA; fi
					#if [ $INTS -lt $expected ]; then debugecho "Day not yet fully downloaded, intervals found [$INTS] expected [$expected], skipping" ; continue; fi
					if [ $ZCOUNT -lt $expected ] && [ $archivedelay -gt $maxwait ]; then 
						techo "$DAY not completely downloaded, but we've waited more than $MAXWAITDAYS days, archiving it anyway."  
					else
						techo "$DAY not yet completely downloading, waiting upto $MAXWAITDAYS days to complete, skipping for now."
						if [ $FORCEUPDATE -eq 0 ]; then continue; fi
					fi

					# check for existing archive, skip if found - don't want to overwrite archived data.
					ARCNAME=$AMDNAME-$DATADATE.tar.$COMPTYPE
					if [ ! -w "$MONTH"/$ARCNAME ] && [ -f "$MONTH"/$ARCNAME ]; then
						if [ $FORCEUPDATE -eq 1 ]; then
							#extract existing archive so we can update it.
							techo "Archive $ARCNAME exists so we'll update it."
							UPDATEARC=1
						else
							techo "\e[33m***WARNING:\e[0m Archive [$MONTH/$ARCNAME] already exists or can't write, skipping."
							continue
						fi
					fi

					# grab version from non HS AMD zdata						
					if [ $ZDATA -ne 0 ]; then $AWK -F" " '$1=="V" { printf("%s.%s.%s.%s", $2,$3,$4,$5) }' "$DAY"/zdata_*_t >> "$DAY"/versions.lst.tmp; fi
					# grab version from HS AMD zdata
					if [ $VOLDATA -ne 0 ]; then $AWK -F" " '$1=="#Producer:" { sub("ndw.","" , $2); print $2 }' "$DAY"/zdata_*_t_vol >> "$DAY"/versions.lst.tmp; fi

					#grab server/client/port details from zdata 'U' and 'h' records
					FILEEXT="$DAY/*_t*"		#catchall hopefully only used when there's no n/z data and a forced update is called for
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
							if [ ! -f "$DAY"/$file ] || [ ! -f "$DAY"/$file.tmp ] ; then continue; fi
							if [ -f "$DAY"/$file ]; then chmod +w "$DAY"/$file; fi
							$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$DAY"/$file.tmp > "$DAY"/$file
							chmod -w "$DAY"/$file
							rm "$DAY"/$file.tmp
						done
					fi

					# archive it all
					techo "Compressing $DAY"
					if [ $UPDATEARC -eq 1 ]; then
						cp "$MONTH/$ARCNAME" "$MONTH/$ARCNAME.bak"
						cp "$MONTH/$ARCNAME.sha512" "$MONTH/$ARCNAME.sha512.bak"
						chmod +w "$MONTH/$ARCNAME" "$MONTH/$ARCNAME.sha512"
						$TAR --$COMPTYPE -rf "$MONTH"/$ARCNAME -C "$DAY" . >&2
						RC=$?
					else
						if [ -f "$MONTH"/$ARCNAME ]; then techo "\e[31m***FATAL:\e[0m Archive exists $MONTH/$ARCNAME, yet it shouldn't, aborting to portect data integrity!"; exit 1; fi
						$TAR --$COMPTYPE -cf "$MONTH"/$ARCNAME -C "$DAY" . >&2
						RC=$?
					fi
					if [ $RC -eq 0 ]; then
						#succesful, checksum the archive and clean up data files
						$SHA512SUM $MONTH/$ARCNAME > $MONTH/$ARCNAME.sha512
						chmod -w $MONTH/$ARCNAME $MONTH/$ARCNAME.sha512
						#rm -f "$DAY"/*data_* "$DAY"/vdataidx_* "$DAY"/page2transmap_*
						#rm -rf "$DAY"/conf
						DDAY=${MONTH}/DDD${DAY##*/}
						debugecho "DDAY: [$DDAY]", 2
						mv "$DAY" "$DDAY"
						mkdir -p "$DAY"
						if [ -f "$DDAY"/*.lst ]; then cp "$DDAY"/*.lst "$DAY"; fi
						EDIR=`mktemp -d`
						rsync -a --delete "$EDIR/" "$DDAY/"
						rm -rf "$DDAY"
						rm -rf "$EDIR"
					else
						#failed
						techo "\e[33m***WARNING:\e[0m Couldn't archive data files in: $DAY, will try again next time."
					fi
				elif [ $ZCOUNT -gt 0 ] && [ $ZCOUNT -lt $expected ] && [ $archivedelay -lt $maxwait ]; then
					debugecho "ZCOUNT: [$ZCOUNT] not expected: [$expected], archivedelay: [$archivedelay] lt [$maxwait]"
					techo "$DAY not yet complete, waiting upto $MAXWAITDAYS days for all data to download."
				elif [ $ZCOUNT -eq 0 ]; then
					#no zdata files found, test to see if truely empty, or already archived.
					if [ ! -r "$DAY/softwareservice.lst" ]; then
						debugecho "\e[33m***WARNING:\e[0m No zdata files in: DAY: [$DAY]." 2
					else
						debugecho "Already archived: DAY: [$DAY]" 2
					fi
				else
					debugecho "DATADATE: [$DATADATE] = today, not ready to archive yet. skipping."
				fi

			done
		done 
	done
	techo "Processing AMD: $AMDNAME complete."
	) &	
	(( ++running ))
done

rm -f "$PIDFILE"

#wait for final threads to complete
while (( running > 0 )) ; do
	if read -u 3 cpid ; then
		debugecho "running threads: [$running] [$cpid]" 4
		wait $cpid
		(( --running ))
	fi
done

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "rtmarchive Archive Management Script"
techo "Completed in $tdur seconds"

