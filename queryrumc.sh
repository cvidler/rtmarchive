#!/usr/bin/env bash
# queryrcon Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Builds amdlist.cfg from querying RUM console.
# parameters:
# queryrumc.sh [-h] [-u] [-d] [-e password] [-c conffile] [-a amdlistfile]
# -u	update amdlist.cfg file in path below default OFF
# -d	debug output debug info (repeat for more verbosity). default OFF
# -e	encrypt a password for RUMC access used to add RUMC entries to rumc.cfg
#		(update and debug paramaters are ignored, not RUMC connection is made)
# -c	location of RUMC config file. Default specified below.
# -a	location of AMD list file. Default specified below.

#config 
RUMCCONF=/etc/rumc.cfg
AMDLIST=/etc/amdlist.cfg
SCRIPTDIR=/opt/rtmarchive
DEBUG=0





# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
WGET=`which wget`
CAT=`which cat`
OPENSSL=`which openssl`
XXD=`which xxd`
TEE=`which tee`
XSLTPROC=`which xsltproc`
MKTEMP=`which mktemp`
CURL=`which curl`

#command line parameters
ENCODE=0
DECODE=0
UPDATELIST=0
OPTS=1
while getopts ":uhdec:a:z:" OPT; do
	case $OPT in
		u)
			UPDATELIST=1
			OPTS=1
			;;
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		e)
			OPTS=1
			ENCODE=-e
			;;
		c)
			RUMCCONF=$OPTARG
			;;
		a)
			AMDLIST=$OPTARG
			;;
		z)
			ENCPASS=$OPTARG
			DECODE=-z
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
	echo -e "*** INFO: Usage: $0 [-h] [-u] [-a amdlist] [-c rumcconfig] [-e]"
	echo -e "-h This help"
	echo -e "-u Update AMD list"
	echo -e "-a Full path to amdlist file, default $AMDLIST"
	echo -e "-c Full path to rumcconfig file, default $RUMCCONF"
	echo -e ""
	echo -e "-e Encode a RUMC password"
	exit 0
fi



RUMKEY=6f018ccd57a6f1d5757a13674a75c1c2

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`]: $1" 
}

function derumpassword {
	echo "`echo "$@" | $XXD -r -p | $OPENSSL enc -aes-128-ecb -d -K $RUMKEY`"
}

function rumpassword {
	echo "`echo $@ | $OPENSSL enc -aes-128-ecb -e -K $RUMKEY | $XXD -p`"
}

function read_password {
	unset password
	prompt=${1:-"Password: "}
	while IFS= read -p "$prompt" -r -s -n 1 char
	do
		if [[ $char == $'\0' ]]
		then
		    break
		fi
		prompt='*'
		password+="$char"
	done
	echo "$password"
}

function urlencode {
	# urlencode <string>
	IFS=
	length="${#1}"
	for (( i = 0; i < length; i++ )); do
		local c="${1:i:1}"
		case $c in
			[a-zA-Z0-9.~_-]) printf "$c" ;;
		*) printf '%s' "$c" | $XXD -p -c1 |
			while read c; do printf '%%%s' "$c"; done ;;
		esac
	done
}

tstart=`date -u +%s`
techo "rtmarchive System: RUM Console AMD Query script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2016"

if [ $ENCODE == "-e" ]; then 
	IFS=
	EPASS=$(read_password "Enter password:   ")
	echo -e ""
	EPASS2=$(read_password "Confirm password: ")
	echo -e ""
	if [ "$EPASS" == "$EPASS2" ]; then
		debugecho "[$EPASS]"
		ENCPASS=$(rumpassword $EPASS)
		techo "Encoded password: $ENCPASS"
		DPASS=$(derumpassword $ENCPASS)
		debugecho "Decoded password: [$DPASS]"
		if [ ! "$DPASS" == "$EPASS" ]; then techo "*** FAILURE: Password encoding failed, input password [$EPASS] doesn't match decoded password [$DPASS]."; exit 1; fi
		exit 0
	else
		techo "Passwords don't match, aborting."
		exit 1
	fi
fi

if [ $DECODE == "-z" ]; then
	IFS=
	echo -E "Decoded password in [] brackets: [$(derumpassword $ENCPASS)]"
	exit 0
fi


if [ $UPDATELIST -ne 1 ]; then AMDLIST=/dev/null; fi
if [ ! -w $AMDLIST ]; then
	techo -e "\e[31m*** FATAL:\e[0m Can't update $AMDLIST"
	exit 1
fi
echo -n "" | $TEE $AMDLIST

rumcs=0
IFS=", "
while read RUMNAME RUMPROT RUMADDR RUMPORT RUMUSER RUMHASH; do

	#blank line
	if [ "$RUMNAME,$RUMPROT,$RUMADDR,$RUMPORT,$RUMUSER,$RUMHASH" == ",,,,," ]; then continue; fi

	#comment line
	if [[ $RUMNAME == "#"* ]]; then continue; fi

	debugecho "$RUMNAME,$RUMPROT,$RUMADDR,$RUMPORT,$RUMUSER,$RUMHASH"
	rumcs=$((rumcs+1))

	RUMPASS=$(derumpassword $RUMHASH)


	#query RUMC
	techo "Connecting to RUM Console $RUMNAME on: $RUMPROT://$RUMADDR:$RUMPORT/"
	#query RUMC server for XML data of all devices
	set +e
	XML=`$CURL --insecure --silent --header "Accept: application/xml" -u $RUMUSER:$RUMPASS $RUMPROT://$RUMADDR:$RUMPORT/cxf/rest/backup -o -`
	if [ $? -ne 0 ]; then techo "\e[33m***WARNING:\e[0m RUM Console '$RUMNAME' on $RUMPROT://$RUMADDR:$RUMPORT/ not responding/bad logon/etc." ; continue; fi
	set -e
	debugecho "Returned XML: $XML" 2
	if [ "$XML" == "" ]; then techo "\e[33m***WARNING:\e[0m RUM Console '$RUMNAME' on $RUMPROT://$RUMADDR:$RUMPORT/ not responding/bad logon/etc."; continue; fi

	if [[ "$XML" == *"Unauthorized"* ]]; then techo "\e[31m***ERROR:\e[0m RUM Console '$RUMNAME' on $RUMPROT://$RUMADDR:$RUMPORT/ Incorrect logon."; continue; fi

	techo "Parsing response from RUM Console...."
	PARSED=`echo -e $XML | $XSLTPROC --nonet $SCRIPTDIR/rumcquery.xslt -`
	if [ $? -ne 0 ]; then techo "\e[31m***ERROR:\e[0m RUM Console '$RUMNAME' on $RUMPROT://$RUMADDR:$RUMPORT/ returned bad or incomplete data.\nDownloaded XML: [$XML]\nParsed result: [$PARSED]"; continue; fi

	#test for empty result - probably bad/unknown data from RUMC
	if [ "$PARSED" == "" ]; then
		debugecho "No results from RUMC after XSLT parse"
		techo "\e[33m***WARNING:\e[0m RUM Console '$RUMNAME' reported no AMDs."
		continue
	fi
		
	IFS=$''
	debugecho "Parsed result: $PARSED" 2
	
	
	techo "Creating $AMDLIST output"
	IFS=$','
	echo -n "" | $TEE $AMDLIST
	echo "# rtmarchive AMD List" | $TEE -a $AMDLIST
	echo "# Generated by $0 on "`date` | $TEE -a $AMDLIST
	
	echo "$PARSED" | while read a b c d e f g; do
		#a: amd name
		#b: http/https flag
		#c: port number
		#d: password
		#e: host name/ip
		#f: amd version
		#g: username
	
		#blank line
		if [ "$a-$b-$c-$d-$e-$f-$g" == "------" ]; then continue; fi

		debugecho "parsing line: $a-$b-$c-$d-$e-$f-$g"

		if [ "$a" == "" ]; then
			#blank name, reuse address
			debugecho "blank name found", 2
			a=${e//\./_}_$c
			debugecho "using: [$a]", 2
		fi

		if [ "$b" == "false" ]; then 
			b=http
		else 
			b=https 
		fi
		preIFS=$IFS
		IFS=
		d=$(derumpassword $d)
		debugecho "d [$d]" 3
		if [ "$d" == "" ]; then debugecho "NULL password detected for [$e:$c], aborting check"; continue; fi 
		d=$(urlencode $d)
		g=$(urlencode $g)
		url=$b://$g:$d@$e:$c/
		IFS=$preIFS
		#check connection to AMD
		set +e
		RETURN=`$WGET --no-check-certificate -q --header="Accept: application/xml" -O - $url/RtmDataServlet?cmd=version`
		if [ $? -ne 0 ]; then RETURN=; fi
		set -e
		debugecho "AMD Version Info: $RETURN" 2
		if [[ $RETURN == *"Emulated"* ]]; then
			#Archive AMD, disable it.
			echo -E "# AMD '$a' ($e:$c) is an archive AMD. Disabling it." | $TEE -a $AMDLIST
			echo -E "D,$url,$a" | $TEE -a $AMDLIST
		elif [[ $RETURN == "" ]]; then
			#AMD returned no version data? not working? disable it
			techo "\e[33m***WARNING:\e[0m No response from AMD '$a' ($e:$c)"
			echo -E "# AMD '$a' ($e:$c) returned no version info or not responding, disabling it." | $TEE -a $AMDLIST
			echo -E "D,$url,$a" | $TEE -a $AMDLIST
		else
			echo -E "# AMD '$a' ($e:$c) version: $f active." | $TEE -a $AMDLIST
			echo -E "A,$url,$a" | $TEE -a $AMDLIST
		fi
		
	done;

done < $RUMCCONF

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "\e[0mCompleted $rumcs RUM Console queries in $tdur seconds."
exit 0

