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


// main command selector
if ( $command == "version" ) {
// D-RTM v. ndw.12.3.0.791 Copyright (C) 1999-2011 Compuware Corp.
// time_stamp=1449719436906
// os=Red Hat Enterprise Linux Server release 6.6 (Santiago)
// instances=true
	echo "V-RTM v. ndw.12.3.0.000 Emulated AMD\n";
	echo "time_stamp=".`date -s +%s`."\n";
	echo "os=".`cat /etc/redhat-release`."";
	echo "instances=true\n";
	exit;

} elseif ( $command == "instance" ) {
	echo "rtm\nnfs\n";
	exit;
} else {
	//invalid/unsupported command
	exit;
}

?>
