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

if ( is_dir(BASEDIR) ) {} else {
	echo "***FATAL: ".BASEDIR." does not exist.\n";
}

if (count($_GET)) {
	$command = $_GET["cmd"];
	//$instance = $_GET["instance"];
	//$entry = $_GET["entry"];
} else {
	exit;
}


// locate utils we need
$TAR = `which tar`;
$CAT = `which cat`;
$DATE = `which date`;


//authentication
$valid_passwords = array (USER => PASS);
$valid_users = array_keys($valid_passwords);

$user = $_SERVER['PHP_AUTH_USER'];
$pass = $_SERVER['PHP_AUTH_PW'];

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


// main command selector
if ( $command == "version" ) {
// D-RTM v. ndw.12.3.0.791 Copyright (C) 1999-2011 Compuware Corp.
// time_stamp=1449719436906
// os=Red Hat Enterprise Linux Server release 6.6 (Santiago)
// instances=true
	echo "D-RTM v. ndw.12.3.0.000 rtmarchive Emulated AMD\n";
	echo "time_stamp=".`/usr/bin/date -u +%s%3N`."";
	echo "os=".`/usr/bin/cat /etc/redhat-release`."";
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

} else {
	//invalid/unsupported command
	exit;
}

?>
