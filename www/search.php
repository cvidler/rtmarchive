<?php

// Config
define("BASEDIR", "/var/spool/rtmarchive/");    // base directory of the archive data structure.
$debug = 1;

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

function outputProgress($current, $total, $text = 'Searching' ) {
	echo "<span class='progress' style='position: absolute;z-index:$current;background:#FFF;'>$text: ".round($current / $total * 100)."% </span>";
	myFlush();
}

function myFlush() {
	echo(str_repeat(' ', 256));
	if (@ob_get_contents()) {
		@ob_end_flush();
	}
	flush();
}


//echo $_GET['searchtxt'];
$searchtxt = urldecode($_GET['searchtxt']);

?>
<html>
<head>
<title>rtmarchive Search - <?php echo $searchtxt; ?></title>
<style>
	.progress { display: block; }
	.hidden { display: none; }
</style>
<script>
<!--
	function cssrules(){
		var rules={}; var ds=document.styleSheets,dsl=ds.length;
		for (var i=0;i<dsl;++i){
			var dsi=ds[i].cssRules,dsil=dsi.length;
			for (var j=0;j<dsil;++j) rules[dsi[j].selectorText]=dsi[j];
		}
		return rules;
	};
function css_getclass(name,createifnotfound){
	var rules=cssrules();
	if (!rules.hasOwnProperty(name)) throw 'todo:deal_with_notfound_case';
	return rules[name];
//};
};

-->
</script>
</head>
<body onload="javascript:css_getclass('.progress').style.display='none';">
<h1>rtmarchive Search Results</h1>
<p>Search Query: <?php echo $searchtxt; ?></p>
<?php

// search archive directory lists
$hits = "";
$matches = "";
$filelist = array('softwareservice.lst','serverips.lst','clientips.lst');
$count = 0; $total = 0;
$basedir = scandir(BASEDIR);
$total = $total + count($basedir);
foreach ($basedir as $amd) {
$count++;
if ( !file_exists(BASEDIR.$amd."/prevdir.lst")) { 
	continue; 
}

if ( $debug ) { print $amd."</br>"; }

// search amd list files
$amdfound = false;
$temp = "";
$allmatches = "";
foreach ($filelist as $file) {
	$temp = file_get_contents(BASEDIR.$amd."/".$file);
	//if ( $debug ) { print $amd."/".$file."|".$temp."|"."</br>"; }
	if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $amdfound = true; }
}
if ( !$amdfound ) { continue; }

$years = scandir(BASEDIR.$amd);
$total = $total + count($years);
foreach ($years as $year) {
	$count++;
	if ( !is_numeric($year) ) {
		continue;
	}

	if ( $debug ) { print $amd."/".$year."</br>"; }


	// search year list files
	$yearfound = false;
	$temp = "";
	foreach ($filelist as $file) {
		$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$file);
		//if ( $debug ) { print $amd."/".$year."/".$file."|".$temp."|"."</br>"; }
		if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $yearfound = true; }
	}
	if ( !$yearfound ) { continue; }
							   
	$months = scandir(BASEDIR.$amd."/".$year);
	$total = $total + count($months);
	foreach ($months as $month) {
		$count++;
		if ( !is_numeric($month) ) {
			continue;
		}

		if ( $debug ) { print $amd."/".$year."/".$month."</br>"; }

		// search month list files
		$monthfound = false;
		$temp = "";
		foreach ($filelist as $file) {
			$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$month."/".$file);
			//if ( $debug ) { print $amd."/".$year."/".$month."/".$file."|".$temp."|"."</br>"; }
			if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $monthfound = true; }
		}
		if ( !$monthfound ) { continue; }
								 
		$days = scandir(BASEDIR.$amd."/".$year."/".$month);
		$total = $total + count($days);
		foreach ($days as $day) {
			$count++;
			if ( ! ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) ) {
				continue;
			}

			if ( $debug ) { print $amd."/".$year."/".$month."/".$day."</br>"; }

			// search day list files
			$dayfound = false;
			$temp = ""; $daydata = "";
			foreach ($filelist as $file) {
				$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$month."/".$day."/".$file);
				//if ( $debug ) { print $amd."/".$year."/".$month."/".$day."/".$file."|".$temp."|"."</br>"; }
				if ( (!$temp === false) and (!stripos($temp, $searchtxt) === false) ) { $dayfound = true; $daydata = $daydata.$temp;}
			}

			//outputProgress($count, $total);

			if ( $debug ) { print "<b>".$dayfound."</b>"; }
			if ( !$dayfound ) { continue; }

			// we've found the requested data in a day dataset, note it
			//$hits = $hits."|".$amd."-".$year."-".$month."-".$day;

			// extract the hit so it can be displayed
			$lines = explode("\n", $daydata);
			//$keys = array_keys($lines, $searchtxt);
			$matches = "";
			$keys = array_filter($lines, function($value) {
					return stripos($value, $GLOBALS['searchtxt']) !== false;
			});
			asort($keys);
			$keys = array_unique(array_values($keys));
			//print_r($keys);
			$matches = implode("|",$keys);
			$allmatches = $allmatches."|".$matches;

			$ahits[$amd][$year."-".$month."-".$day] = $keys;
			if ( $debug) { var_dump($ahits); }


		}
		outputProgress($count, $total);
	}
}
}

if ( $debug ) { print "allmatches:".$allmatches; }

$temparr = array_unique(explode("|",ltrim(@$allmatches,"|")));
asort($temparr);
$allmatches = implode(",<br/>",$temparr);

outputProgress($total + 1, $total + 1, "Loading page");

if ( @$ahits == "" ) { $ahits["Nothing found."] = ""; }
if ( $allmatches == "" ) { $temparr[0] ="Nothing found."; }
//echo $hits."\n";
//echo $matches."\n";

?>
<h3>Hits</h3>

<?php
echo "<ul>\n";
foreach ($temparr as $match) {
	echo "<li>$match</li>\n";
}
echo "</ul>\n";
?>

<h3>Data Sets</h3>

<?php

echo "<ul>\n";
if ( $allmatches === "" ) {
	echo "<li>No matches in archive data found</li>\n";
} else {
	foreach ($ahits as $amd => $dates) {
		echo "<li>".$amd."\n";
		echo "<ul>\n";
		foreach ($dates as $date => $data) {
			echo "<li>$date - ".implode(", ",$data)."</li>\n";
		}
		echo "</ul>\n";
		echo "</li>\n";
	}
}
echo "</ul>\n";


?>



</body>
</html>
