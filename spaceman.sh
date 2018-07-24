#!/usr/bin/env bash
# spaceman Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Monitors disk space utilisation of the rtmarchive storage directory and 
# alerts when disk space is low.  Additionally a retention period can be 
# set to automatically purge data exceeding the retention time.
#
# parameters:
# queryrumc.sh [-h] [-d]
# -h	syntax help
# -d	add debug output
#
# Output:
# Typically none.
# If a threshold is breached, syslog and email alerts sent.
# If auto managed cleanup is enabled, and data is removed it will be detailed.



# config 

# location of archive storage
BASEDIR=/var/spool/rtmarchive
PIDFILE=/tmp/spaceman.pid

# free space warning and critical thresholds %
WARNPER=20
CRITPER=10

# comma seperated list of recipient email addresses
EMAILLIST="root,admin@example.org"
# sender address
FROM_ADDR="spaceman@rtmarchive"


# not functional yet - years
# deletions will only occur if space is warning or critical and data exceeds retention time.

# retention period, nothing newer than this will be deleted.
RETENTION_YEARS=7
# enable (1) or disable (0) automatic space cleanup
AUTO_MANAGE=0




# Start of script - do not edit below
DEBUG=0
set -euo pipefail
IFS=$',\n\t'

# Parse command line parameters
OPTS=1
while getopts ":hd" OPT; do
	case $OPT in
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
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
	echo -e "*** INFO: Usage: $0 [-h] [-d]"
	echo -e "-h This help"
	echo -e "-d debug output"
	exit 0
fi


# support functions

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u "+%Y-%m-%d %H:%M:%S"`]: $1" 
}

function sendalert {
	# three params "subject" "body" "syslog priority"(optional defaults to user.warn)

	# log to syslog
	prio=${3:-"user.warn"}
	syslog="$1 - `echo -e "$2" | tr '\n' ' '`"
	debugecho "syslog: [$syslog]" 2
	logger -s -p $prio "$syslog"
	
	# send email
	debugecho "sending email: BCC: [$EMAILLIST] From: [$FROM_ADDR] Subject: [$1] Body: [$2]" 2 
	mail -s "$1" -r "$FROM_ADDR" -b "$EMAILLIST" "$FROM_ADDR" < <(echo -e "$2\n")

}



# main code

if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	techo "spaceman script already running pid: `cat $PIDFILE`. Aborting."
	exit 1
fi

#use 'df' and the basedir to determine which volume the archive is on, and size/used/free.
RET=`df -BM $BASEDIR | tail -n 1`
debugecho "DF RET: [$RET]" 2

IFS=" "
read FS_VOL FS_SIZE FS_USED FS_FREE FS_USEDPER FS_MOUNT < <(echo -E $RET)
debugecho "\nVolume: [$FS_VOL]\nSize:   [$FS_SIZE]\nUsed:   [$FS_USED]\nFree:   [$FS_FREE]\nUsed%   [$FS_USEDPER]\nMount:  [$FS_MOUNT]"

FS_USEDPER=${FS_USEDPER::-1}
debugecho "FS_USEDPER: [$FS_USEDPER]" 2

CRITPER=$((100 - CRITPER))
debugecho "CRITPER [$CRITPER]" 2
WARNPER=$((100 - WARNPER))
debugecho "WARNPER [$WARNPER]" 2

NEED_CLEANUP=0
if [ $FS_USEDPER -ge $CRITPER ]; then
	# critical threshold
	sendalert "CRITICAL! $HOSTNAME rtmarchive storage approaching capacity" "Server: ${HOSTNAME}\nFile System: ${FS_VOL}\nTotal: $FS_SIZE  Used: $FS_USED ($FS_USEDPER%) Free: $FS_FREE " "user.crit"
	NEED_CLEANUP=1
elif [ $FS_USEDPER -ge $WARNPER ]; then
	# warning theshold
	sendalert "Warning! $HOSTNAME rtmarchive storage approaching capacity" "Server: ${HOSTNAME}\nFile System: ${FS_VOL}\nTotal: $FS_SIZE  Used: $FS_USED ($FS_USEDPER%) Free: $FS_FREE "
	NEED_CLEANUP=1
fi


# auto space management, if enabled, and if warning or critical threshold reached
if [ $AUTO_MANAGE -eq 1 ] && [ $NEED_CLEANUP -eq 1 ]; then

	debugecho "Auto managed space cleanup starting"

	# calculate timestamp cutoff.
	CUTOFF=$(date -ud "-$RETENTION_YEARS years")
	debugecho "CUTOFF: [$CUTOFF]"

	for AMD in "$BASEDIR"/*; do
		# only interested if it has got AMD data in it
		if [ ! -r "$AMD/prevdir.lst" ]; then continue; fi

		debugecho "AMD: [$AMD]" 2

		for YEAR in "$AMD"/*; do
			if [ ! -d "$YEAR" ]; then continue; fi

			debugecho "AMD/YEAR: [$YEAR]" 2

			CUTOFF_YR=$(date -d "$CUTOFF" +%C%y )
			CUTOFF_MN=$(date -d "$CUTOFF" +%m )
			debugecho "CUTOFF_YR: [$CUTOFF_YR]  CUTOFF_MN: [$CUTOFF_MN]" 2
			if [ ${YEAR##*/} -lt $CUTOFF_YR ]; then
				# old year - cull it
				debugecho "$YEAR, cull" 1
				#rm -rf $YEAR
				if [ $? -eq 0 ]; then
					techo "Removed: $YEAR"
				else
					techo "***WARNING: Could Not Remove: $YEAR"
				fi

			elif [ ${YEAR##*/} -eq $CUTOFF_YR ]; then
				# border year, recurse it for month cutoff
				debugecho "$YEAR, current, recurse" 2

				for MONTH in "$YEAR"/*; do
					#recurse month folders to cull to the cut off month.
					if [ ${MONTH##*/} -lt $CUTOFF_MN ]; then
						#month older than cutoff
						debugecho "$MONTH, cull" 1
						#rm -rf $MONTH
						if [ $? -eq 0 ]; then
							techo "Removed: $MONTH"
						else
							techo "***WARNING: Could Not Remove: $MONTH"
						fi
					else
						# month current, safe
						debugecho "$MONTH, safe" 2
					fi

				done
				 
			elif [ ${YEAR##*/} -gt $CUTOFF_YR ]; then
				# retention period year, keep it
				debugecho "$YEAR, safe" 2
				continue
			else
				# err				
				debugecho "*** WANRING: Unknown year directory: $YEAR"
				continue
			fi

		done		

	done

fi

rm -f $PIDFILE

# exit
exit 0

