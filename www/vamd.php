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
define("CHUNK_SIZE", 5*1024*1024); // Size (in bytes) of files chunk
define("BASEDIR", "/var/spool/rtmarchive/");	//location of data archive
//define("USER", "rtmarchive");			//auth for RUMC/CAS to use
//define("PASS", "history");			// "


$eservices = 1;


// Code follows do not edit
function searchForFile($fileToSearchFor){
	$numberOfFiles = count(glob($fileToSearchFor));
	if($numberOfFiles == 0){ return(FALSE); } else { return(TRUE);}
}


// Read a file and display its content chunk by chunk
function readfile_chunked($filename, $retbytes = TRUE) {
	$buffer = "";
	$cnt =0;
	// $handle = fopen($filename, "rb");
	$handle = fopen($filename, "rb");
	if ($handle === false) {
		return false;
	}
	while (!feof($handle)) {
		set_time_limit(30);
		$buffer = fread($handle, CHUNK_SIZE);
		echo $buffer;
		ob_flush();
		flush();
		if ($retbytes) {
			$cnt += strlen($buffer);
		}
	}
	$status = fclose($handle);
	if ($retbytes && $status) {
		return $cnt; // return num. bytes delivered like readfile() does.
	}
	return $status;
}


header_remove();

if ( is_dir(BASEDIR) ) {} else {
	echo "***FATAL: ".BASEDIR." does not exist. Aborting.\n";
	http_response_code(500);
	exit;
}

// Load config file
// id,username,password,datasets
// datasets = amd-year-month-day| repeat
$valid_passwords[rand()] = rand();		//set a random logon incase we have no config
if ( file_exists("activedatasets.conf") ) {
	$file = fopen("activedatasets.conf","r");
        while (($buffer = fgets($file)) !== false ) {
		$buffer = trim($buffer);
		if ( ($buffer !== "" ) and (substr($buffer, 0, 1) !== "#") ) { 
	                $data = explode(",", $buffer);
			// load authentication details
			//echo $data[2].",".$data[3];
			$valid_passwords[$data[2]] = $data[3];
			$datasets[$data[2]] = $data[5];
			$hids[$data[2]] = $data[0];
		}
	}
        fclose($file);
	
} else {
	echo "***FATAL: Archive AMD config file not found or not readable. Aborting.\n";
	http_response_code(500);
	exit;
}

// figure out what we're meant to do...
$command = "";
if ( isset( $_GET['cmd']) ) { $command = strtolower($_GET['cmd']); }
if ( isset( $_GET['cfg_oper']) ) { $command = $_GET['cfg_oper']; }
if ( isset( $_GET['product']) ) { $suffix = $_GET['product']; }
if ( isset( $_SERVER['QUERY_STRING']) ) { if ( $_SERVER['QUERY_STRING'] === 'hid' ) { $command = "hid"; } }
if ( isset( $_SERVER['QUERY_STRING']) ) { if ( $_SERVER['QUERY_STRING'] === 'v2' ) { $command = "v2"; } }

if ( $command == "" ) { echo "***FATAL: No command. Aborting."; http_response_code(400); exit; }		// unknown command




//authentication
//$valid_passwords = array (USER => PASS);  //loaded from config file above
$valid_users = array_keys($valid_passwords);

$user = "";
$pass = "";
if ( isset($_SERVER['PHP_AUTH_USER']) ) { $user = $_SERVER['PHP_AUTH_USER']; }
if ( isset($_SERVER['PHP_AUTH_PW']) ) { $pass = $_SERVER['PHP_AUTH_PW']; }

$validated = (in_array($user, $valid_users)) && ($pass === $valid_passwords[$user]);

if (!$validated) {
  header('WWW-Authenticate: Basic realm="rtmarchive"');
  header('HTTP/1.0 401 Unauthorized');
  die ("Not authorized");
}


if (!isset($datasets[$user])) { echo "***FATAL no config. Aborting."; http_response_code(500); exit;}


// determine which AMD and archived day to report data from.
//$datasets = explode("|", $datasets[$user]);
//sort($datasets);
//$datacount = count($datasets);
//$x = 0; $noarchive = 0;
//for ($i = 0; $i < $datacount; $i++) {
//	if ( $datasets[$i] == "" ) { continue; }
//	$data = explode("-",$datasets[$i]);
//	$amd = @$data[0];
//	$year = @$data[1];
//	$month = @$data[2];
//	$day = @$data[3];
//
//	// create vars we need
//	$datadate = $year."-".$month."-".$day;
//	$archive = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$datadate.".tar.bz2";
//	if ( ! file_exists($archive) ) { $noarchive = 1; echo "***FATAL Archive: $archive does not exist. Aborting."; http_response_code(404); exit;} else {
//		$archives[$x++] = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$datadate.".tar.bz2";
//	}
//}
//$datacount = count($archives);

// build temp dir variable, use the unique ID
$tempdir = BASEDIR.".temp/".$hids[$user]."/";
$confdir = $tempdir."conf/";
$noarchive = 0;
if ( ! file_exists($tempdir) ) { $noarchive = 1; }


//determine (from available file types) if data is HS AMD data or Classic AMD data
$ngprobe = 0;
if ( ! searchForFile($tempdir."/zdata_*_vol") ) { $ngprobe = 0; } else { $ngprobe = 1; }

//check validity
//if ( ! file_exists($archive) ) { $noarchive = 1; }

header("Cache-Control: private");
header("Content-Type:");
header("Server: Apache-Coyote/1.1");
header("Expires: 1 Jan 1970 00:00:00 GMT");


// main command selector

// RtmDataServlet (the one we really want)
if ( $command === "version" ) {
// ND-RTM v. ndw.12.3.0.791 Copyright (C) 1999-2011 Compuware Corp.
// time_stamp=1449719436906
// os=Red Hat Enterprise Linux Server release 6.6 (Santiago)
// instances=true
	$release = file_get_contents("/etc/redhat-release");
	echo "ND-RTM v. ndw.12.4.0.000 rtmarchive Emulated AMD\n";
	echo "time_stamp=".round(microtime(true) * 1000)."\n";
	echo "os=".str_replace(array("\r","\n"), "", $release)."\n";
	echo "instances=true\n";
	if ( $ngprobe ) { 
		echo "ng.probe=true\n";
	}
	if ( $eservices ) {
		echo "licensing=v2\n";
	}
	exit;

} elseif ( $command === "instance" ) {
	#echo "rtm\nnfc\n";
	echo "rtm\n";
	exit;

} elseif (( $command === "get_dir" ) || ( $command === "zip_dir" ))  {
	//if ( $noarchive ) { echo "***FATAL Archive: $archive does not exist. Aborting."; http_response_code(404); exit; }
	//$data = ""; $i = 0;
	//for ( $i = 0; $i < $datacount; $i++ ) {
	//	$data = $data.`/usr/bin/tar -tf "$archives[$i]" | /usr/bin/awk -F" " ' match($0,"(.+/)+(.+)$",a) { print a[2] } '`;
	//}
	$data = "";
	//$data = `ls -1 $tempdir`;.
	if ( !file_exists($tempdir) ) { echo "***FATAL: Directory $tempdir not found. Aborting."; http_response_code(500); exit; }

	//$data = implode("\n", array_diff(scandir($tempdir),array(".","..","conf")));

	$data = glob($tempdir."/*_*_*");
	$data = array_map('basename', $data);
	$data = preg_replace("/([a-z0-9A-Z-% _]+_[0-9a-f]{8}_[a-f0-9]+_[tb])([_a-z]*)/","$1",$data);
	rsort($data);
	$data = array_unique($data);
	$data = implode("\n", $data);

	if ( $command === "zip_dir" ) { $data = gzencode($data); header('Content-Encoding: gzip'); }
	echo $data;
	exit;

} elseif (( $command === "get_entry" ) || ( $command === "zip_entry" ))  {
	//if ( $noarchive ) { echo "***FATAL Archive: $archive does not exist. Aborting."; http_response_code(404); exit; }
	$entry = urldecode($_GET["entry"]);
	//sanitise filename
	$entry = preg_replace("/[^a-z0-9_]/", "", $entry);
	if ( $entry === "" ) { echo "***FATAL Invalid entry parameter. Aborting."; http_response_code(400); exit; }

	$filenames = $tempdir.$entry."*";
	$filelist = glob($filenames);
	if ( ! count($filelist) ) { echo "***FATAL: Requested Files: ".$filenames." not found. Aborting."; http_response_code(404); exit; }

	if ( $command === "zip_entry" ) { header('Content-Encoding: gzip'); ob_start("ob_gzhandler"); }
	
	$data = "";
	$filelistlen = count($filelist);

	for ( $filenum = 0; $filenum < $filelistlen; $filenum++ ) {
		readfile_chunked($filelist[$filenum]);
	}

	//echo $data;
	flush();
	exit;


//RtmConfigServlet - don't really care, just respond (safely) to stop RUMC complaining.
} elseif ( $command === "exportconfig" ) {
	echo "ExportConfig Request discarded. Another export operation already in progress!";
	http_response_code(503);
	exit;

} elseif ( $command === "get_cfg_dir" ) {
	echo "0\n";
	if ( !file_exists($confdir) ) { http_response_code(500); exit; }
	$conffiles = array_diff(scandir($confdir),array(".","..","conf"));
	foreach ($conffiles as $conffile) {
		if ( $conffile == "0" ) { continue; }
		//$ts = date("U", filemtime($confdir.$conffile));
		$ts = filemtime($confdir.$conffile);
		echo $conffile." ".$ts."\n";
	}
	exit;

} elseif ( $command === "console_get" ) {
	$entry = urldecode($_GET["cfg_file"]);
	$filename = $confdir.$entry;
	if ( !file_exists($filename) ) { echo "***FATAL: Config file $entry not found. Aborting."; http_response_code(404); exit; }
	$data = "";
	$file = fopen($filename, "r");
	if ( !$file ) { echo "***FATAL: Config file not readable: $filename. Aborting."; http_response_code(404); exit;}
	$data = fread($file, filesize($filename));  
	$data = gzencode($data);
	header('Content-Encoding: gzip');
	echo $data;
	exit;


//DiagServlet - don't really care, just respond to stop RUMC complaining.
} elseif ( $command === "get_status" ) {
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


//hid - return a unique id
} elseif ( $command === "hid" ) {
	echo $hids[$user]."\n";
	exit;


//v2 - respond with v2 license strings
} elseif ( $command === "v2" ) {
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><licenses><license>";
	echo "<feature><key>A-KERBEROS</key><value>true</value></feature>";
	echo "<feature><key>A-SOAP-HTTP</key><value>true</value></feature>";
	echo "<feature><key>A-NETFLOW</key><value>true</value></feature>";
	echo "<feature><key>A-PARSER</key><value>true</value></feature>";
	echo "<feature><key>A-LTHTTP</key><value>true</value></feature>";
	echo "<feature><key>A-RMI</key><value>true</value></feature>";
	echo "<feature><key>A-CORBA</key><value>true</value></feature>";
	echo "<feature><key>A-IBMMQ</key><value>true</value></feature>";
	echo "<feature><key>A-RPC</key><value>true</value></feature>";
	echo "<feature><key>A-DRDA</key><value>true</value></feature>";
	echo "<feature><key>A-HTTP</key><value>true</value></feature>";
	echo "<feature><key>A-MYSQL</key><value>true</value></feature>";
	echo "<feature><key>A-DNS</key><value>true</value></feature>";
	echo "<feature><key>A-INFORMIX</key><value>true</value></feature>";
	echo "<feature><key>A-SAPRFC</key><value>true</value></feature>";
	echo "<feature><key>A-JOLT</key><value>true</value></feature>";
	echo "<feature><key>A-ORACLE</key><value>true</value></feature>";
	echo "<feature><key>A-VOIP</key><value>true</value></feature>";
	echo "<feature><key>A-AMD-SIZE</key><value>20000</value></feature>";
	echo "<feature><key>A-OF-HTTP</key><value>true</value></feature>";
	echo "<feature><key>A-SAPGUI</key><value>5000</value></feature>";
	echo "<feature><key>A-SMTP</key><value>true</value></feature>";
	echo "<feature><key>A-GENERIC-TRANS</key><value>true</value></feature>";
	echo "<feature><key>A-DSSL</key><value>true</value></feature>";
	echo "<feature><key>A-ICA</key><value>true</value></feature>";
	echo "<feature><key>A-SMB</key><value>true</value></feature>";
	echo "<feature><key>A-LDAP</key><value>true</value></feature>";
	echo "<feature><key>A-TDS</key><value>true</value></feature>";
	echo "</license></licenses>";
	exit;

// catchall
} else {
	//invalid/unsupported command
	echo "*** FATAL: Unknown command: $command";
	http_response_code(404);
	exit;
}

?>
