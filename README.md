# rtmarchive
Long term archiving system from rtm data files produced by Dynatrace DCRUM

## Requirements:
- httpd >= 2.4
- php >= 5.4
- bash >= 4.2
- tar
- bzip2
- gawk
- wget
- gzip
- coreutils
- cronie
- checkpolicy
- policycoreutils
- policycoreutils-python
- shadow-utils
- glibc-common

Tested against:
- DCRUM 12.3, 12.4
- RHEL 7.2
- CentOS 7.1, 7.2

## Usage

`rtmarchive.sh`
Main script, cron this hourly.
Parses amdlist.cfg, spawns a copy of archiveamd.sh for each. Can be 'multi-threaded' configure number of spawned processes in script (MAXTHREADS variable).
Accepts one parameter, if a singel 1 is passed, debug output is produced.

`archiveamd.sh`
Called from the main script, does the work.
Collects any outstadning data files, and collects the config files. Saves to archive directory.
Not designed to be executed directly.

`archivemgmt.sh`
Executed nightly from cron, processes zdata producing lists of data (client/server IPs, software services, timestamps) for later searching, and archives them for space/integrity.

`archivemgmtindex.sh`
Called nightly from cron, takes produced data lists, and aggregates/indexes them for faster searching.

`amdlist.cfg`
CSV format file listing the AMDs by name, and URL.

`index.php`
Archive system repository viewer. Browse archive repository, and optionally create active AMD instances to serve archived data to a CAS.
Up to 10 AMD instances allowed.  very basic User tracking (determiend by client IP) sees only the instances they've created. Connect from 'localhost' to be 'admin' and see/manage the complete list.

`search.php`
Archive search (for client/server IPs, software services).

`vamd.php`
Virtual AMD code, emulates an AMD so a RUMC and CAS can interrogate the archive system for data files.

`activedatasets.conf`
Stores all active AMD instances 'data set'. Includes originating users client IP, and unique user/password to configure in RUM Console for access. A unique port is specified, but only needed by RUMC because it won't let you add an AMD with an exisitng ip/port combination - even with a unique log on.  And open port is useable.  As configured ports 80 and 9090-9099 are made available. SSL connections not yet available (no reason they couldn't be however). 

`0_rtmarchive.conf`
Apache 2.4 compatible config file, suitable from RHEL7/CentOS7.

## RPM package
Installs amdlist.cfg in /etc/
Installs apache config in /etc/httpd/conf.d/
Installs scripts in /opt/rtmarchive/
Installs web code in /var/www/rtmarchive/
Creates /var/spool/rtmarchive/
Adds rtmarchive user
Adds cron entries for rtmarchive user
Compiles and installs SELinux policies
Opens firewall ports for web components
Enables/starts apache (httpd)


