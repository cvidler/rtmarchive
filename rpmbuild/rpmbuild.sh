#!/usr/bin/env bash
# rpmbuild Script
# Chris Vidler - Dynatrace DCRUM SME 2017
#
# Used to build rpm package for rtmarchive
#


# config
DEBUG=0
NAME=rtmarchive
DIST=el7


# support functions

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`]: $1" 
}

function formatdescribe {
	hash=${1:-}
	res=`git describe`
	ver=${res%%-*}
	ver=${ver#*v}
	release=${res#*-}
	commit=${release#*-}
	release=${release%%-*}
	echo -E "$ver-$release"
}


# main code


# get current git tag/release/commit from describe
TAG=`git describe | tail -n1`
debugecho "TAG: [$TAG]"
# break it up for rpm info
VERSION=${TAG%%-*}
VERSION=${VERSION#*v}
RELEASE=${TAG#*-}
COMMIT=${RELEASE#*-}
RELEASE=${RELEASE%%-*}
debugecho "NAME: [$NAME]  VERSION: [$VERSION]  RELEASE: [$RELEASE]  COMMIT: [$COMMIT]  DIST: [$DIST]"


# build release archive
TMPDIR=`mktemp -d`
debugecho "TMPDIR: [$TMPDIR]"
#BUILDROOT="$TMPDIR/$NAME-$VERSION-$RELEASE"
BUILDROOT="$TMPDIR/$NAME-$VERSION"
debugecho "BUILDROOT: [$BUILDROOT]"

# add directory structure
mkdir -p "$BUILDROOT/etc/httpd/conf.d" "$BUILDROOT/etc/logrotate.d" "$BUILDROOT/opt/$NAME" "$BUILDROOT/opt/$NAME/cron" "$BUILDROOT/opt/$NAME/logrotate" "$BUILDROOT/opt/$NAME/sepol" "$BUILDROOT/var/log/$NAME" "$BUILDROOT/var/spool/$NAME" "$BUILDROOT/var/www/$NAME"
# copy current source files to tmp dir structure
# configs
cp ../rumc.cfg ../amdlist.cfg -t "$BUILDROOT/etc"
cp ../$NAME.logrotate -t "$BUILDROOT/opt/$NAME/logrotate"
cp ../$NAME.crontab -t "$BUILDROOT/opt/$NAME/cron"
# sepol
cp ../*.te ../compilepolicy.sh -t "$BUILDROOT/opt/$NAME/sepol"
# www
cp ../www/0_$NAME.conf -t "$BUILDROOT/etc/httpd/conf.d"
cp ../www/*.php ../www/activedatasets.conf -t "$BUILDROOT/var/www/$NAME"
# scripts
cp ../*.sh -t "$BUILDROOT/opt/$NAME"
rm -f "$BUILDROOT/opt/$NAME/compilepolicy.sh"
cp ../*.xslt -t "$BUILDROOT/opt/$NAME"

# tgz release archive
BUILDPWD="`pwd`"
TARGZ="$BUILDPWD/SOURCES/$NAME-$VERSION-$RELEASE.$DIST.tar.gz"
debugecho "TARGZ: [$TARGZ]"
(
cd $TMPDIR
#tar -czf "$TARGZ" "$NAME-$VERSION-$RELEASE"
tar -czf "$TARGZ" "$NAME-$VERSION"
)
#clean up temp dir
rm -rf "$TMPDIR"

# extract/format changelog from git log
CLOGDETAIL=`git log -n5 --decorate=full --pretty=format:'* %at  %aN <%aE> %n- %h %s '`
debugecho "CLOGDETAIL [$CLOGDETAIL]" 2
# convert raw (unix timestamp) dates into format rpm wants
CLOGDETAIL=`echo -E "$CLOGDETAIL" | awk -F" " '/-/ {print $0}; /*/ {print $1,strftime("%a %b %d %Y",$2),$3,$4,$5};'`
debugecho "CLOGDETAIL [$CLOGDETAIL]" 2

#parse spec file, copy everything, until getting to line "%changelog" replace everything after it with $CLOGDETAIL.
SPECFILE=`awk ' { if($0=="%changelog") exit ; else print $0; }' "SPEC/$NAME-build.spec"`
SPECFILE="${SPECFILE}\n\n\n%changelog\n${CLOGDETAIL}"
debugecho "SPECFILE: [$SPECFILE]" 3
TMPSPEC=`mktemp`
debugecho "TMPSPEC [$TMPSPEC]" 2
echo -e "$SPECFILE" > $TMPSPEC


# call rpmbuild to package tgz and SPEC
rpmbuild -ba --define "_topdir $(pwd)" --define "_tmpdir %topdir/tmp" --define "dist .$DIST" --define "version $VERSION" --define "release $RELEASE"  "$TMPSPEC"
RC=$?
#rpmbuild -ba --define "_topdir $(pwd)" --define "_tmpdir %topdir/tmp" --define "version $VERSION" --define "release $RELEASE"  "$TMPSPEC"

#pause on failure
if [ $RC -ne 0 ]; then echo "rpmbuild failed temp source still present at $TARGZ, SPEC at $TMPSPEC"; read -p "paused, press enter"; fi

#clean up SOURCES
rm -f $TMPSPEC
rm -f $TARGZ


#finished

