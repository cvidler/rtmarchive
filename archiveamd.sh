#!/usr/bin/env bash
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
GETCONF=1						#grab config files too
FORCEDL=0						#always download everything (SLOW!)
DISPCOUNT=250					#print progress bar every x files processed
DISPCOLS=${COLUMNS:-132}		#default character screen width, read from environment, default to 132



# --- Script below do not edit ---
set -euo pipefail
IFS=$' ,\n\t'

AWK=`which awk`
WGET=`which wget`
GUNZIP=`which gunzip`
TOUCH=`which touch`
MKTEMP="`which mktemp` -t rtmarchive.XXXXXXXX"
MKTEMPD="`which mktemp` -d -t rtmarchive.XXXXXXXX"
CAT=`which cat`
TAIL=`which tail`
HEAD=`which head`
DATE=`which date`
TR=`which tr`
SORT=`which sort`
set +e
BC=`which bc`
if [ $? -ne 0 ]; then BC=""; fi  #bc is optional, don't display percentages/progress bar if absent
set -e


#DISPCOLS used to draw progress bars, resize to acount for screenwidth and extras
DISPCOLS=$((DISPCOLS - 2 - 5))  #make room for end tags and percentage display

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
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`][$AMDNAME]: $1" 
}


# command line arguments
AMDNAME=0
BASEDIR=0
URL=0
NSET=0
BSET=0
USET=0
OPTS=1
while getopts ":dfhn:b:u:" OPT; do
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
		f)
			FORCEDL=1
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
			techo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			techo "*** FATAL: argument -$OPTARG requires parameter."
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

debugecho "Passed Parameters: AMDNAME: [$AMDNAME], URL: [$URL], BASEDIR: [$BASEDIR], DEBUG: [$DEBUG]" 2
debugecho "Constructed Parameters: AMDDIR [$AMDDIR]" 2

if [ -z "$AMDNAME" ]; then
	techo "\e[31m***FATAL:\e[0m AMDNAME parameter not supplied. Aborting." >&2
	exit 1
fi

if [ -z "$URL" ]; then
	techo "\e[31m***FATAL:\e[0m URL parameter not supplied. Aborting." >&2
	exit 1
fi

techo "AMD Archiving script"
techo "Chris Vidler - Dynatrace DCRUM SME, 2016"
techo "Archiving AMD: $AMDNAME beginning"
tstart=`date -u +%s`

# check if data folder exists, create if needed.
if [ ! -d "$AMDDIR" ]; then
	mkdir "$AMDDIR"
	debugecho "Created AMD data folder $AMDDIR."
fi

# check access to data folder
if [ ! -w "$AMDDIR" ]; then
	techo -e "\e[31m***FATAL:\e[0m Cannot write to $AMDDIR. Aborting." >&2
	exit 1
fi

# check for existing previous data file list, touch it if needed, so we can download everything.
if [ ! -r "$AMDDIR/prevdir.lst" ]; then
	touch "$AMDDIR/prevdir.lst"
	echo "newfile" > "$AMDDIR/prevdir.lst"
fi

# check for existing current data file list (there shouldn't be one if the script finished last time, remove it)
if [ -f "$AMDDIR/currdir.lst" ]; then
	debugecho "Found stale currdir.lst. Removing it."
	rm -f "$AMDDIR/currdir.lst"
fi


#get data file listing and version info from AMD
tmpfile=`$MKTEMP`
tmpfile2=`$MKTEMP`
tmpfile3=`$MKTEMP`
set +e
EC=`curl --insecure --silent --retry 3 --basic -o $tmpfile $URL/RtmDataServlet?cmd=zip_dir -o $tmpfile2 $URL/RtmDataServlet?cmd=version -o $tmpfile3 $URL/RtmConfigServlet?cfg_oper=get_cfg_dir`
RC=$?
set -e
debugecho "curl result RC: [$RC], EC: [$EC]" 2
if [ $RC -ne 0 ]; then techo "\e[31m***FATAL:\e[0m Could not download directory listing from AMD: [$AMDNAME] using URL: [$URL] Aborting." >&2 ; exit 1; fi


#unzip, filter, and sort (by timestamp) all the interval data files
$GUNZIP -q -c "$tmpfile" | grep -oE '[a-z0-9]+_[0-9a-f]+_[150a]+_[tb].*' | $SORT -t "_" -k 2d,3 -k 1d,2 > "$AMDDIR/currdir.lst"
RC=$?
if [ $RC -ne 0 ]; then techo "\e[31m***FATAL:\e[0m Could not process directory listing from AMD: [$AMDNAME] using data: [$tmpfile] Aborting." >&2 ; exit 1; fi
rm -f "$tmpfile"


#determine if AMD is HS AMD or classic AMD
HSAMD=0
HSAMD=`$AWK '/ng\.probe=true/ { print "1" }' "$tmpfile2"`
rm -f "$tmpfile2"
debugecho "HSAMD: [$HSAMD]" 2


#get config file listing
cp -f "$tmpfile3" "$AMDDIR/confdir.lst"
rm -f "$tmpfile3"




# determine delta of current file list from previous and download the difference.
if [ $FORCEDL -eq 1 ]; then techo "FORCED DOWNLOAD FLAG SET"; echo "newfile" > "$AMDDIR/prevdir.lst"; fi
difflist=`$AWK 'NR==FNR{a[$1]++;next;}!($0 in a)' "$AMDDIR/prevdir.lst" "$AMDDIR/currdir.lst"`
diffcount=`echo -e "$difflist" | wc -l`
debugecho "filecount: [$diffcount]" 2
debugecho "filelist: [$difflist]" 4

tslist=`echo -e "$difflist" | grep -oE '[a-f0-9]{8}' | sort -u`
tscount=`echo -e "$tslist" | wc -l`
debugecho "tscount: [$tscount]" 2
debugecho "tslist: [$tslist]" 4


#set up some vars
BARL=0
BARR=0
PERC=0
downloaded=0
warnings=0
warnlist=""
tcount=0
count=0


#loop through timestamps
while read -r ts; do
	#per timestamp
	tcount=$((tcount+1))


	#progress display
	if [ ! "$BC" == "" ]; then		
		# figure out percentages of progress
		PERC=0$($BC -l <<<  "(($count/$diffcount) * 100); " ); PERC=${PERC%.*}; PERC=${PERC#0}; if [ "$PERC" == "" ]; then PERC=0; fi
		PERC2=0$($BC -l <<<  "(($tcount/$tscount) * 100); " ); PERC2=${PERC2%.*}; PERC2=${PERC2#0}; if [ "$PERC2" == "" ]; then PERC2=0; fi
		# figure out progress bar length
		BARL=0$($BC -l <<<  "(((($count/$diffcount) * $DISPCOLS)) / $DISPCOLS) * $DISPCOLS; "); BARL=${BARL%.*}; BARL=${BARL#0}; if [ "$BARL" == "" ]; then BARL=0; fi
		# figure out progress bar blank length
		BARR=$((DISPCOLS - BARL)); if [[ $BARR -lt 1 ]]; then BARR=0; fi
		techo "Processed files: $count/$diffcount $PERC%" 
		techo "Processed intervals: $tcount/$tscount $PERC2%" 
		techo "[`$HEAD -c $BARL < /dev/zero | $TR '\0' '#' ``$HEAD -c $BARR < /dev/zero | $TR '\0' ' '`] $PERC%"
	else
		techo "Processed files: $count/$diffcount" 
		techo "Processed intervals: $tcount/$tscount" 
	fi
	debugecho "count: [$count], diffcount: [$diffcount], PERC: [$PERC], BARL: [$BARL], BARR: [$BARR], COLUMNS: [$DISPCOLS], tcount [$tcount], tscount: [$tscount], PERC2: [$PERC2]" 2


	#figure out date to create directory
	year=`TZ=UTC; printf "%(%Y)T" 0x$ts`
	month=`TZ=UTC; printf "%(%m)T" 0x$ts`
	day=`TZ=UTC; printf "%(%d)T" 0x$ts`

	# Check for correct directory structure - create if needed
	ARCDIR="$AMDDIR/$year/$month/$day/"
	debugecho "ARCDIR: [$ARCDIR]" 2
	if [ ! -d "$ARCDIR" ]; then
		debugecho "Creating archive directory: $ARCDIR"
		mkdir -p "$ARCDIR"
	fi
	if [ ! -w "$ARCDIR" ]; then
		techo "\e[31m***FATAL:\e[0m Can't write to archive directory: [$ARCDIR]"
		exit 1
	fi


	#build download list
	dllist=""
	tmpdir=`$MKTEMPD`
	debugecho "tmpdir: [$tmpdir]" 3
	filelist=`echo -e "$difflist" | grep -E "_${ts}_"`
	while read -r p; do	

		if [ -r "$ARCDIR/$p" ] && [ ! $FORCEDL -eq 1 ]; then		#if file already exists and forced download flag unset, skip downloading it. 
			count=$((count+1))
			debugecho "Skipping exiting file ${p}" 2
			continue	# already exists skip downloading
		fi

		tmpfile="$tmpdir/$p"
		#debugecho "tmpfile: [$tmpfile]" 3
		dllist="$dllist -o $tmpfile ${URL}RtmDataServlet?cmd=zip_entry&entry=${p} "
		
	done < <(echo -e "$filelist")		#files per timestamp
	if [ "$dllist" == "" ]; then rm -rf "$tmpdir"; continue; fi		#skip altogether if we've got nothing to download
	debugecho "dllist: [$dllist]" 4


	#download
	set +e
	EC=`curl --insecure --silent --retry 3 --basic ${dllist}`
	RC=$?
	set -e
	debugecho "curl result RC: [$RC], EC: [$EC]" 2
	#error handling TBD


	#process
	while read -r p; do
		file="$ARCDIR/${p}"
		count=$((count+1))

		if [ ! -f "$tmpdir/$p" ]; then
			debugecho "***WARNING: File: [$p] not downloaded from AMD [$AMDNAME]"
			warnings=$((warnings+1))
			warnlist="$warnlist\n$p"
			continue
		fi
		
		if [ -f "$file" ] && [ ! -w "$file" ]; then chmod +w "$file"; fi		#file read-only fix that
		set +e
		$GUNZIP -q -c "$tmpdir/$p" > "$file"		#unzip it
		RC=$?
		set -e
		if [ $RC -ne 0 ]; then debugecho "***WARNING File: [$tmpdir/$p] didn't decompress."; warnings=$((warnings+1)); warnlist="$warnlist\n$p"; continue; fi 
		downloaded=$((downloaded + 1))

		#set correct timestamp on file
		set +e
		FTS=`echo "${p}" | $AWK -F"_" ' { print strftime("%Y%m%d%H%M.%S",strtonum("0x"$2),1); } '`
		`TZ=UTC $TOUCH -c -t $FTS  "$file"`
		set -e

		# Extract AMD UUID
		if [[ ${p} =~ ^zdata_.*_t_vol$ ]] || [[ ${p} =~ ^zdata_.*_t$ ]] ; then		#found in zdata files
			if [ -r "$file" ]; then
				# get UUID from zdata, use to check if the AMD changes unexpectedly.
				debugecho "Extracting UUID from zdata file: ${p}"
				UUID=`$AWK -F" " '$1=="#AmdUUID:" { print $2 }' "$file"`
				if [ ! -f "$AMDDIR/uuid.lst" ]; then
					echo "$UUID" > "$AMDDIR/uuid.lst"
				else
					while read k; do
						OLDUUID=${k}
					done < "$AMDDIR/uuid.lst"
					if [ ! "$OLDUUID" == "$UUID" ]; then
						techo "\e[33m*** WARNING:\e[39m UUID Mismatch on AMD: $AMDNAME, Old: $OLDUUID, New: $UUID" >&2
						techo "\e[33m*** WARNING:\e[39m If this is expected remove file $AMDDIR/uuid.lst to clear the error" >&2
					fi
				fi
			fi
		fi 

	done < <(echo -e "$filelist")		#files per timestamp


	#clean up tmpdir
	rm -rf "$tmpdir"
done < <(echo -e "$tslist")		#timestamp list
techo "Completed downloading interval data for [$AMDNAME]"


# finally, make the current dir list the previous one.
rm -f "$AMDDIR/prevdir.lst"
mv "$AMDDIR/currdir.lst" "$AMDDIR/prevdir.lst"


# get AMD config
if [ $GETCONF ]; then
	techo "Archiving AMD Config: $AMDNAME"

	ARCDIR="$ARCDIR/conf"
	if [ ! -d "$ARCDIR" ]; then
		debugecho "Creating config archive directory: $ARCDIR"
		mkdir -p "$ARCDIR"
	fi	
	if [ ! -w "$ARCDIR" ]; then
		debugecho "Setting permissions on config archive directory: $ARCDIR"
		chmod 664 "$ARCDIR"
	fi

	#build download command
	dllist=""
	tmpdir=`$MKTEMPD`
	while read -r p q; do

		if [ "$p" == "0" ]; then continue; fi		#amd sends a '0' as first line of config list. ignore it

		tmpfile="$tmpdir/$p"
		dllist="$dllist -o $tmpfile ${URL}RtmConfigServlet?cfg_oper=console_get&cfg_file=$p"

	done < <($CAT "$AMDDIR/confdir.lst")  
	debugecho "dllist: [$dllist]" 4

	#download
	set +e
	EC=`curl --insecure --silent --retry 3 --basic ${dllist}`
	RC=$?
	set -e
	debugecho "curl result RC: [$RC], EC: [$EC]" 2
	#error handling TBD

	#process config files
	ccount=0
	while read -r p q; do

		if [ "$p" == "0" ]; then continue; fi		#amd sends a '0' as first line of config list. ignore it

		ccount=$((ccount+1))
		debugecho "Downloading config file [$p]" 2
		#prep vars
		tmpfile="$tmpdir/$p"
		file="$ARCDIR/$p"

		#file checks
		if [ ! -f "$tmpfile" ]; then
			#debugecho "Couldn't download config file [$p] from AMD [$AMDNAME]" 2
			#warnings=$((warnings+1))
			#warnlist="$warnlist\n$p"
			continue
		fi
		if [ -f "$file" ] && [ ! -w "$file" ]; then
			chmod 664 "$file"
		fi

		#unzip file
		set +e
		$GUNZIP -q -c "$tmpfile" > "$file"
		RC=$?
		set -e
		if [ $RC -ne 0 ]; then 
			#debugecho "Couldn't decompress config file [$tmpfile] from AMD [$AMDNAME]" 2
			#warnings=$((warnings+1))
			#warnlist="$warnlist\n$p"
			continue
		fi

		#get timestamp from first line of file
		TS=`$HEAD -n 1 "$file"`
		TS=$((TS / 1000))
		FTS=`TZ=UTC $DATE -u -d @$TS +%Y%m%d%H%M.%S`

		#set file timestamp to match
		`TZ=UTC $TOUCH -c -t $FTS "$file"`
	done < <($CAT "$AMDDIR/confdir.lst")  


	#clean up tempdir
	rm -rf "$tmpdir"

	techo "Completed downloading config data for [$AMDNAME]"

fi


#output results
tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "Archiving AMD: $AMDNAME complete, downloaded $downloaded files in $tcount intervals"
if [ $ccount -gt 0 ]; then techo "Downloaded $ccount config files"; fi
if [ $warnings -ne 0 ]; then techo "\e[33mWarnings: $warnings\e[0m"; debugecho "Files with warnings: $warnlist"; fi
techo "Completed in $tdur seconds"

