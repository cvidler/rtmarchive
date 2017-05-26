#!/usr/bin/env bash
# rtmarchive selinux policy compiler
# Chris Vidler Dynatrace DCRUM SME
#
# script to compile and install selinux policy module for rtmarchvie system operations
#

rm rtmarchivepol.mod rtmarchivepol.pp
checkmodule -M -m -o rtmarchivepol.mod rtmarchivepol.te
semodule_package -o rtmarchivepol.pp -m rtmarchivepol.mod
semodule -i rtmarchivepol.pp
