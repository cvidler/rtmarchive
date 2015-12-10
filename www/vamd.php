<?php
// psuedo AMD process to feed archived data to a CAS
// Chris Vidler Dynatrace DCRUM SME
//
// Must handle a subset of the rtmgate command set in order to be able to respond to data queries
//
// cmd=instance
// repond with available data sets, e.g. rtm and/or nfc
//
// cmd=version
// respond with version info
//
// cmd=get_dir
// respond with available data files to download
//
// cmd=get_entry
// respond with a data file as download


// Config
define("BASEDIR", "/var/spool/rtmarchive/");	//location of data archive
define("USER", "rtmarchive");			//auth for RUMC/CAS to use
define("PASS", "history");			// "



// Code follows do not edit
header_remove();

if ( is_dir(BASEDIR) ) {} else {
	echo "***FATAL: ".BASEDIR." does not exist.\n";
}

if ( isset( $_GET['cmd']) ) { $command = $_GET['cmd']; }
if ( isset( $_GET['cfg_oper']) ) { $command = $_GET['cfg_oper']; }

if ( $command == "" ) { exit;}		// unknown command



// locate utils we need
$TAR = `which tar`;
$CAT = `which cat`;
$DATE = `which date`;


//authentication
$valid_passwords = array (USER => PASS);
$valid_users = array_keys($valid_passwords);

$user = "";
$pass = "";
if ( isset($_SERVER['PHP_AUTH_USER']) ) { $user = $_SERVER['PHP_AUTH_USER']; }
if ( isset($_SERVER['PHP_AUTH_PW']) ) { $pass = $_SERVER['PHP_AUTH_PW']; }

$validated = (in_array($user, $valid_users)) && ($pass == $valid_passwords[$user]);

if (!$validated) {
  header('WWW-Authenticate: Basic realm="rtmarchive"');
  header('HTTP/1.0 401 Unauthorized');
  die ("Not authorized");
}



// Read config file created by web interface
// determine which AMD and archived day to report data from.

// tbd
$amd = "amde1";
$year = "2015";
$month = "12";
$day = "08";

// create vars we need
$datadate = $year."-".$month."-".$day;
$archive = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$datadate.".tar.bz2";

//check validity
if ( ! file_exists($archive) ) { echo "***FATAL Archive: $archive does not exist. Aborting."; exit; }

header("Cache-Control: private");
header("Content-Type:");
header("Server: Apache-Coyote/1.1");
header("Expires: 1 Jan 1970 00:00:00 GMT");


// main command selector

// RtmDataServlet (the one we really want)
if ( $command == "version" ) {
// D-RTM v. ndw.12.3.0.791 Copyright (C) 1999-2011 Compuware Corp.
// time_stamp=1449719436906
// os=Red Hat Enterprise Linux Server release 6.6 (Santiago)
// instances=true
	echo "ND-RTM v. ndw.12.3.0.000 rtmarchive Emulated AMD\n";
	echo "time_stamp=".str_replace(array("\r","\n"), "", `/usr/bin/date -u +%s%3N`)."\n";
	echo "os=".str_replace(array("\r","\n"), "", `/usr/bin/cat /etc/redhat-release`)."\n";
	echo "instances=true\n";
	exit;

} elseif ( $command == "instance" ) {
	echo "rtm\nnfc\n";
	exit;

} elseif (( $command == "get_dir" ) || ( $command == "zip_dir" ))  {
	$data = `/usr/bin/tar -tf "$archive" | /usr/bin/awk -F" " ' match($0,"(.+/)+(.+)$",a) { print a[2] } '`;
	if ( $command == "zip_dir" ) { $data = gzencode($data); }
	echo $data;
	exit;

} elseif (( $command == "get_entry" ) || ( $command == "zip_entry" ))  {
	$entry = $_GET["entry"];
	if ( $entry == "" ) { exit; }
	$data = `/usr/bin/tar -Oxf "$archive" "*/$entry"`;
	if ( $command == "zip_entry" ) { $data = gzencode($data); }
        echo $data;
	exit;


//RtmConfigServlet - don't really care, just respond to stop RUMC complaining.
} elseif ( $command == "get_cfg_dir" ) {
	echo "daves_not_here_man\n";
	exit;

} elseif ( $command == "console_get" ) {
	echo "\n";
	exit;


//DiagServlet - don't really care, just respond to stop RUMC complaining.
} elseif ( $command == "get_status" ) {
	echo "{\"modules\": {\n";
	echo "\t\"module\": [\n";
	echo "\t\t{\"name\": \"adlexv2page\", \"version\": \"12.4.0-18.el7\", \"statusBegin\": \"0\", \"statusEnd\": \"0\", \"installed\": \"3296181\", \"uptime\": \"168\"},\n";
	echo "\t\t{\"name\": \"nfc\", \"version\": \"12.4.0-992.el7\", \"statusBegin\": \"4\", \"statusEnd\": \"7\", \"installed\": \"3296182\", \"uptime\": \"-1\"},\n";
	echo "\t\t{\"name\": \"rtm\", \"version\": \"12.4.0-887.el7\", \"statusBegin\": \"4\", \"statusEnd\": \"7\", \"installed\": \"3296180\", \"uptime\": \"-1\"},\n";
	echo "\t\t{\"name\": \"adlexpage2trans\", \"version\": \"12.4.0-24.el7\", \"statusBegin\": \"0\", \"statusEnd\": \"0\", \"installed\": \"3296181\", \"uptime\": \"168\"},\n";
	echo "\t\t{\"name\": \"rtmgate\", \"version\": \"12.4.0-54.el7\", \"statusBegin\": \"0\", \"statusEnd\": \"0\", \"installed\": \"3296198\", \"uptime\": \"162\"},\n";
	echo "\t\t{\"name\": \"cba\", \"version\": \"12.4.0-992.el7\", \"statusBegin\": \"4\", \"statusEnd\": \"7\", \"installed\": \"3296183\", \"uptime\": \"-1\"},\n";
	echo "\t\t{\"name\": \"cba-agent\", \"version\": \"12.4.0-6.el7\", \"statusBegin\": \"4\", \"statusEnd\": \"7\", \"installed\": \"3296178\", \"uptime\": \"-1\"},\n";
	echo "\t\t{\"name\": \"adlexrtm\", \"version\": \"ndw.12.4.0.992-1.el7\", \"statusBegin\": \"0\", \"statusEnd\": \"6\", \"installed\": \"3296192\", \"uptime\": \"168\"}\n";
	echo "\t]\n";
	echo "}}\n";
	exit;


//hid - ???
} elseif ( $command == "hid" ) {
	echo "5d2d6916f8713b91\n";
	exit;


// catchall
} else {
	//invalid/unsupported command
	exit;
}

?>
