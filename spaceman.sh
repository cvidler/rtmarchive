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

# config 

# location of archive storage
BASEDIR=/var/spool/rtmarchive

# free space warning and critical thresholds %
WARNPER=70
CRITPER=10

# comma seperated list of recipient email addresses
EMAILLIST="root,admin@example.org"
# sender address
FROM_ADDR="spaceman@rtmarchive"


# not functional yet - years
# deletions will only occur if space is warning or critical and data exceeds retention time.
RETENTION_YEARS=7





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
	echo -e "[`date -u`]: $1" 
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

#use 'df' and the basedir to determine which volume the archive is on, and size/used/free.
RET=`df -BM $BASEDIR | tail -n 1`
debugecho "DF RET: [$RET]" 2

IFS=" "
read FS_VOL FS_SIZE FS_USED FS_FREE FS_USEDPER FS_MOUNT < <(echo -E $RET)
debugecho "\nVolume: [$FS_VOL]\nSize:   [$FS_SIZE]\nUsed:   [$FS_USED]\nFree:   [$FS_FREE]\nUsed%   [$FS_USEDPER]\nMount:  [$FS_MOUNT]" 2

FS_USEDPER=${FS_USEDPER::-1}
debugecho "FS_USEDPER: [$FS_USEDPER]" 2

CRITPER=$((100 - CRITPER))
debugecho "CRITPER [$CRITPER]" 2
WARNPER=$((100 - WARNPER))
debugecho "WARNPER [$WARNPER]" 2

if [ $FS_USEDPER -ge $CRITPER ]; then
	# critical threshold
	sendalert "CRITICAL! $HOSTNAME rtmarchive storage approaching capacity" "Server: ${HOSTNAME}\nFile System: ${FS_VOL}\nTotal: $FS_SIZE  Used: $FS_USED ($FS_USEDPER%) Free: $FS_FREE " "user.crit"
elif [ $FS_USEDPER -ge $WARNPER ]; then
	# warning theshold
	sendalert "Warning! $HOSTNAME rtmarchive storage approaching capacity" "Server: ${HOSTNAME}\nFile System: ${FS_VOL}\nTotal: $FS_SIZE  Used: $FS_USED ($FS_USEDPER%) Free: $FS_FREE "
fi


