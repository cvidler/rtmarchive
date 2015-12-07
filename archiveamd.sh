# archiveamd script
# Chris Vidler Dynatrace DCRUM SME
#
# called from rtmarchive.sh connects to an AMD determines teh delta of data files and downloads to storage
#
# Parameters:  name url basedir
# name: name to use for AMD, human readable, must be unique or bad stuff will happen
# url: url to use to connect tot he AMD, include logon credentials
# basedir: where to save stuff.



# Script below do not edit
set -euo pipefail
IFS=$',\n\t'

AMDNAME=${1:-}
URL=${2:-}
BASEDIR=${3:-}
DEBUG=${4:-0}
AMDDIR=$BASEDIR/$AMDNAME
AWK=`which awk`
WGET=`which wget`
GUNZIP=`which gunzip`
TOUCH=`which touch`
MKTEMP=`which mktemp`

function test {
	set +e
	"$@"
	local status=$?
	set -e
	if [ $status -ne 0 ]; then
		debugecho "\e[33m***WARNING:\e[0m Non-zero exit code $status for '$@'" >&2
	fi
	return $status
}

function debugecho {
	if [ $DEBUG -ne 0 ]; then echo -e "$@"; fi
}


#check passed parameters

debugecho "***DEBUG: Parameters [$AMDNAME], [$URL], [$BASEDIR], [$DEBUG]"

if [ -z "$AMDNAME" ]; then
	echo -e "\e[31m***FATAL:\e[0m AMDNAME parameter not supplied. Aborting." >&2
	exit 1
fi

if [ -z "$URL" ]; then
        echo -e "\e[31m***FATAL:\e[0m URL parameter not supplied. Aborting." >&2
        exit 1
fi

echo "Archiving AMD: $AMDNAME beginning"

# check if data folder exists, create if needed.
if [ ! -d "$AMDDIR" ]; then
	mkdir "$AMDDIR"
	debugecho "***DEBUG: Created AMD data folder $AMDDIR."
fi

# check access to data folder
if [ ! -w "$AMDDIR" ]; then
	echo -e "\e[31m***FATAL:\e[0m Cannot write to $AMDDIR. Aborting." >&2
	exit 1
fi

# check for existing previous data file list, touch it if needed, so we can download everything.
if [ ! -r "$AMDDIR/prevdir.lst" ]; then
	touch "$AMDDIR/prevdir.lst"
	echo "newfile" > "$AMDDIR/prevdir.lst"
fi

# check for existing current data file list (there shouldn't be one if the script works, remove it)
if [ -f "$AMDDIR/currdir.lst" ]; then
	debugecho "***DEBUG: Found stale currdidr.lst. Removing it."
	rm "$AMDDIR/currdir.lst"
fi

# Get data file listing from AMD, try 3 times, abort (FATAL) if failed
fail=0
tmpfile=`$MKTEMP`
for i in 1 2 3; do
	set +e
	$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmDataServlet?cmd=zip_dir
	if [ $? -ne 0 ]; then
		echo -e "\e[31m***FATAL:\e[0m Can not download directory listing from AMD: $AMDNAME try: ${i}" >&2
		fail=$((fail + 1))
	else
		cat $tmpfile | gunzip -c > $AMDDIR/currdir.lst
		break
	fi
	set -e
done
rm $tmpfile
if [ $fail -ne 0 ]; then echo -e "\e[31m***FATAL:\e[0m Could not download directory listing from AMD: $AMDNAME Aborting." >&2 ; exit 1; fi


downloaded=0
warnings=0

# determine delta of current file list from previous and download them all.
while read p; do

	# Validate file name is something we want.
	if [ "`echo ${p} | $AWK ' /[a-z0-9]+_[0-9a-f]+_[150a]+_[tb].*/ '`" == "${p}" ]; then
	 	# Extract date codes from file name	
		year=`echo ${p} | $AWK -F"_" ' { print strftime("%Y",strtonum("0x"$2),1); } '`
		month=`echo ${p} | $AWK -F"_" ' { print strftime("%m",strtonum("0x"$2),1); } '`
		day=`echo ${p} | $AWK -F"_" ' { print strftime("%d",strtonum("0x"$2),1); } '`
		#echo ${file},$year,$month,$day 
		# Check for correct folder structure - create if needed
		ARCDIR=$AMDDIR/$year/$month/$day/
		if [ ! -w "$ARCDIR" ]; then
			debugecho "***DEBUG: Creating archive directory: $ARCDIR"
			mkdir -p "$ARCDIR"
		fi
		file=$ARCDIR/${p}

		if [ -r "$file" ]; then continue; fi	# already exists skip downloading

	        debugecho "***DEBUG: Downloading ${p} from $AMDNAME to $file"
		# Try download 3 times
		warn=0
		tmpfile=`$MKTEMP`
		for i in 1 2 3 ; do
			set +e
			$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmDataServlet?cmd=zip_entry\&entry=${p} 
			if [ $? -ne 0 ]; then
				warn=$((warn + 1))
	        		debugecho "\e[33m***WARNING:\e[39m Can not download file: ${p} from AMD: $AMDNAME try: ${i}" >&2
			else
				cat $tmpfile | gunzip -c > $file
				downloaded=$((downloaded + 1))
				break
			fi
			set -e
		done
		rm $tmpfile
		if [ $warn -ne 0 ]; then echo -e "\e[33m***WARNING:\e[39m Could not download file: ${p} from AMD: $AMDNAME" >&2 ; warnings=$((warnings + 1)); fi
	
		# Set file timestamp correctly
		# extract timestamp from file name and convert it to require format CCYYMMDDhhmm.SS
		FTS=`echo ${p} | $AWK -F"_" ' { print strftime("%Y%m%d%H%M.%S",strtonum("0x"$2),1); } '`
		$TOUCH -c -t $FTS  "$file"
	
		# Proces contents here
		if [[ ${p} =~ zdata_.* ]]; then
			# get UUID from zdata, use to check if the AMD changes unexpectedly.
			UUID=`$AWK -F" " '$1=="#AmdUUID:" { print $2 }' $file`
			if [ ! -f "$AMDDIR/uuid.lst" ]; then
				echo $UUID > $AMDDIR/uuid.lst
			else
				while read k; do
					OLDUUID=${k}
				done < $AMDDIR/uuid.lst
				if [ ! "$OLDUUID" == "$UUID" ]; then
					echo -e "\e[33m***WARNING:\e[39m UUID Mismatch on AMD: $AMDNAME, Old: $OLDUUID, New: $UUID" >&2
					echo -e "\e[33m***WARNING:\e[39m If this is expected remove file $AMDDIR/uuid.lst to clear the error" >&2
				fi
			fi
	
			# get TS from zdata, keep record of all timestamps we have archived.
			#TS=`$AWK -F" " '$1=="#TS:" { print $2 }' $file` 
			#echo $TS >> $AMDDIR/timestamps.lst
		fi
	else
		debugecho "\e[33m***WARNING:\e[39m Unknown file: ${p} on AMD: $AMDNAME" >&2
	fi
done < <($AWK 'NR==FNR{a[$1]++;next;}!($0 in a)' $AMDDIR/prevdir.lst $AMDDIR/currdir.lst)


# finally, make the current dir list the previous one.
rm $AMDDIR/prevdir.lst
mv $AMDDIR/currdir.lst $AMDDIR/prevdir.lst

echo -ne "Archiving AMD: $AMDNAME complete, downloaded $downloaded"
if [ $warnings -ne 0 ]; then echo -e " - \e[33mWarnings: $warnings\e[0m"; fi
echo -e ""

