<?php

// Config
define("BASEDIR", "/var/spool/rtmarchive/");    // base directory of the archive data structure.
$debug = 0;

// Script below, do not edit.
session_start();

if ( isset($_GET['clearsearch']) ) {
	unset($_SESSION['searchresults']);
	unset($_SESSION['searchallmatches']);
}

if ( !is_dir(BASEDIR) ) {
	echo "***FATAL: ".BASEDIR." does not exist.\n";
	http_response_code(500);
	die;
}


// bomb out back to the index if search text is blank
if ( ! isset($_GET['searchtxt']) or @$_GET['searchtxt'] === "" ) {
	http_response_code(400);
	header("Location: /");
}

function outputProgress($current, $total, $text = 'Searching' ) {
	echo "<span class='progress' style='position: absolute;z-index:$current;background:#FFF;'>$text: ".round($current / $total * 100)."% </span>";
	myFlush();
}

function myFlush() {
	echo(str_repeat(' ', 4096));
	if (@ob_get_contents()) {
		@ob_end_flush();
	}
	flush();
}

function randnum() {
	return mt_rand();
}



// handle session vars for creation of datasets
if ( isset($_SESSION['datasets']) ) {
	$tmpdatasets = explode("|", $_SESSION['datasets']); 
}

if ( isset($_GET['check']) ) {
	$count = count($tmpdatasets);
	$tmpdatasets[$count + 1] = urldecode($_GET['amd']).":".$_GET['year'].":".$_GET['month'].":".$_GET['day'];
	sort($tmpdatasets);
}

if ( isset($_GET['uncheck']) ) {

	$count = count($tmpdatasets);
	for ( $i = 0; $i < $count; $i++ ) {
		$temp = urldecode($_GET['amd']).":".$_GET['year'].":".$_GET['month'].":".$_GET['day'];
		if ( $tmpdatasets[$i] === $temp ) { 
			unset($tmpdatasets[$i]); array_values($tmpdatasets); 
		}
	}
	sort($tmpdatasets);
}

$datasets = implode("|", $tmpdatasets);
$_SESSION['datasets'] = $datasets;
//echo $datasets;




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
<table width="100%">
<tr>
<td></td>
<td colspan="1" align="right"><form action="search.php">Search IP/Software Service: <input type="text" name="searchtxt" size="40" value="<?php echo $searchtxt; ?>"/><input type="submit" value="Search"/></form></td>
</tr>
<tr><td colspan="2">
<b>Search results for query: </b>"<?php echo $searchtxt; ?>" - <a href="?clearsearch=true">Clear Search Results</a>
</td></tr>
<?php

if ( isset($_SESSION['searchresults']) && ($_SESSION['searchstring'] == $searchtxt) ) {
	//search already run, so existing results.
	echo "<!-- reloaded search results from session -->";
	$ahits = $_SESSION['searchresults'];
	$temparr = $_SESSION['searchallmatches'];
	$searchtxt = $_SESSION['searchstring'];
} else {
	// search archive directory lists
	$hits = "";
	$matches = "";
	$allmatches = "";
	$filelist = array('softwareservice.lst','serverips.lst','clientips.lst');
	$count = 0; $total = 0;
	$basedir = scandir(BASEDIR);
	$total = $total + count($basedir);


	foreach ($basedir as $amd) {
	$count++;
	if ( !file_exists(BASEDIR.$amd."/prevdir.lst")) { 
		continue; 
	}

	//if ( $debug ) { print $amd."</br>"; }

	// search amd list files
	$amdfound = false;
	$temp = "";
	foreach ($filelist as $file) {
		$temp = file_get_contents(BASEDIR.$amd."/".$file);
		//if ( $debug ) { print $amd."/".$file."|".$temp."|"."</br>"; }
		if ( (!$temp === false) and (stripos($temp, $searchtxt) !== false) ) { $amdfound = true; }
	}
	if ( !$amdfound ) { continue; }

	$years = scandir(BASEDIR.$amd);
	$total = $total + count($years);
	foreach ($years as $year) {
		$count++;
		if ( !is_numeric($year) ) {
			continue;
		}

		//if ( $debug ) { print $amd."/".$year."</br>"; }


		// search year list files
		$yearfound = false;
		$temp = "";
		foreach ($filelist as $file) {
			$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$file);
			//if ( $debug ) { print $amd."/".$year."/".$file."|".$temp."|"."</br>"; }
			if ( (!$temp === false) and (stripos($temp, $searchtxt) !== false) ) { $yearfound = true; }
		}
		if ( !$yearfound ) { continue; }
								   
		$months = scandir(BASEDIR.$amd."/".$year);
		$total = $total + count($months);
		foreach ($months as $month) {
			$count++;
			if ( !is_numeric($month) ) {
				continue;
			}

			//if ( $debug ) { print $amd."/".$year."/".$month."</br>"; }

			// search month list files
			$monthfound = false;
			$temp = "";
			foreach ($filelist as $file) {
				$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$month."/".$file);
				//if ( $debug ) { print $amd."/".$year."/".$month."/".$file."|".$temp."|"."</br>"; }
				if ( (!$temp === false) and (stripos($temp, $searchtxt) !== false) ) { $monthfound = true; }
			}
			if ( !$monthfound ) { continue; }
									 
			$days = scandir(BASEDIR.$amd."/".$year."/".$month);
			$total = $total + count($days);
			foreach ($days as $day) {
				$count++;
				if ( ! ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) ) {
					continue;
				}

				//if ( $debug ) { print $amd."/".$year."/".$month."/".$day."</br>"; }

				// search day list files
				$dayfound = false;
				$temp = ""; $daydata = "";
				foreach ($filelist as $file) {
					$temp = file_get_contents(BASEDIR.$amd."/".$year."/".$month."/".$day."/".$file);
					//if ( $debug ) { print $amd."/".$year."/".$month."/".$day."/".$file."|".$temp."|"."</br>"; }
					if ( (!$temp === false) and (stripos($temp, $searchtxt) !== false) ) { $dayfound = true; $daydata = $daydata.$temp;}
				}

				//outputProgress($count, $total);

				//if ( $debug ) { print "<b>".$dayfound."</b>"; }
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

				//if ( $debug ) { print "allmatches:".$allmatches."<br/>"; }

				$ahits[$amd][$year."-".$month."-".$day] = $keys;
				//if ( $debug) { var_dump($ahits); }


			}
			outputProgress($count, $total);
		}
	}
	}

	$temparr = array_unique(explode("|",ltrim(@$allmatches,"|")));
	asort($temparr);
	$allmatches = implode(",<br/>",$temparr);

	outputProgress($total + 1, $total + 1, "Loading page");

	if ( @$ahits == "" ) { $ahits["Nothing found."] = ""; }
	if ( $allmatches == "" ) { $temparr[0] ="Nothing found."; }
	//echo $hits."\n";
	//echo $matches."\n";

	$_SESSION['searchresults'] = $ahits;
	$_SESSION['searchallmatches'] = $temparr;
	$_SESSION['searchstring'] = $searchtxt;
}

?>
<tr><td valign="top">
<h3>Hits</h3>

<?php
echo "<ul>\n";
foreach ($temparr as $match) {
	echo "<li>$match</li>\n";
}
echo "</ul>\n";
?>
</td>
<td valign="top">
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
			$dpart = explode("-",$date); $year = $dpart[0]; $month = $dpart[1]; $day = $dpart[2];
			echo "<li><a href=\"?searchtxt=".urlencode($searchtxt)."&amd=".urlencode($amd)."&year=".$year."&month=".$month."&day=".$day."&check=true"."\">$date</a> - ".implode(", ",$data)."</li>\n";
		}
		echo "</ul>\n";
		echo "</li>\n";
	}
}
echo "</ul>\n";

?>
</td>
</tr>
</table>


</body>
</html>
