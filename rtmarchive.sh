# rtmarchive Main Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Starts archiving process, other scripts are called from here.
#

#config 
export AMDLIST=amdlist.cfg
export BASEDIR=/var/spool/rtmarchive
export SCRIPTDIR=~/rtmarchive




# Start of script - do not edit below
export AWK=`which awk`

# Some sanity checking of the config parameters above
if [ ! -r "$AMDLIST" ]
then 
	echo ***FATAL: AMD config list file $AMDLIST not found. Aborting.
	exit
fi

if [ ! -w "$BASEDIR" ]
then
	echo ***FATAL: archive storage directory $BASEDIR not found or not writeable. Aborting.
	exit
fi

if [ ! -x "$SCRIPTDIR/archiveamd.sh" ]
then
        echo ***FATAL: Required scripts in script directory $SCRIPTDIR not found or not executable. Aborting.
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

$AWK -F"," '$1=="A" { print $3" "$2 } ' $AMDLIST | while read p q; do 
	echo Launching amdarchive script for: ${p}
	$SCRIPTDIR/archiveamd.sh "${p}" "${q}" "$BASEDIR" &
done

echo
echo rtmarchive script complete
echo

