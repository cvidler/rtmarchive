# rtmarchive
Long term archiving system from rtm data files produced by Dynatrace DCRUM

Requirements:
- bash
- gawk
- wget
- which
- gunzip

Tested against:
- DCRUM 12.3
- RHEL 6.6
- CentOS 7.1

# Usage

rtmarchvie.sh
Main script, cron this hourly?

archiveamd.sh
Called from the main script, does the work

amdlist.cfg
CSV format file listing the AMDs by name, and URL.



