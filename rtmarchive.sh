# rtmarchive Main Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Starts archiving process, other scripts are called from here.
#

#config 
AMDLIST=/home/data_mine/rtmarchive/amdlist.cfg
BASEDIR=/var/spool/rtmarchive
SCRIPTDIR=~/rtmarchive
MAXTHREADS=4
DEBUG=${1:-0}



# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
JOBS=`which jobs`
WC=`which wc`

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

$AWK -F"," '$1=="A" { print $3","$2 } ' $AMDLIST | ( while read p q; do 
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	echo -e "Launching amdarchive script for: ${p}"
	$SCRIPTDIR/archiveamd.sh "${p}" "${q}" "$BASEDIR" $DEBUG &
done; wait
)

echo
echo rtmarchive script complete
echo

