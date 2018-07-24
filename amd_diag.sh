#!/bin/bash
# diagnsotics script to help determine why AMD not being collected, accepts one parameter AMD name.

#config

BASEDIR=/var/spool/rtmarchive
RTMARCHIVEUSER=rtmarchive


#setup


# command line arguments
OPTS=0
while getopts ":dhb:a:" OPT; do
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
		a)
			AMDNAME=$OPTARG
			OPTS=1
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
	echo -e "*** INFO: Usage: $0 [-h] [-b basearchivedir] -a amdname"
	echo -e "-h This help. Optional"
	echo -e "-b basearchivedir Archive directory path. Optional. Default: $BASEDIR"
	echo -e "-a amdname Name of AMD to run diagnostics against. Required."
	exit 0
fi
#if [ "$AMDNAME" == "" ]; then echo "no AMD name specified. Aborting"; exit 255; fi



#functions
function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u "+%Y-%m-%d %H:%M:%S"`]: $1" 
}

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

	for FILE in "$1"/*; do
		if [ -d "$FILE" ]; then continue; fi
		temp2=`permtestfile $FILE`
		if [ $? -ne 0 ]; then echo -e "$temp2\n" ; fi

	done

	for YEAR in "$1"/*; do
		if [ ! -d "$YEAR" ]; then continue; fi
		temp2=`permtestdir $YEAR`
		if [ $? -ne 0 ]; then echo -e "$temp2\n" ; fi

		for MONTH in "$YEAR"/*; do
			if [ ! -d "$MONTH" ]; then continue; fi
			temp2=`permtestdir $MONTH`
			if [ $? -ne 0 ]; then echo -e "$temp2\n" ; fi

			for DAY in "$MONTH"/*;  do
				if [ ! -d "$DAY" ]; then continue; fi
				temp2=`permtestdir $DAY`
				if [ $? -ne 0 ]; then echo -e "$temp2\n" ; fi

			done
		done 
	done

}

function permtestdir {
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
	if [[ ! $PERMS =~ 7[75]5 ]]; then temp+="$PERMS incorrect. FAIL\n"; RC=1 ; else temp+="$PERMS correct. OK\n"; fi

	echo -e "$temp\n"
	return $RC
}

function permtestfile {
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
	if [[ ! $PERMS =~ 6[64][40] ]]; then temp+="$PERMS incorrect. FAIL\n"; RC=1 ; else temp+="$PERMS correct. OK\n"; fi

	echo -e "$temp\n"
	return $RC
}



# main code

techo "Diagnostics Test on $AMDNAME"
echo ""


#test if in amdlist
RETURN=`grep "$AMDNAME" /etc/amdlist.cfg`
#echo "[$RETURN]"
techo "RUM Console check "
if [[ "$RETURN" == "" ]]; then techo "AMD $AMDNAME not in amdlist.cfg, Is it in RUM Console? FAIL"; techo "$(rumclog $AMDNAME)" ; fi
if [[ $RETURN =~ D,.* ]]; then techo "AMD $AMDNAME, disabled in amdlist.cfg, not reachable/up/wrong credentials? FAIL"; techo "$(rumclog $AMDNAME)" ; fi
if [[ $RETURN =~ A,.* ]]; then techo "AMD $AMDNAME in amd list and active. OK"; fi


#test if dir present
echo ""
echo -n "AMD archive directory "
if [ ! -d $BASEDIR/$AMDNAME ]; then echo "doesn't exist! FAIL"; else echo "present. OK"; rtmarchivelog $AMDNAME ;fi

#test dir ownership/permissions
echo ""
techo "AMD archive directory checking all directory permissions... may take a while... "
temp=`testdirectories $BASEDIR/$AMDNAME`
if [[ "$temp" == "" ]]; then techo "All permissions correct. OK"; else echo ""; fi
techo "$temp"


#test if prevdir.lst present
echo ""
techo "Previous state file $BASEDIR/$AMDNAME/prevdir.lst "
if [ ! -r $BASEDIR/$AMDNAME/prevdir.lst ]; then techo "Not present/not readable."; techo "$(rtmarchivelog $AMDNAME)" ; fi
if [ ! -s $BASEDIR/$AMDNAME/prevdir.lst ]; then techo "Previous state file empty."; techo "$(rtmarchivelog $AMDNAME)" ; fi

#test if currdir.lst present, indicates failed last run.
echo ""
techo "Current state file $BASEDIR/$AMDNAME/currdir.lst "
if [ -s $BASEDIR/$AMDNAME/currdir.lst ]; then techo "exists! WARNING"; elif [ -f $BASENAME/$AMDNAME/currdir.lst ]; then techo "Current state file empty!!! FAIL"; else techo "OK"; fi


# dump out filter log entries, no testing done here
techo "Log entries from archivemgmt.sh and archivemgmtindex.sh. INFO"
techo "$(archivemgmtlog $AMDNAME)"


# finished

echo ""
techo "Diagnostics complete."

