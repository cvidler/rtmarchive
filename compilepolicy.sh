#!/usr/bin/env bash
# rtmarchive selinux policy compiler
# Chris Vidler Dynatrace DCRUM SME
#
# script to compile and install selinux policy module for rtmarchvie system operations
#

rm sepolicy.mod sepolicy.pp
checkmodule -M -m -o sepolicy.mod sepolicy.te
semodule_package -o sepolicy.pp -m sepolicy.mod
semodule -i sepolicy.pp
