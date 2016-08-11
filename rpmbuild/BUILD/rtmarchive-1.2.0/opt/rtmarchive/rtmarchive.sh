# rtmarchive Main Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Starts archiving process, other scripts are called from here.
#

#config 
AMDLIST=/etc/amdlist.cfg
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=/opt/rtmarchive
MAXTHREADS=4
DEBUG=0



# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
JOBS=`which jobs`
WC=`which wc`

#command line parameters
OPTS=1
while getopts ":hda:b:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=1
			;;
		a)
			AMDLIST=$OPTARG
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
	echo -e "*** INFO: Usage: $0 [-h] [-a amdlist] [-b basearchivedir]"
	echo -e "-h This help"
	echo -e "-u Update AMD list"
	echo -e "-a Full path to amdlist file, default $AMDLIST"
	echo -e "-b Full path to basearchivedir, default $BASEDIR"
	exit 0
fi



# Some sanity checking of the config parameters above
if [ ! -r "$AMDLIST" ]
then 
	echo -e "\e[31m***FATAL:\e[39m AMD config list file $AMDLIST not found. Aborting."
	exit
fi

if [ ! -w "$BASEDIR" ]
then
	echo -e "\e[31m***FATAL:\e[39m Archive storage directory $BASEDIR not found or not writeable. Aborting."
	exit
fi

if [ ! -x "$SCRIPTDIR/archiveamd.sh" ]
then
        echo -e "\e[31m***FATAL:\e[39m Required scripts in script directory $SCRIPTDIR not found or not executable. Aborting."
        exit
fi


# Lets start things
echo rtmarchive script
echo 
echo "Loading AMDs from config file: $AMDLIST"
echo
echo -e "`$AWK -F"," '$1=="A" { print " + " $3 "" } ' $AMDLIST`"
echo -e "\e[2m`$AWK -F"," '$1=="D" { print " - " $3 " Disabled" } ' $AMDLIST`\e[0m"
echo

DODEBUG=""
$AWK -F"," '$1=="A" { print $3","$2 } ' $AMDLIST | ( while read p q; do 
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	echo -e "Launching amdarchive script for: ${p}"
	if [ $DEBUG -ne 0 ]; then DODEBUG=-d; fi
	$SCRIPTDIR/archiveamd.sh -n "${p}" -u "${q}" -b "$BASEDIR" $DODEBUG &
done; wait
)

echo
echo rtmarchive script complete
echo

