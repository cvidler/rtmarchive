#!/usr/bin/env bash
# rtmarchive management script
# Chris Vidler Dynatrace DCRUM SME
#
# called nightly by cron to process and compress local AMD data into archives for
# downloading by the archive server.
#
#

# Config
BASEDIR=/var/spool/adlex
CONFDIR=/usr/adlex/config
DATASETS=rtm,nfc
MAXTHREADS=$(($(nproc)*2))
PIDFILE=/tmp/rtmarchive_local.pid
DEBUG=2




# Script below do not edit
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
CAT=`which cat`
TAR=`which tar`
BZIP2=`which bzip2`
DATE=`which date`
GREP=`which grep`
SORT=`which sort`
UNIQ=`which uniq`
SHA512SUM=`which sha512sum`
WC=`which wc`
AMDNAME="$(hostname)"
AMDNAME=${AMDNAME##*.}


# command line arguments
OPTS=1
while getopts ":dhb:c:" OPT; do
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
		c)
			CONFDIR=$OPTARG
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
	echo -e "*** INFO: Usage: $0 [-h] [-b basedatadir] [-c configdir]"
	echo -e "-h This help. Optional"
	echo -e "-b basedatadir AMD data directory path. Optional. Default: $BASEDIR"
	echo -e "-c configdir AMD config directory path. Optional. Default: $CONFDIR"
	exit 0
fi



function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	text=${1:-}
	if [ "$text" == "" ]; then exit; fi
	echo -e "[`date -u`][$AMDNAME]: $text" 
}



tstart=`date -u +%s`
techo "rtmarchive AMD Local Archive Creation Script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2017"
techo "Starting"

#sanity check configuration
if [ ! -w "$BASEDIR" ]
then
	techo "\e[31m***FATAL:\e[39m Archive data/storage directory $BASEDIR not found or not writeable. Aborting."
	exit 1
fi

if [ ! -r "$CONFDIR" ]
then
	techo "\e[31m***FATAL:\e[39m AMD Config directory $CONFDIR not found or not readable. Aborting."
	exit 1
fi


#check if already running/crashed
if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	if ps -p `cat $PIDFILE` > /dev/null; then
		techo "$0 script already running pid: `cat $PIDFILE`. Aborting."
		exit 1
	else
		techo "$0 script crashed/didn't finish last run. [rm $PIDFILE] to clear. Aborting."
		exit 2
	fi
fi




#prepare fifo for thread tracking
pidfifo=$(mktemp --dry-run)
mkfifo --mode=0700 $pidfifo
exec 3<>$pidfifo
rm -f $pidfifo
running=0
debugecho "MAXTHREADS: [$MAXTHREADS]"

# loop through data sets (e.g. rtm and nfc) determine what days of data do we have, produce a list of the days.
IFS=","; for dataset in $DATASETS; do
	debugecho "Enumerating available data in $BASEDIR/$dataset"

	set +e
	datafiles=$(ls -1 "$BASEDIR/$dataset" | grep -oE '[a-z0-9A-Z%\-\ _]+_[0-9a-f]{8}_[a-f0-9]+_[tb][_0-9a-z]*' | $SORT -t "_" -k 2d,3 -k 1d,2)
	set -e
	
	if [ "$datafiles" == "" ]; then debugecho "No data files in [$BASEDIR/$dataset]"; continue; fi
	debugecho "$datafiles" 3

	# iterate file name, extracting timestamps, calculate dates in play
	dates=""
	dates=$(echo $datafiles | while read file; do
		ts=${file#*_}
		ts=${ts%%_*}
		echo "`TZ=UTC; printf "%(%Y-%m-%d)T" 0x$ts`"
	done)
	debugecho "dates [$dates]" 2
	# sort and uniq dates list
	dates=$(echo -e "$dates" | $SORT | $UNIQ)
	debugecho "dataset: [$dataset] dates: [$dates]"

	techo "$BASEDIR/$dataset contains `echo $dates | wc -l` full/partial days of data"

	# iterate known dates archiving if complete and not already done
	echo $dates | while read date; do

		debugecho "Testing archivability of: [$date]"
		
		#create list of all possible time stamps for this date. /min resolution 1440 timestamps.
		startts=`TZ=UTC; date +%s --date "$date 00:00:00"`
		tss=$(for secs in {0..86399..60}; do
			printf "%x\n" $((secs+startts))
		done)
		#debugecho `echo $tss | wc -l`

		# use timestamp list to collate all matching files
		for file in $BASEDIR/$dataset/*; do
			
		done
		echo 

		# if correct number of files present, archive them
		# or not if already arhived

		# insufficient files, skip til next time



	done

done



# Done
rm $PIDFILE
techo "Complete"


