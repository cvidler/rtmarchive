# rtmarchive
Long term archiving system from rtm data files produced by Dynatrace DCRUM

Requirements:
- bash
- gawk
- wget
- which
- mktemp
- gunzip
- touch
- cat
- wc
- date
- chmod
- jobs
- sha512sum
- php >= 5.4

Tested against:
- DCRUM 12.3, 12.4
- RHEL 6.6
- CentOS 7.1

# Usage

rtmarchvie.sh
Main script, cron this hourly?

archiveamd.sh
Called from the main script, does the work

archivemgmt.sh
Called nightly from cron, processed zdata, and archives them for space/integrity

amdlist.cfg
CSV format file listing the AMDs by name, and URL.



