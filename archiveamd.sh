# archiveamd script
# Chris Vidler Dynatrace DCRUM SME
#
# called from rtmarchive.sh connects to an AMD determines teh delta of data files and downloads to storage
#
# Parameters:  name url basedir
# name: name to use for AMD, human readable, must be unique or bad stuff will happen
# url: url to use to connect tot he AMD, include logon credentials
# basedir: where to save stuff.

export AMDNAME=$1
export URL=$2
export BASEDIR=$3
export AMDDIR=$BASEDIR/$AMDNAME
export AWK=`which awk`
export WGET=`which wget`
export GUNZIP=`which gunzip`

#echo $AMDNAME, $URL, $BASEDIR

function test {
	"$@"
	local status=$?
	if [ $status -ne 0 ]; then
		echo ***ERROR non-zero exit code $status for "$1" >&2
	fi
	return $status
}


echo Archiving AMD: $AMDNAME beginning

# check if data folder exists, create if needed.
if [ ! -d "$AMDDIR" ]
then
	mkdir "$AMDDIR"
	echo ***NOTE Created AMD data folder $AMDDIR.
fi

# check access to data folder
if [ ! -w "$AMDDIR" ]
then
	echo ***FATAL Cannot write to $AMDDIR Aborting.
	exit 1
fi

# check for existing previous data file list, touch it if needed
if [ ! -r "$AMDDIR/prevdir.lst" ]
then
	touch "$AMDDIR/prevdir.lst"
fi

# check for existing current data file list (there shouldn't be one, remove it
if [ -f "$AMDDIR/currdir.lst" ]
then
	rm "$AMDDIR/currdir.lst"
fi

# Get data file listing from AMD
test $WGET --no-check-certificate -S -O - $URL/RtmDataServlet?cmd=zip_dir | $GUNZIP > $AMDDIR/currdir.lst
if [ $? -ne 0 ]
then
	echo ***FATAL: $? Can not download directory listing from AMD: $AMDNAME
	exit 1
fi

# determine delta of current file list from previous and download them all.
$AWK 'NR==FNR{a[$1]++;next;}!($0 in a)' $AMDDIR/prevdir.lst $AMDDIR/currdir.lst | while read p; do
        echo Downloading ${p} from $AMDNAME
	test $WGET --no-check-certificate -S -O - $URL/RtmDataServlet?cmd=zip_entry\&entry=${p} | $GUNZIP > $AMDDIR/${p}
	if [ $? -ne 0 ]
	then
        	echo ***WARNING: $? Can not download file: ${p} from AMD: $AMDNAME
	fi

	#proces contents here
	#TBA
done



# finally, make the current dir list the previous one.
rm $AMDDIR/prevdir.lst
mv $AMDDIR/currdir.lst $AMDDIR/prevdir.lst

echo Archiving AMD: $AMDNAME complete

