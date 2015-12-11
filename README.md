# rtmarchive
Long term archiving system from rtm data files produced by Dynatrace DCRUM

## Requirements:
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
- apache >= 2.4

Tested against:
- DCRUM 12.3, 12.4
- RHEL 6.6
- CentOS 7.1

## Usage

`rtmarchvie.sh`
Main script, cron this hourly?

`archiveamd.sh`
Called from the main script, does the work

`archivemgmt.sh`
Called nightly from cron, processed zdata, and archives them for space/integrity

`amdlist.cfg`
CSV format file listing the AMDs by name, and URL.

`www/index.php`
Archive system repository viewer.

`www/vamd.php`
Virtual AMD code, emulates an AMD so a RUMC and CAS can interrogate the archive system for data files.

`www/0_rtmarchive.conf`
Apache 2.4 compatible config file


