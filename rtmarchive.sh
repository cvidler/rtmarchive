#!/usr/bin/env bash
# rtmarchive Main Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Starts archiving process, other scripts are called from here.
#

#config 
AMDLIST=/etc/amdlist.cfg
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=/opt/rtmarchive
PIDFILE=/tmp/rtmarchive.pid
MAXTHREADS=$(($(nproc)*4))
DEBUG=0



# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
JOBS=`which jobs`
WC=`which wc`
HEAD=`which head`
TR=`which tr`

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u "+%Y-%m-%d %H:%M:%S"`]: $1" 
}

tstart=`date -u +%s`
techo "rtmarchive script"

#command line parameters
OPTS=1
while getopts ":hda:b:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		a)
			AMDLIST=$OPTARG
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
	echo -e "*** INFO: Usage: $0 [-h] [-a amdlist] [-b basearchivedir]"
	echo -e "-h This help"
	echo -e "-a Full path to amdlist file, default $AMDLIST"
	echo -e "-b Full path to basearchivedir, default $BASEDIR"
	exit 0
fi


# Some sanity checking of the config parameters above
if [ ! -r "$AMDLIST" ]
then 
	techo "\e[31m***FATAL:\e[39m AMD config list file $AMDLIST not found. Aborting."
	exit 1
fi

if [ ! -w "$BASEDIR" ]
then
	techo "\e[31m***FATAL:\e[39m Archive storage directory $BASEDIR not found or not writeable. Aborting."
	exit 1
fi

if [ ! -x "$SCRIPTDIR/archiveamd.sh" ]
then
        techo "\e[31m***FATAL:\e[39m Required scripts in script directory $SCRIPTDIR not found or not executable. Aborting."
        exit 1
fi


if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	techo "rtmarchive script already running pid: `cat $PIDFILE`. Aborting."
	exit 1
fi


# Lets start things
techo "Loading AMDs from config file: $AMDLIST"
AAMDLIST="`$AWK -F"," '$1=="A" { print " + " $3 "" } ' $AMDLIST`"
DAMDLIST="\e[2m`$AWK -F"," '$1=="D" { print " - " $3 " Disabled" } ' $AMDLIST`\e[0m"
techo "$AAMDLIST"
techo "$DAMDLIST"

DODEBUG=""
amds=0
AAMDS=`$AWK -F"," '$1=="A" { print $3","$2 } ' $AMDLIST`
debugecho "AAMDS: [$AAMDS]" 2
if [ $DEBUG -ne 0 ]; then DODEBUG=-`$HEAD -c $DEBUG < /dev/zero | $TR '\0' 'd' `; fi

pidfifo=$(mktemp --dry-run)
mkfifo --mode=0700 $pidfifo
exec 3<>$pidfifo
rm -f $pidfifo
running=0
debugecho "MAXTHREADS: [$MAXTHREADS]"

while IFS=$',' read -r p q; do
	debugecho "p: [$p] q: [$q]" 2
	while (( running >= $MAXTHREADS )) ; do
		if read -u 3 cpid ; then
			wait $cpid
			(( --running ))
		fi
	done
	debugecho "running threads: [$running]"
	amds=$((amds+1))
	(
		echo $BASHPID 1>&3
		techo "Launching amdarchive script for: ${p}"
		RUNCMD="$SCRIPTDIR/archiveamd.sh -n \"${p}\" -u \"${q}\" -b \"$BASEDIR\" $DODEBUG"
		debugecho "RUNCMD: $RUNCMD"
		set +e
		$SCRIPTDIR/archiveamd.sh -n "${p}" -u "${q}" -b "$BASEDIR" $DODEBUG 
		RC=$?
		if [ $RC -ne 0 ]; then techo "\e[33m***WARNING:\e[0m ${p} archive collection aborted abnormally!" ; fi
		set -e
	) &
	(( ++running ))
done < <(echo "$AAMDS")
wait

rm -f $PIDFILE

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "rtmarchive script completed $amds AMDs in $tdur seconds"

