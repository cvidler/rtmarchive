# rtmarchive Main Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Starts archiving process, other scripts are called from here.
#

#config 
export AMDLIST=amdlist.cfg
export BASEDIR=/var/spool/rtmarchive
export SCRIPTDIR=~/rtmarchive
export DEBUG=1



# Start of script - do not edit below
AWK=`which awk`

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
echo Loading AMDs from config file: $AMDLIST
echo
echo `$AWK -F"," '$1=="A" { print " + " $3 } ' $AMDLIST`
echo `$AWK -F"," '$1=="D" { print " - " $3 " Disabled" } ' $AMDLIST`
echo


$AWK -F"," '$1=="A" { print $3" "$2 } ' $AMDLIST | ( while read p q; do 
	echo Launching amdarchive script for: ${p}
	$SCRIPTDIR/archiveamd.sh "${p}" "${q}" "$BASEDIR" $DEBUG &
done; wait
)

echo
echo rtmarchive script complete
echo

