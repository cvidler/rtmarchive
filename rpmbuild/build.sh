#!/bin/bash
# Build RPM from spec - Chris Vidler Dynatrace DCRUM SME
#
# Usage:
# build.sh pathtospecfile

rpmbuild -ba --define "_topdir $(pwd)" --define "_tmpdir %topdir/tmp" --define "dist .el7" $1

