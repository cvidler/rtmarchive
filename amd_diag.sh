#!/bin/bash
# diagnsotics script to help determine why AMD not being collected, accepts one parameter AMD name.

BASEDIR=/var/spool/rtmarchive
AMDNAME=${1:-}
RTMARCHIVEUSER=rtmarchive

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

function testdirectories {

	for YEAR in "$1"/*; do
		if [ ! -d "$YEAR" ]; then continue; fi
		temp2=`permtest $YEAR`
		if [ $? -ne 0 ]; then temp+="$temp2\n" ; fi
		continue

		for MONTH in "$YEAR"/*; do
			if [ ! -d "$MONTH" ]; then continue; fi
			temp+=`permtest $MONTH`

			for DAY in "$MONTH"/*;  do
				if [ ! -d "$DAY" ]; then continue; fi
				temp+=`permtest $DAY`	

			done
		done 
	done

	echo -e "$temp"
}

function permtest {
	DIR=$1
	RC=0
	OWNER=`stat -c %U $DIR`
	GROUP=`stat -c %G $DIR`
	PERMS=`stat -c %a $DIR`
	temp+="AMD archive directory ownership $DIR "
	if [ ! "$OWNER" == "$RTMARCHIVEUSER" ]; then temp+="$OWNER incorrect. FAIL\n"; RC=1 ; else temp+="$OWNER correct. OK\n"; fi
	temp+="AMD archive directory group ownership $DIR "
	if [ ! "$GROUP" == "$RTMARCHIVEUSER" ]; then temp+="$GROUP incorrect. FAIL\n"; RC=1 ; else temp+="$GROUP correct. OK\n"; fi
	temp+="AMD archive directory permissions $DIR "
	if [ ! $PERMS -eq 775 ]; then temp+="$PERMS incorrect. FAIL\n"; RC=1 ; else temp+="$PERMS correct. OK\n"; fi

	echo -e "$temp\n"
	return $RC
}

#test if in amdlist
RETURN=`grep "$AMDNAME" /etc/amdlist.cfg`
#echo "[$RETURN]"
echo -n "RUM Console check "
if [[ "$RETURN" == "" ]]; then echo "AMD $AMDNAME not in amdlist.cfg, Is it in RUM Console? FAIL"; rumclog $AMDNAME ; fi
if [[ $RETURN =~ D,.* ]]; then echo "AMD $AMDNAME, disabled in amdlist.cfg, not reachable/up/wrong credentials? FAIL"; rumclog $AMDNAME ; fi
if [[ $RETURN =~ A,.* ]]; then echo "AMD $AMDNAME in amd list and active. OK"; fi


#test if dir present
echo -n "AMD archive directory "
if [ ! -d $BASEDIR/$AMDNAME ]; then echo "doesn't exist! FAIL"; else echo "present. OK"; rtmarchivelog $AMDNAME ;fi

#test dir ownership/permissions
temp=`testdirectories $BASEDIR/$AMDNAME`
echo -e "$temp"



#test if prevdir.lst present
echo -n "Previous state file $BASEDIR/$AMDNAME/prevdir.lst "
if [ ! -r $BASEDIR/$AMDNAME/prevdir.lst ]; then echo "Not present/not readable."; rtmarchivelog $AMDNAME ; fi
if [ ! -s $BASEDIR/$AMDNAME/prevdir.lst ]; then echo "Previous state file empty."; rtmarchivelog $AMDNAME ; fi

#test if currdir.lst present, indicates failed last run.
echo -n "Current state file $BASEDIR/$AMDNAME/currdir.lst "
if [ -s $BASEDIR/$AMDNAME/currdir.lst ]; then echo "exists! WARNING"; elif [ -f $BASENAME/$AMDNAME/currdir.lst ]; then echo "Current state file empty!!! FAIL"; else echo "OK"; fi


# dump out filter log entries, no testing done here
echo "Log entries from archivemgmt.sh and archivemgmtindex.sh. INFO"
archivemgmtlog $AMDNAME



echo "Diagnostics complete."
