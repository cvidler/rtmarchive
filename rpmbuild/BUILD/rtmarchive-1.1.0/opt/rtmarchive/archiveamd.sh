# archiveamd script
# Chris Vidler Dynatrace DCRUM SME
#
# called from rtmarchive.sh connects to an AMD determines teh delta of data files and downloads to storage
#
# Parameters:  -n name -u url -b basedir [-d]
# -n name: name to use for AMD, human readable, must be unique or bad stuff will happen
# -u url: url to use to connect tot he AMD, include logon credentials
# -b basedir: where to save stuff.
# -d: debug

# Config defaults
DEBUG=0

# zdata file extensions for HS AMD (12.4.5+)
ZDATAEXTS=db,dns,gen,h,he,ica,ip,mq,of,rmi,sap,smb,unv,voip,vol,xml
# vdata/vdataidx extensions for HS AMD
VDATAEXTS=db,h,mq,of,rmi,sap,unv,xml
# hpdata extensions for HS AMD
HPDATAEXTS=db,h,ica,mq,of,rmi,sap,unv,xml
# headerdata exts...
HDATAEXTS=h,of,xml
# ndata exts
NDATAEXTS=rtm
# amddata exts
AMDDATAEXTS=rtm,amd



# --- Script below do not edit ---
set -euo pipefail
IFS=$',\n\t'

#AMDNAME=${1:-}
#URL=${2:-}
#BASEDIR=${3:-}
#DEBUG=${4:-0}
#AMDDIR=$BASEDIR/$AMDNAME
AWK=`which awk`
WGET=`which wget`
GUNZIP=`which gunzip`
TOUCH=`which touch`
MKTEMP=`which mktemp`
CAT=`which cat`
TAIL=`which tail`
HEAD=`which head`
DATE=`which date`

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
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then echo -e "*** DEBUG[$dbglevel]: $1"; fi
}


# command line arguments
AMDNAME=0
BASEDIR=0
URL=0
NSET=0
BSET=0
USET=0
OPTS=1
while getopts ":dhn:b:u:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		n)
			if [ $NSET -ne 0 ] ; then OPTS=0; fi
			AMDNAME=$OPTARG
			NSET=1
			OPTS=1
			;;
		b)
			if [ $BSET -ne 0 ]; then OPTS=0; fi
			BASEDIR=$OPTARG
			BSET=1
			OPTS=1
			;;
		u)
			if [ $USET -ne 0 ]; then OPTS=0; fi
			URL=$OPTARG
			USET=1
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

if [ $USET -eq 0 ] || [ $BSET -eq 0 ] || [ $USET -eq 0 ]; then OPTS=0; fi

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] -n amdname -u amdurl -b basearchivedir"
	echo -e "-h This help"
	echo -e "-n amdname AMD descriptive name. Required"
	echo -e "-u amdurl AMD connection url. Required"
	echo -e "-b basearchivedir Archive directory path. Required"
	exit 0
fi


AMDDIR=$BASEDIR/$AMDNAME


#check passed parameters

debugecho "Passed Parameters [$AMDNAME], [$URL], [$BASEDIR], [$DEBUG]", 2

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
	debugecho "Created AMD data folder $AMDDIR."
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
	debugecho "Found stale currdidr.lst. Removing it."
	rm "$AMDDIR/currdir.lst"
fi

# Get data file listing from AMD, try 3 times, abort (FATAL) if failed
fail=0
tmpfile=`$MKTEMP`
for i in 1 2 3; do
	set +e
	$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmDataServlet?cmd=zip_dir
	if [ $? -ne 0 ]; then
		echo -e "\e[33m***WARNING:\e[0m Can not download directory listing from AMD: $AMDNAME try: ${i}" >&2
		fail=$((fail + 1))
	else
		$CAT $tmpfile | $GUNZIP -q -c > $AMDDIR/currdir.lst
		break
	fi
	set -e
done
rm $tmpfile
if [ $fail -ne 0 ]; then echo -e "\e[31m***FATAL:\e[0m Could not download directory listing from AMD: $AMDNAME Aborting." >&2 ; exit 1; fi


# test for HS AMD, version commands responds with line "ng.probe=true"
fail=0
tmpfile=`$MKTEMP`
for i in 1 2 3; do
	set +e
	$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmDataServlet?cmd=version
	if [ $? -ne 0 ]; then
		echo -e "\e[31m***FATAL:\e[0m Can not download version info from AMD: $AMDNAME try: ${i}" >&2
		fail=$((fail + 1))
	else
		HSAMD=`$AWK '/ng\.probe=true/ { print "1" }' "$tmpfile"`
		break
	fi
	set -e
done
rm $tmpfile
if [ $fail -ne 0 ]; then echo -e "\e[31m***FATAL:\e[0m Could not download version info from AMD: $AMDNAME Aborting." >&2 ; exit 1; fi
debugecho "HS AMD detected: $HSAMD"


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
			debugecho "Creating archive directory: $ARCDIR"
			mkdir -p "$ARCDIR"
		fi
		file=$ARCDIR/${p}

		# HS AMD produces many zdata files split, these are NOT listed in the downloaded directory listing, only the base names - yay :(
		# we must handle this. 
		filelist=""
		if [ $HSAMD == 1 ] && [ -z "${p##zdata_*}" ]; then
			# build required filenames to download
			debugecho "[$ZDATAEXTS]", 2
			for e in $ZDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		elif [ $HSAMD == 1 ] && ( [ -z "${p##vdata_*}" ] || [ -z "${p##vdataidx_*}" ] ); then
			for e in $VDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		elif [ $HSAMD == 1 ] &&  [ -z "${p##hpdata_*}" ]; then
			for e in $HPDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		elif [ $HSAMD == 1 ] && [ -z "${p##headerdata_*}" ]; then
			for e in $HDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		elif [ $HSAMD == 1 ] && [ -z "${p##ndata_*}" ]; then
			for e in $NDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		elif [ $HSAMD == 1 ] && [ -z "${p##amddata_*}" ]; then
			for e in $AMDDATAEXTS; do
				filelist=${filelist}${p}_${e},
			done
		else
			filelist=${p}
		fi
		debugecho "filelist: $filelist", 2

		for f in $filelist; do
			file=$ARCDIR/${f}

			if [ -r "$file" ]; then continue; fi	# already exists skip downloading

			debugecho "Downloading ${f} from $AMDNAME to $file"
			# Try download 3 times
			warn=0
			tmpfile=`$MKTEMP`
			for i in 1 2 3 ; do
				set +e
				$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmDataServlet?cmd=zip_entry\&entry=${f}
				if [ $? -ne 0 ]; then
					warn=$((warn + 1))
			    		debugecho "\e[33m*** WARNING:\e[39m Can not download file: ${f} from AMD: $AMDNAME try: ${i}" >&2
				else
					$CAT "$tmpfile" | $GUNZIP -q -c > "$file"
					downloaded=$((downloaded + 1))
					break
				fi
				set -e
			done
			rm $tmpfile
			if [ $warn -ne 0 ]; then echo -e "\e[33m*** WARNING:\e[39m Could not download file: ${f} from AMD: $AMDNAME" >&2 ; warnings=$((warnings + 1)); fi
	
			# Set file timestamp correctly
			# extract timestamp from file name and convert it to require format CCYYMMDDhhmm.SS
			FTS=`echo ${f} | $AWK -F"_" ' { print strftime("%Y%m%d%H%M.%S",strtonum("0x"$2),1); } '`
			`TZ=UTC $TOUCH -c -t $FTS  "$file"`
	
			# Proces contents here
			debugecho "[$HSAMD] [${f}]", 2
			extract=0
			if [[ ${f} =~ ^zdata_.*_t_vol$ ]]; then
				extract=1
			elif [[ ${f} =~ ^zdata_.*_t$ ]]; then
				extract=2
			else
				extract=0
			fi 
			debugecho "[$extract]", 2
			if [ $extract -ne 0 ]; then
				# get UUID from zdata, use to check if the AMD changes unexpectedly.
				debugecho "Extracting UUID from zdata file: ${f}"
				UUID=`$AWK -F" " '$1=="#AmdUUID:" { print $2 }' "$file"`
				if [ ! -f "$AMDDIR/uuid.lst" ]; then
					echo $UUID > "$AMDDIR/uuid.lst"
				else
					while read k; do
						OLDUUID=${k}
					done < "$AMDDIR/uuid.lst"
					if [ ! "$OLDUUID" == "$UUID" ]; then
						echo -e "\e[33m*** WARNING:\e[39m UUID Mismatch on AMD: $AMDNAME, Old: $OLDUUID, New: $UUID" >&2
						echo -e "\e[33m*** WARNING:\e[39m If this is expected remove file $AMDDIR/uuid.lst to clear the error" >&2
					fi
				fi
			fi
		done
	else
		debugecho "\e[33m*** WARNING:\e[39m Unknown file: ${p} on AMD: $AMDNAME" >&2
	fi
done < <($AWK 'NR==FNR{a[$1]++;next;}!($0 in a)' "$AMDDIR/prevdir.lst" "$AMDDIR/currdir.lst")


# finally, make the current dir list the previous one.
rm "$AMDDIR/prevdir.lst"
mv "$AMDDIR/currdir.lst" "$AMDDIR/prevdir.lst"





# get config
echo -e "Archiving AMD Config: $AMDNAME"
# Get data file listing from AMD, try 3 times, abort (FATAL) if failed
fail=0
tmpfile=`$MKTEMP`
for i in 1 2 3; do
	set +e
	$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmConfigServlet?cfg_oper=get_cfg_dir
	if [ $? -ne 0 ]; then
		echo -e "\e[33m*** WARNING:\e[0m Can not download config directory listing from AMD: $AMDNAME try: ${i}" >&2
		fail=$((fail + 1))
	else
		$CAT $tmpfile > $AMDDIR/confdir.lst
		break
	fi
	set -e
done
rm $tmpfile
if [ $fail -ne 0 ]; then echo -e "\e[31m*** FATAL:\e[0m Could not download config directory listing from AMD: $AMDNAME Aborting." >&2 ; exit 1; fi

# read current file list and download them all.
while read p; do
	# Validate file name is something we want.
	filesplit=(${p// /,})
	p=$filesplit
	if [ "$p"!="0" ]; then
		# Check for correct folder structure - create if needed
		ARCDIR=$AMDDIR/$year/$month/$day/conf
		if [ ! -w "$ARCDIR" ]; then
			debugecho "Creating config archive directory: $ARCDIR"
			mkdir -p "$ARCDIR"
		fi
		file=$ARCDIR/$p
		
		#if [ -r "$file" ]; then continue; fi    # already exists skip downloading
		
		debugecho "Downloading $p from $AMDNAME to $file"
		# Try download 3 times
		warn=0
		tmpfile=`$MKTEMP`
		TS=""
		FTS=""
		for i in 1 2 3 ; do
			set +e
			$WGET --quiet --no-check-certificate -O "$tmpfile" $URL/RtmConfigServlet?cfg_oper=console_get\&cfg_file=$p
			if [ $? -ne 0 ]; then
				warn=$((warn + 1))
				debugecho "\e[33m*** WARNING:\e[39m Can not download config file: $p from AMD: $AMDNAME try: ${i}" >&2
				echo -e "127\n" > $file
				FTS=`TZ=UTC $DATE -u -d @127 +%Y%m%d%H%M.%S`
				`TZ=UTC $TOUCH -c -t $FTS "$file"`
			else
				downloaded=$((downloaded + 1))
				$CAT $tmpfile | $GUNZIP -q -c > $file
				TS=`$CAT $file | $HEAD -n 1`
				TS=$((TS / 1000))
				FTS=`TZ=UTC $DATE -u -d @$TS +%Y%m%d%H%M.%S`
				`TZ=UTC $TOUCH -c -t $FTS  "$file"`
				break
			fi
			set -e
		done
		rm $tmpfile
																		 
		#if [ $warn -ne 0 ]; then echo -e "\e[33m*** WARNING:\e[39m Could not download config file: $p from AMD: $AMDNAME" >&2 ; warnings=$((warnings + 1)); fi
	else
		debugecho "\e[33m*** WARNING:\e[39m Unknown config file: $p on AMD: $AMDNAME" >&2
	fi
done < <($CAT $AMDDIR/confdir.lst)




echo -ne "Archiving AMD: $AMDNAME complete, downloaded $downloaded"
if [ $warnings -ne 0 ]; then echo -e " - \e[33mWarnings: $warnings\e[0m"; fi
echo -e ""

