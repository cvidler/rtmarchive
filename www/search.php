<?php

// Config
define("BASEDIR", "/var/spool/rtmarchive/");    // base directory of the archive data structure.


// Script below, do not edit.

if ( !is_dir(BASEDIR) ) {
	echo "***FATAL: ".BASEDIR." does not exist.\n";
	http_response_code(500);
	die;
}


// bomb out back to the index if search text is blank
if ( ! isset($_GET['searchtxt']) or @$_GET['searchtxt'] === "" ) {
	header("Location: /");
}

//echo $_GET['searchtxt'];
$searchtxt = urldecode($_GET['searchtxt']);


// search archive directory lists
$hits = "";
$matches = "";
$filelist = array('softwareservice.lst','serverips.lst','clientips.lst');
$basedir = scandir(BASEDIR);
foreach ($basedir as $amd) {
	if ( !file_exists(BASEDIR.$amd."/prevdir.lst")) { 
		continue; 
	}

	// search amd list files
	$amdfound = false;
	$temp = "";
	foreach ($filelist as $file) {
		$temp = file_get_contents(BASEDIR.$amd."/".$file);
		if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $amdfound = true; }
	}
	if ( !$amdfound ) { continue; }

	$years = scandir(BASEDIR.$amd);
	foreach ($years as $year) {
		if ( !is_numeric($year) ) {
			continue;
		}

		// search year list files
		$yearfound = false;
		$temp = "";
		foreach ($filelist as $file) {
			$temp = file_get_contents(BASEDIR.$amd."/".$file);
			if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $yearfound = true; }
		}
		if ( !$yearfound ) { continue; }
                                   
		$months = scandir(BASEDIR.$amd."/".$year);
		foreach ($months as $month) {
			if ( !is_numeric($month) ) {
				continue;
			}

			// search month list files
			$monthfound = false;
			$temp = "";
			foreach ($filelist as $file) {
				$temp = file_get_contents(BASEDIR.$amd."/".$file);
				if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $monthfound = true; }
			}
			if ( !$monthfound ) { continue; }
                                     
			$days = scandir(BASEDIR.$amd."/".$year."/".$month);
			foreach ($days as $day) {
				if ( ! ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) ) {
					continue;
				}

				// search day list files
				$amdfound = false;
				$temp = ""; $daydata = "";
				foreach ($filelist as $file) {
					$temp = file_get_contents(BASEDIR.$amd."/".$file);
					if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $amdfound = true; $daydata = $daydata.$temp;}
				}
				if ( !$amdfound ) { continue; }

				// we've found the requested data in a day dataset, note it
				$hits = $hits."|".$amd."-".$year."-".$month."-".$day;

				// extract the hit so it can be displayed
				$lines = explode("\n", $daydata);
				//$keys = array_keys($lines, $searchtxt);
				//$matches = "";
				$keys = array_filter($lines, function($value) {
					    return stripos($value, $GLOBALS['searchtxt']) !== false;
				});
				//print_r($keys);
				$matches = implode("|",$keys);

			}
		}
	}
}

if ( $hits === "" ) { $hits = "Nothing found."; }
if ( $matches === "" ) { $matches = "Nothing found."; }
//echo $hits."\n";
//echo $matches."\n";

?>

<html>
<head>
<title>rtmarchive Search - <?php echo $searchtxt; ?></title>
</head>
<body>
<h1>rtmarchive Search Results</h1>
<p>Search Query: <?php echo $searchtxt; ?></p>
<p>Hits</p>
<p><?php echo $matches; ?></p>
<p>Data Sets</p>
<p><?php echo $hits; ?></p>
</body>
</html>
