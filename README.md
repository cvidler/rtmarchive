# rtmarchive
Long term archiving system from rtm data files produced by Dynatrace DCRUM

## Requirements:
- httpd >= 2.4
- php >= 5.4
- bash >= 4.2
- curl
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
- openssl
- xsltproc

Tested against:
- DCRUM 12.3, 12.4, 2017
- RHEL 7.2-4
- CentOS 7.1-4

## Usage

`rtmarchive.sh`
Main script, cron this hourly.
Parses amdlist.cfg, spawns a copy of archiveamd.sh for each. Can be 'multi-threaded' configure number of spawned processes in script (MAXTHREADS variable).
Accepts one parameter, if a single 1 is passed, debug output is produced.

`archiveamd.sh`
Called from the main script, does the work.
Collects any outstanding data files, and collects the config files. Saves to archive directory.
Not designed to be executed directly.

`archivemgmt.sh`
Executed nightly from cron, processes zdata producing lists of data (client/server IPs, software services, timestamps) for later searching, and archives them for space/integrity.
Accepts one parameter, if a single 1 is passed, debug output is produced.

`archivemgmtindex.sh`
Called nightly from cron, takes produced data lists, and aggregates/indexes them for faster searching.
Accepts one parameter, if a single 1 is passed, debug output is produced.

`queryrumc.sh`
Called nightly from cron, takes /etc/rumc.cfg (override with -c) file, and queries each RUM Console instance listed producing a list of AMDs writes to /etc/amdlist.cfg (overide with -a) for use by rtmarchive.sh
Works in two modes, normally:

Accepts the following  parameters, 

-u to update /etc/amdlist.cfg (otherwise a test occurs no changes to amdlist.cfg are made).

-a path change the default location for the amd list config file.

-c path change the default location for the rum console config file. 

-h show syntax help.

Password encoding mode:

accepts mandatory single parameter -e, which then runs interactively to input a password to encode, once encoded the hex value used to add entries to the /etc/rumc.cfg file.

`rumcquery.xslt`
Required by `queryrumc.sh` to pre-process (using xsltproc) the returned data from RUM Console.

`amdlist.cfg`
CSV format file listing the AMDs by name, and URL.

`rumc.cfg`
CSV format file listing the RUM console servers

name,protocol (http/https),address,port (4183 typically),username,encoded password

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
- Installs amdlist.cfg in /etc/
- Installs apache config in /etc/httpd/conf.d/
- Installs scripts in /opt/rtmarchive/
- Installs web code in /var/www/rtmarchive/
- Creates /var/spool/rtmarchive/
- Adds rtmarchive user
- Adds cron entries for rtmarchive user
- Compiles and installs SELinux policies
- Opens firewall ports for web components
- Enables/starts apache (httpd)

### Download RPM Packages
https://github.com/cvidler/rtmarchive/tree/master/rpmbuild/RPMS/x86_64

