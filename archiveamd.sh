# archiveamd script
# Chris Vidler Dynatrace DCRUM SME
#
# called from rtmarchive.sh connects to an AMD determines teh delta of data files and downloads to storage
#
# Parameters:  name url basedir
# name: name to use for AMD, human readable, must be unique or bad stuff will happen
# url: url to use to connect tot he AMD, include logon credentials
# basedir: where to save stuff.

AMDNAME=$1
URL=$2
BASEDIR=$3
DEBUG=$4
AMDDIR=$BASEDIR/$AMDNAME
AWK=`which awk`
WGET=`which wget`
GUNZIP=`which gunzip`
TOUCH=`which touch`

#echo $AMDNAME, $URL, $BASEDIR

function test {
	"$@"
	local status=$?
	if [ $status -ne 0 ]; then
		echo -e "\e[33m***WARNING:\e[39m Non-zero exit code $status for '$1'" >&2
	fi
	return $status
}


echo Archiving AMD: $AMDNAME beginning

# check if data folder exists, create if needed.
if [ ! -d "$AMDDIR" ]; then
	mkdir "$AMDDIR"
	echo ***NOTE Created AMD data folder $AMDDIR.
fi

# check access to data folder
if [ ! -w "$AMDDIR" ]; then
	echo -e "\e[31m***FATAL:\e[39m Cannot write to $AMDDIR Aborting."
	exit 1
fi

# check for existing previous data file list, touch it if needed, so we can download everything.
if [ ! -r "$AMDDIR/prevdir.lst" ]; then
	touch "$AMDDIR/prevdir.lst"
	echo newfile > "$AMDDIR/prevdir.lst"
fi

# check for existing current data file list (there shouldn't be one if the script works, remove it)
if [ -f "$AMDDIR/currdir.lst" ]; then
	rm "$AMDDIR/currdir.lst"
fi

# Get data file listing from AMD
test $WGET --quiet --no-check-certificate -O - $URL/RtmDataServlet?cmd=zip_dir | $GUNZIP > $AMDDIR/currdir.lst
if [ $? -ne 0 ]; then
	echo -e "\e[31m***FATAL:\e[39m $? Can not download directory listing from AMD: $AMDNAME"
	exit 1
fi

downloaded=0
warnings=0

# determine delta of current file list from previous and download them all.
while read p; do

	# Validate file name is something we want.
	if [ "`echo ${p} | $AWK ' /[a-z0-9]+_[0-9a-f]+_[15]_[tb]/ '`" == "${p}" ]; then

	        if [ $DEBUG -ne 0 ]; then echo Downloading ${p} from $AMDNAME; fi
		test $WGET --quiet --no-check-certificate -O - $URL/RtmDataServlet?cmd=zip_entry\&entry=${p} | $GUNZIP > $AMDDIR/${p}
		if [ $? -ne 0 ]; then
			warnings=$((warnings + 1))
	        	echo -e "\e[33m***WARNING:\e[39m $? Can not download file: ${p} from AMD: $AMDNAME"
		fi
		downloaded=$((downloaded + 1))
	
		# Set file timestamp correctly
		# extract timestamp from file name and convert it to require format CCYYMMDDhhmm.SS
		FTS=`echo ${p} | $AWK -F"_" ' { print strftime("%Y%m%d%H%M.%S",strtonum("0x"$2),1); } '`
		$TOUCH -c -t $FTS  "$AMDDIR/${p}"
	
		# Proces contents here
		if [[ ${p} =~ zdata_.* ]]; then
			# get UUID from zdata, use to check if the AMD changes unexpectedly.
			UUID=`$AWK -F" " '$1=="#AmdUUID:" { print $2 }' $AMDDIR/${p}`
			if [ ! -f "$AMDDIR/uuid.lst" ]; then
				echo $UUID > $AMDDIR/uuid.lst
			else
				while read k; do
					OLDUUID=${k}
				done < $AMDDIR/uuid.lst
				if [ ! "$OLDUUID" == "$UUID" ]; then
					echo -e "\e[33m***WARNING:\e[39m UUID Mismatch on AMD: $AMDNAME, Old: $OLDUUID, New: $UUID"
					echo -e "\e[33m***WARNING:\e[39m If this is expected remove file $AMDDIR/uuid.lst to clear the error"
				fi
			fi
	
			# get TS from zdata, keep record of all timestamps we have archived.
			TS=`$AWK -F" " '$1=="#TS:" { print $2 }' $AMDDIR/${p}` 
			echo $TS >> $AMDDIR/timestamps.lst
		fi
	else
		echo -e "\e[33m***WARNING:\e[39m Unknown file: ${p} on AMD: $AMDNAME"
	fi
done < <($AWK 'NR==FNR{a[$1]++;next;}!($0 in a)' $AMDDIR/prevdir.lst $AMDDIR/currdir.lst)


# finally, make the current dir list the previous one.
rm $AMDDIR/prevdir.lst
mv $AMDDIR/currdir.lst $AMDDIR/prevdir.lst

echo Archiving AMD: $AMDNAME complete, downloaded $downloaded
if [ $warnings -ne 0 ]; then echo Warnings: $warnings; fi




