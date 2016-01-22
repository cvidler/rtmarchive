#!/bin/bash
# Build RPM from spec - Chris Vidler Dynatrace DCRUM SME
#
# Usage:
# build.sh pathtospecfile


rpmbuild -ba $1

