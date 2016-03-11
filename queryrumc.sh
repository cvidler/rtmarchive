# queryrcon Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Builds amdlist.cfg from querying RUM console.
# parameters:
# queryrumc.sh [update] [debug] [-e password] 
# 0|1	update amdlist.cfg file in path below default 0 OFF
# 0|1	debug output debug info. default 0 OFF
# -e	encrypt a password for RUMC access used to add RUMC entries to rumc.cfg
#		(update and debug paramaters are ignored, not RUMC connection is made)
#

#config 
RUMCCONF=/etc/rumc.cfg
AMDLIST=/etc/amdlist.cfg
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

#command line parameters
ENCODE=0
UPDATELIST=0
OPTS=1
while getopts ":uhde:c:a:" OPT; do
	case $OPT in
		u)
			UPDATELIST=1
			OPTS=1
			;;
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=1
			;;
		e)
			OPTS=1
			ENCODE=-e
			EPASS=$OPTARG
			;;
		c)
			RUMCCONF=$OPTARG
			;;
		a)
			AMDLIST=$OPTARG
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
	echo -e "*** INFO: Usage: $0 [-h] [-u] [-a amdlist] [-c rumcconfig] [-e password]"
	echo -e "-h This help"
	echo -e "-u Update AMD list"
	echo -e "-a Full path to amdlist file, default $AMDLIST"
	echo -e "-c Full path to rumcconfig file, default $RUMCCONF"
	echo -e ""
	echo -e "-e password Encode a RUMC password"
	exit 0
fi



RUMKEY=6f018ccd57a6f1d5757a13674a75c1c2

function debugecho {
        if [ $DEBUG -ne 0 ]; then echo -e "\e[2m***DEBUG\n$@\e[0m\n"; fi
	}

function derumpassword {
	echo `echo "$@" | $XXD -r -p | $OPENSSL enc -aes-128-ecb -d -K $RUMKEY`
}

function rumpassword {
	echo `echo $@ | $OPENSSL enc -aes-128-ecb -e -K $RUMKEY | $XXD -p`
}

urlencode() {
	# urlencode <string>
	
	local length="${#1}"
	for (( i = 0; i < length; i++ )); do
		local c="${1:i:1}"
		case $c in
			[a-zA-Z0-9.~_-]) printf "$c" ;;
		*) printf '%s' "$c" | xxd -p -c1 |
			while read c; do printf '%%%s' "$c"; done ;;
		esac
	done
}


echo "rtmarchive System: RUM Console AMD Query script"
echo "Chris Vidler - Dynatrace DCRUM SME, 2016"
echo ""

if [ $ENCODE == "-e" ]; then 
	echo -e "Encoded password: $(rumpassword $EPASS)" 
	echo -e "Complete"
	exit
fi


if [ $UPDATELIST -ne 1 ]; then AMDLIST=/dev/null; fi
if [ ! -w $AMDLIST ]; then
	echo -e "\e[31m*** FATAL:\e[0m Can't update $AMDLIST"
	exit
fi
echo -n "" | $TEE $AMDLIST

IFS=", "
echo `$CAT $RUMCCONF` | while read RUMNAME RUMPROT RUMADDR RUMPORT RUMUSER RUMHASH; do

	if [[ $RUMNAME == "#"* ]]; then continue; fi

	debugecho $RUMNAME,$RUMPROT,$RUMADDR,$RUMPORT,$RUMUSER,$RUMHASH

	RUMPASS=$(derumpassword $RUMHASH)


	#query RUMC
	echo "Connecting to RUM Console $RUMNAME on: $RUMPROT://$RUMADDR:$RUMPORT/"
	#query RUMC server for XML data of all devices
	#XML=`wget --no-check-certificate -q --header="Accept: application/xml" -O - --user '$RUMUSER' --password '$RUMPASS' $RUMPROT://$RUMADDR:$RUMPORT/cxf/rest/backup`
	set +e
	XML=`$WGET --no-check-certificate -q --header="Accept: application/xml" -O - --user "$RUMUSER" --password "$RUMPASS" $RUMPROT://$RUMADDR:$RUMPORT/cxf/rest/backup`
	if [ $? -ne 0 ]; then echo -e "\e[31m***FATAL:\e[0m RUM Console '$RUMNAME' on $RUMPROT://$RUMADDR:$RUMPORT/ not responding/bad logon/etc." ; exit; fi
	set -e
	debugecho "$XML"

	#Extract required info from XML
	#gawk ' BEGIN { FS="|"; RS="</devices>"; OFS=","; } match($0,"<name>([a-zA-Z0-9]*?)</name><type>0<.+?\"IS_HTTPS\" value=\"([a-z]+?)\"/>.*?\"PORT\" value=\"([0-9]+?)\"/>.+?\"PASSWORD\" value=\"(.*?)\"/>.*?\"IP\" value=\"([^\"]*?)\"/>.*?\"VERSION\" value=\"([^\"]*?)\"/>.*?\"USER\" value=\"([^\"]*?)\"/>",a)  { print a[1],a[2],a[3],a[4],a[5],a[6],a[7] }'
	# returns for each AMD in the RUMC
	# 1: name
	# 2: http/https flag
	# 3: port number for comms
	# 4: encrypted password
	# 5: address for comms
	# 6: version number (eAMDs return 0.0.0)
	# 7: username for access
	
	#12.3 and 12.4 AMDs
	PARSED=`echo -e $XML | $AWK ' BEGIN { FS="|"; RS="</devices>"; OFS=","; } match($0,"<name>([a-zA-Z0-9]*?)</name><type>0<.+?\"IS_HTTPS\" value=\"([a-z]+?)\"/>.*?\"PORT\" value=\"([0-9]+?)\"/>.+?\"PASSWORD\" value=\"([a-fA-F0-9]+?)\"/>.*?\"IP\" value=\"([^\"]*?)\"/>.*?\"VERSION\" value=\"([^\"]*?)\"/>.*?\"USER\" value=\"([^\"]*?)\"/>",a)  { print a[1],a[2],a[3],a[4],a[5],a[6],a[7] }'`
	#12.4 NG AMDs are different.
	PARSEDNG=`echo -e $XML | $AWK ' BEGIN { FS="|"; RS="</devices>"; OFS=","; } match($0,"<name>([a-zA-Z0-9]*?)</name><type>0<.+?\"IS_HTTPS\" value=\"([a-z]+?)\"/>.*?\"PASSWORD\" value=\"([a-fA-F0-9]+?)\"/>.+?\"PORT\" value=\"([0-9]+?)\"/>.*?\"IP\" value=\"([^\"]*?)\"/>.*?\"VERSION\" value=\"([^\"]*?)\"/>.*?\"USER\" value=\"([^\"]*?)\"/>",a)  { print a[1],a[2],a[4],a[3],a[5],a[6],a[7] }'`
	
	echo "Parsing response from RUM Console...."
		
	IFS=$''
	PARSED=`echo -e "$PARSED\n$PARSEDNG"`
	debugecho $PARSED
	
	
	echo "Creating $AMDLIST output"
	IFS=$', '
	echo -n "" | $TEE $AMDLIST
	echo "# rtmarchive AMD List" | $TEE -a $AMDLIST
	echo "# Generated by $0 on "`date` | $TEE -a $AMDLIST
	
	echo $PARSED | while read a b c d e f g; do
	
		#echo -e "$a-$b-$c-$d-$e-$f-$g"
		if [ $b == false ]; then 
			b=http
		else 
			b=https 
		fi
		d=$(derumpassword $d)
		d=$(urlencode $d)
		g=$(urlencode $g)
		url=$b://$g:$d@$e:$c/
		#check connection to AMD
		set +e
		RETURN=`$WGET --no-check-certificate -q --header="Accept: application/xml" -O - $url/RtmDataServlet?cmd=version`
		if [ $? -ne 0 ]; then RETURN=; fi
		set -e
		debugecho $RETURN
		if [[ $RETURN == *"Emulated"* ]]; then
			#Archive AMD, disable it.
			echo -en "\e[2m"
			echo "# AMD '$a' ($e:$c) is an archive AMD. Disabling it." | $TEE -a $AMDLIST
			echo "D,$url,$a" | $TEE -a $AMDLIST
			echo -en "\e[0m"
		elif [[ $RETURN == "" ]]; then
			#AMD returned no version data? not working? disable it
			echo -e "\e[33m***WARNING: No response from AMD '$a' ($e:$c)\e[0m\e[2m"
			echo "# AMD '$a' ($e:$c) returned no version info or not responding, disabling it." | $TEE -a $AMDLIST
			echo "D,$url,$a" | $TEE -a $AMDLIST
			echo -en "\e[0m"
		else
			echo -en "\e[32m"
			echo "# AMD '$a' ($e:$c) version: $f active." | $TEE -a $AMDLIST
			echo "A,$url,$a" | $TEE -a $AMDLIST
			echo -en "\e[0m"
		fi
		
	done;

done;

echo -e "\e[0mCompleted."

