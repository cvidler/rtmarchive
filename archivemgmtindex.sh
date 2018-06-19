#!/usr/bin/env bash
# rtmarchive management search indexer script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process the daily data lists from the AMDs and build monthly/yearly lists for search optimisation.
#
#

# Config
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=/opt/rtmarchive
PIDFILE=/tmp/archivemgmtindex.pid
MAXTHREADS=$(($(nproc)*4))
DEBUG=0

# Script below do not edit
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
CAT=`which cat`
DATE=`which date`
JOBS=`which jobs`
WC=`which wc`
TOUCH=`which touch`

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`]: $1" 
}

# command line arguments
OPTS=1
FORCEINDEX=0
while getopts ":dhfb:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		f)
			FORCEINDEX=1
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
	echo -e "*** INFO: Usage: $0 [-h] [-f] [-b basearchivedir]"
	echo -e "-h This help. Optional"
	echo -e "-f Force a full re-index (potentially slow)."
	echo -e "-b basearchivedir Archive directory path. Optional. Default: $BASEDIR"
	exit 0
fi


tstart=`date -u +%s`
techo "rtmarchive Archive Search Indexer Script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2016"
techo "Starting"

if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	techo "archivemgmtindex script already running pid: `cat $PIDFILE`. Aborting."
	exit 1
fi

#determine yesterday (UTC)
today=$($DATE -u +"%s")
yesterday=$(($today - 86400))
tgtyear=$($DATE -u -d "@$yesterday" +"%Y")
tgtmonth=$($DATE -u -d "@$yesterday" +"%m")
tgtday=$($DATE -u -d "@$yesterday" +"%d")

amds=0
years=0
months=0
days=0
files=0
jobcount=0

outfile=$(mktemp)
debugecho "outfile [$outfile]" 2

pidfifo=$(mktemp --dry-run)
mkfifo --mode=0700 $pidfifo
exec 3<>$pidfifo
rm -f $pidfifo
running=0
debugecho "MAXTHREADS: [$MAXTHREADS]"

#list contents of BASEDIR for 
for AMD in "$BASEDIR"/*; do
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
	    if [ ! -r "$AMD/prevdir.lst" ]; then continue; fi
		amds=$((amds+1))
	    AMDNAME=`echo $AMD | $AWK ' match($0,"(.+/)+(.+)$",a) { print a[2] } ' `
	    techo "Processing AMD: $AMDNAME"
		debugecho "PID: [$BASHPID]"

		# recurse year/month/day directory structure
	    for YEAR in "$AMD"/*; do
	        if [ ! -d "$YEAR" ]; then continue; fi
			if [ ! $FORCEINDEX ] && [ ! $YEAR == $AMD"/"$tgtyear ]; then continue; fi
			years=$((years+1))
	        for MONTH in "$YEAR"/*; do
				if [ ! -d "$MONTH" ]; then continue; fi
				if [ ! $FORCEINDEX ] && [ ! $MONTH == $YEAR"/"$tgtmonth ]; then continue; fi
				months=$((months+1))
				for DAY in "$MONTH"/*;  do
					if [ ! -d "$DAY" ]; then continue; fi
					if [ ! $FORCEINDEX ] && [ ! $DAY == $MONTH"/"$tgtday ]; then continue; fi
					days=$((days+1))
					debugecho "Processing directory $DAY"
					# target year and month, process it

					# concatenate yesterdays list files into months ones (create as needed)
					# then de-dupe and sort list files
					for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst; do
						if [ ! -r "$DAY/$file" ]; then continue; fi
						files=$((files+1))
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
					files=$((files+1))
					$TOUCH "$YEAR"/$file
					$CAT "$YEAR/$file" "$MONTH/$file" >> "$YEAR/$file.tmp"
					rm -f "$YEAR"/$file
					$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$YEAR"/$file.tmp > "$YEAR"/$file
					chmod -w "$YEAR/$file"
					rm "$YEAR"/$file.tmp
				done

			done
			                
			# concatenate yearly list files into amd ones (create as needed)
			# then de-dupe and sort list files
			for file in timestamps.lst softwareservice.lst serverips.lst clientips.lst serverports.lst; do
				if [ ! -r "$YEAR/$file" ]; then continue; fi
				files=$((files+1))
				$TOUCH "$AMD"/$file
				$CAT "$AMD/$file" "$YEAR/$file" >> "$AMD/$file.tmp"
				rm -f "$AMD"/$file
				$AWK '{ !a[$0]++ } END { n=asorti(a,c) } END { for (i = 1; i <= n; i++) { print c[i] } }' "$AMD"/$file.tmp > "$AMD"/$file
				chmod -w "$AMD/$file"
				rm "$AMD"/$file.tmp
			done

		done
	    techo "Processing AMD: $AMDNAME Finished"
		echo -e "$amds,$years,$months,$days,$files" >> $outfile
	) & 
	(( ++running ))
done
wait

while read a b c d e; do
    amds=$((amds + a))
    years=$((years + b))
    months=$((months + c))
    days=$((days + d))
	files=$((files + e))
done < $outfile
rm -f $outfile

rm -f $PIDFILE

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "rtmarchive Archive Search Indexer Script"
techo "Completed $amds AMDs, $years years, $months months, $days days, totalling $files files in $tdur seconds."

