#!/bin/bash
# diagnsotics script to help determine why AMD not being collected, accepts one parameter AMD name.

BASEDIR=/var/spool/rtmarchive
AMDNAME=${1:-}

if [ "$AMDNAME" == "" ]; then echo "no AMD name specified. Aborting"; exit 255; fi

#functions
function rumclog {
echo -e "filtered queryrumc.log\n----"
grep "$1" /var/log/rtmarchive/queryrumc.log | tail
echo "----"
}

function rtmarchivelog {
echo -e "filtered rtmarchive.log\n----"
grep "$1" /var/log/rtmarchive/rtmarchive.log | tail
echo "----"
}

function archivemgmtlog {
echo -e "filtered archivemgmt.log\n----"
grep "$1" /var/log/rtmarchive/archivemgmt.log | tail
echo "----"
echo -e "filtered archiveindex.log\n----"
grep "$1" /var/log/rtmarchive/archiveindex.log | tail
echo "----"

}

#test if in amdlist

RETURN=`grep "$AMDNAME" /etc/amdlist.cfg`
#echo "[$RETURN]"
if [[ "$RETURN" == "" ]]; then echo "AMD $AMDNAME not in amdlist.cfg, RUM Console?"; rumclog $AMDNAME ; exit 1; fi
if [[ $RETURN =~ D,.* ]]; then echo "AMD $AMDNAME, disabled in amdlist.cfg, not reachable/up/wrong credentials?"; rumclog $AMDNAME ; exit 1; fi
if [[ $RETURN =~ A,.* ]]; then echo "AMD $AMDNAME in amd list and active OK."; fi


#test if dir present
if [ ! -d $BASEDIR/$AMDNAME ]; then echo "AMD never collected from, archive directory doesn't exist"; else echo "AMD archive directory present. OK"; rtmarchivelog $AMDNAME ;fi

#test if prevdir.lst present
if [ ! -r $BASEDIR/$AMDNAME/prevdir.lst ]; then echo "No previous state file present/not readable."; rtmarchivelog $AMDNAME ; fi
if [ ! -s $BASEDIR/$AMDNAME/prevdir.lst ]; then echo "Previous state file empty."; rtmarchivelog $AMDNAME ; fi

#test if currdir.lst present, indicates failed last run.
if [ -s $BASEDIR/$AMDNAME/currdir.lst ]; then echo "Current state file currdir.lst exists!"; elif [ -f $BASENAME/$AMDNAME/currdir.lst ]; then echo "Current state file empty!!!"; fi

archivemgmtlog $AMDNAME


