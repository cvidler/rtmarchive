# queryrcon Script
# Chris Vidler - Dynatrace DCRUM SME 2015
#
# Builds amdlist.cfg from querying RUM console.
#

#config 
RUMCCONF=/etc/rumc.cfg
AMDLIST=/etc/amdlist.cfg
DEBUG=${1:-1}


#temp vars
RUMPROT=https
RUMADDR=192.168.0.45
RUMPORT=4183
RUMUSER=rumcaccess
RUMHASH=1ec72b5061df466c929f2cc4eb1d07a0


# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
WGET=`which wget`

function debugecho {
        if [ $DEBUG -ne 0 ]; then echo -e "$@"; fi
	}

function derumpassword {
	echo `printf %s "$@" | xxd -r -p | openssl enc -aes-128-ecb -d -K 6f018ccd57a6f1d5757a13674a75c1c2`
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


RUMPASS=$(derumpassword $RUMHASH)


#query RUMC server for XML data of all devices
#XML=`wget --no-check-certificate -q --header="Accept: application/xml" -O - --user '$RUMUSER' --password '$RUMPASS' $RUMPROT://$RUMADDR:$RUMPORT/cxf/rest/backup`
XML=`wget --no-check-certificate -q --header="Accept: application/xml" -O - --user "$RUMUSER" --password "$RUMPASS" $RUMPROT://$RUMADDR:$RUMPORT/cxf/rest/backup`

#debugecho "$XML"


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

PARSED=`echo -e $XML | $AWK ' BEGIN { FS="|"; RS="</devices>"; OFS=","; } match($0,"<name>([a-zA-Z0-9]*?)</name><type>0<.+?\"IS_HTTPS\" value=\"([a-z]+?)\"/>.*?\"PORT\" value=\"([0-9]+?)\"/>.+?\"PASSWORD\" value=\"(.*?)\"/>.*?\"IP\" value=\"([^\"]*?)\"/>.*?\"VERSION\" value=\"([^\"]*?)\"/>.*?\"USER\" value=\"([^\"]*?)\"/>",a)  { print a[1],a[2],a[3],a[4],a[5],a[6],a[7] }'`

debugecho "$PARSED"

IFS=$', '
echo $PARSED | while read a b c d e f g; do
	
	#echo -e "$a-$b-$c-$d-$e-$f-$g"
	if [ $f == 13.0.0.000 ] || [ $f == 0.0.0 ]; then continue; fi
	if [ $b == false ]; then 
		b=http
	else 
		b=https 
	fi
	d=$(derumpassword $d)
	d=$(urlencode $d)
	g=$(urlencode $g)
	echo -e "A.$b://$g:$d@$e:$c/,$a"

done;



