<?php
// Config
define("BASEDIR", "/var/spool/rtmarchive/");	// base directory of the archive data structure.
define("BASEPORT",9090);			// needs to match available/listening ports in Apache config, or it won't work so well.
define("NUMPORTS",10);				// "


// Script below, do not edit.

if ( !is_dir(BASEDIR) ) {
	echo "***FATAL: ".BASEDIR." does not exist.\n";
}


function getdaydata($amd, $year, $month, $day, $dataset = "ss") {
	// return the extracted zdata stats for browsing
	$data = "";

	$filename = BASEDIR.$amd."/".$year."/".$month."/".$day;
	if ($dataset === "ss") {
		$filename = $filename."/softwareservice.lst";
	} elseif ($dataset === "sip") {
		$filename = $filename."/serverips.lst";
	} elseif ($dataset === "cip") {
		$filename = $filename."/clientips.lst";
	} elseif ($dataset === "ts") {
		$filename = $filename."/timestamps.lst";
	} elseif ($dataset === "ver") {
		$filename = $filename."/versions.lst";
	} elseif ($dataset === "fi") {
		$filename = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$year."-".$month."-".$day.".tar.bz2.sha512";
		if ( file_exists($filename) ) {
			$retval = "";
			$retval = exec('sha512sum --status -c "'.$filename.'" ; echo $?');
			if ( ! $retval === 0 ) {
				$data = "Archive integrity check: <b><font color=red>FAILED</font></b><br/>";
			} else {
				$data = "Archive integrity check: <b><font color=green>OK</font></b><br/>";
			}
		}
	} else {
		$data = "";
	}

	if ( file_exists($filename) and $data === "" ) {
		$file = fopen($filename,"r");
		$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
		fclose($file);
	}

	if ( $dataset === "ts" ) { $data = processtimestamplist($data); }

	if ( $data === "" ) { $data = "No Data Available.<br/>"; }
	return $data;
}


function processtimestamplist($timestamplist = "") {

	if ( $timestamplist === "" ) { 
		return ""; 
	}
	
	$timestamps = explode("<br/>", $timestamplist);
	$count = count($timestamps);

	// strip readable timestamp, and convert hex string to integer
	for ( $i=0; $i < $count; $i++ ) {
		if ( $timestamps[$i] === "" ) { 
			unset($timestamps[$i]); $count--; continue; 
		}
		$temp = explode(",", $timestamps[$i]);
		$timestamps[$i] = hexdec($temp[0]);
	}

	//sort
	sort($timestamps);

	//parse for gaps, first interval determines right interval, sanity checked for norms (multiple of 60 seconds)
	$interval = $timestamps[1] - $timestamps[0];
	if ( ! ($interval >= 60 and $interval <= 300 and (($interval % 60) === 0) ) ) { 
		//can't process this return the raw data
		return $timestamplist; 
	}

	$temp = "";
	$first = $timestamps[0]; $last = 0;
	for ( $i=1; $i < $count; $i++ ) {

		if ( $timestamps[$i] <> $timestamps[$i-1]+$interval ) {
			$last = $timestamps[$i-1];
			$temp = $temp.gmdate(DATE_RFC850,$first+$interval)." thru ".gmdate(DATE_RFC850,$last+$interval)."<br/>";
			$first = $timestamps[$i]; $last = 0;
		}
	}
	if ( $last === 0 ) { 
		$last = $timestamps[$i-1]; $temp = $temp.gmdate(DATE_RFC850,$first+$interval)." thru ".gmdate(DATE_RFC850,$last+$interval)."<br/>"; 
	}
	if ( (($last+$interval) - $first) === 86400 ) { 
		$temp = $temp." Complete<br/>"; 
	} else { 
		$temp = $temp."Incomplete dataset<br/>"; 
	}
	return $temp;
}


//init linkopts variables
$linkopts['rand'] = "";
$linkopts['amd'] = "";
$linkopts['year'] = "";
$linkopts['month'] = "";
$linkopts['day'] = "";
$linkopts['dataset'] = "";
$linkopts['datasets'] = "";

if ( isset($_GET["link"]) ) {
	$link = base64_decode($_GET["link"]);
	if ( strlen($link) ) {
		$options = explode("&", $link);
		$optcount = count($options);
		for($x = 0; $x < $optcount; $x++) {
			$opt =explode("=",$options[$x]);
			$linkopts[$opt[0]] = $opt[1];
		}
	}
}
$datasets = @$linkopts['datasets'];


function randnum() {
	return mt_rand();
}


function generateRandomString($length = 10) {
	$characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
	$charactersLength = strlen($characters);
	$randomString = '';
	for ($i = 0; $i < $length; $i++) {
		$randomString .= $characters[rand(0, $charactersLength - 1)];
	}
	return $randomString;
}



$serverip = $_SERVER['SERVER_ADDR'];
$serverport = $_SERVER['SERVER_PORT'];
if ( isset($_SERVER['HTTPS']) ) { 
	$serverssl = $_SERVER['HTTPS']; 
} else { 
	$serverssl = ""; 
}
$username = $_SERVER['AUTHENTICATE_UID'];
$user = $_SERVER['REMOTE_ADDR'];
if ( $user === "::1" or $user === "127.0.0.1" ) { 
	$localuser = 1; 
} else { 
	$localuser = ""; 
}
if ($username != "") { $user = $username; }


// multi select data set code
$tmpdatasets = ""; $datasets = "";
if ( isset($linkopts['datasets']) ) { 
	$tmpdatasets = explode("|", $linkopts['datasets']); 
}

if ( isset($linkopts['check']) ) {
	$count = count($tmpdatasets);
	$tmpdatasets[$count + 1] = $linkopts['amd'].":".$linkopts['year'].":".$linkopts['month'].":".$linkopts['day'];
	sort($tmpdatasets);
}

if ( isset($linkopts['uncheck']) ) {

	$count = count($tmpdatasets);
	for ( $i = 0; $i < $count; $i++ ) {
		$temp = $linkopts['amd'].":".$linkopts['year'].":".$linkopts['month'].":".$linkopts['day'];
		if ( $tmpdatasets[$i] === $temp ) { 
			unset($tmpdatasets[$i]); array_values($tmpdatasets); 
		}
	}
	sort($tmpdatasets);
}
	
$datasets = implode("|", $tmpdatasets);
$datasetsurl = "";
if ( $datasets <> "" ) { 
	$datasetsurl = "&datasets=".$datasets; 
}



//grab the first selected AMD, we use this to lock the additon of any others.
$activeamd = "";
$activeamd = explode("|", $datasets);
$activeamd = explode(":", @$activeamd[1]);
$activeamd = @$activeamd[0];
if ( $activeamd == "" ) { 
	$activeamd = "nothing"; 
}


function recurseRmdir($dir) {
  $files = array_diff(scandir($dir), array('.','..'));
  foreach ($files as $file) {
    (is_dir("$dir/$file")) ? recurseRmdir("$dir/$file") : unlink("$dir/$file");
  }
  return rmdir($dir);
}


// eAMD config setting code
if ( isset($linkopts['remove_dataset']) )  {
	// Remove dataset command
	// 
	// open/read config file
	$filename = "activedatasets.conf";
	$datalines = 0;
	$output = "";
	if ( file_exists($filename) ) {
		$file = fopen($filename,"r");
		while (($buffer = fgets($file)) !== false ) {
			$buffer = trim($buffer);
			$temp = explode(",", $buffer);

			if ( ($temp[0] === $linkopts['remove_dataset']) and ($temp[1] === $user or $localuser) ) {
				// this one is being removed.
				$tempdir = BASEDIR.".temp/".$temp[0];

				} elseif ( $buffer === "" ) {
					//do nothing, empty line

				} else {
					$output = $output.$buffer."\n";
				}
		}
		fclose($file);

		// Update config file
		$file = fopen($filename, "w") or die("***FATAL: Unable to update config file.");
		fwrite($file, $output);
		fclose($file);

		if ( file_exists($tempdir) ) {
			//remove the temp dir if it exists
			#array_map('unlink', glob("$tempdir/*"));
			#rmdir($tempdir);
			recurseRmdir($tempdir);
		}
	}
	header("Location: /");
}

if ( isset($linkopts['add_dataset']) ) {
	// Add dataset command

	// read file for existing port usage.
	$filename = "activedatasets.conf";
	if ( file_exists($filename) ) {
		$file = fopen($filename, "r");
		$usedports['0'] = 0;
		while (($buffer = fgets($file)) !== false ) {
			$buffer = trim($buffer);
			if ( substr($buffer,0,1) === "#" ) { 
				continue; 
			}
			$temp = explode(",", $buffer);
			$usedports[$temp[4]] = 1;
		}

		// find first unused port
		$port = 0;
		$lastport = BASEPORT + NUMPORTS;
		for ($i = BASEPORT; $i <= $lastport; $i++) {
			if ( isset($usedports[$i]) ) { 
				continue; 
			} else { 
				$port = $i; break; 
			}
		}
		if ( $port <> 0 ) { 
			// append to config file
			$file = fopen($filename, "a") or die("***FATAL: Unable to open config file for appending.");
			if ( $datasets <> "" ) { 
				$temp = $datasets;
			} else { 
				$temp = "|".$linkopts['amd'].":".$linkopts['year'].":".$linkopts['month'].":".$linkopts['day'];
			}
			$uuid = randnum();	
			$output = $uuid.",".$user.",".generateRandomString().",".generateRandomString().",".$port.",".$temp."\n";
	
			fwrite($file, $output);
			fclose($file);
			// create temp dir and extract archives to it
			$tempdir = BASEDIR.".temp/".$uuid;
			mkdir($tempdir, 0777, true);
			$temp = explode("|", $temp);
			$count = count($temp);
			for ( $i = 0; $i < $count; $i++) {
				if ( $temp[$i] === "" ) { 
					continue; 
				}
				$temp2 = explode(":", $temp[$i]);
				$amd = $temp2[0]; $year = $temp2[1]; $month = $temp2[2]; $day = $temp2[3];
				$arcname = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$year."-".$month."-".$day.".tar.bz2";
				if ( !file_exists($arcname) ) { die("***FATAL: Archive $arcname not found. Aborting."); }
				#extract files
				`cd $tempdir && /usr/bin/tar -xjf $arcname --exclude='./conf' --transform='s/.*\///'`;
				#extract config files
				`mkdir $tempdir/conf && cd $tempdir/conf && /usr/bin/tar -xjf $arcname ./conf/ --transform='s/.*\///'`;
				#remove lst files
				array_map('unlink', glob("$tempdir/*.lst"));
			}
		}
		unset($port);
		unset($lastport);
		unset($usedports);
		unset($filename);
		unset($tempdir);
		unset($arcname);
		unset($temp);
		unset($temp2);
		unset($amd);
		unset($year);
		unset($month);
		unset($day);
		unset($i);
		unset($file);
		unset($uuid);
		header("Location: /");
	}
}


function getSymbolByQuantity($bytes) {
	$symbols = array('B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB');
	$exp = floor(log($bytes)/log(1024));

	return sprintf('%.2f'.$symbols[$exp], ($bytes/pow(1024, floor($exp))));
}

class IgnorantRecursiveDirectoryIterator extends RecursiveDirectoryIterator {
    function getChildren() {
        try {
            return new IgnorantRecursiveDirectoryIterator($this->getPathname());
        } catch(UnexpectedValueException $e) {
            return new RecursiveArrayIterator(array());
        }
    }
} 

function get_dir_size($directory) {
	$size = 0;
	if ( file_exists($directory) ) {
		foreach (new RecursiveIteratorIterator(new IgnorantRecursiveDirectoryIterator($directory)) as $file) {
			$size += $file->getSize();
		}
	}
	return $size;
}



// now onto html
?>
<html>
<head>
<title>rtmarchive System</title>
<style>
	.bold { font-weight: bold; }
</style>
</head>
<body>
<h1>rtmarchive System</h1>

<table>
<tr>
<td colspan="2" align="right"><form action="search.php">Search IP/Software Service: <input type="text" name="searchtxt" size="40"/><input type="submit" value="Search"/></form></td>
</tr>
<tr>
<td width="50%" valign="top">
<h2>Archive Sources</h2>
<ul class="list">
<?php
$basedir = scandir(BASEDIR);
foreach ($basedir as $amd) {
	if (file_exists(BASEDIR.$amd."/uuid.lst")) {
		echo " <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd.$datasetsurl)."\">";
		if ( !($linkopts['amd'] === $amd) ) { echo $amd."</a></li>\n"; continue; }
		echo "<b>".$amd."</b></a>\n";
		$years = scandir(BASEDIR.$amd);
		foreach ($years as $year) {
			if ( !is_numeric($year) || !file_exists(BASEDIR.$amd."/".$year."/softwareservice.lst") ) { 
				continue; 
			}
			echo "  <ul>\n";
			echo "   <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year.$datasetsurl)."\">";
			if ( !($linkopts['amd'] === $amd && $linkopts['year'] === $year) ) { echo $year."</a></li>\n</ul>\n"; continue; } 
			echo "<b>".$year."</b></a>\n";
			echo "    <ul>\n";
			$months = scandir(BASEDIR.$amd."/".$year);
			foreach ($months as $month) {
				if ( !is_numeric($month) || !file_exists(BASEDIR.$amd."/".$year."/".$month."/softwareservice.lst") ) { 
					continue;
				}
				echo "     <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month.$datasetsurl)."\">";
				if ( $linkopts['amd'] === $amd && $linkopts['year'] === $year && $linkopts['month'] === $month) { 
					echo "<b>".date_format(date_create($year."-".$month."-01"),"M")."</b></a>\n";
					echo "      <ul>\n";
					$days = scandir(BASEDIR.$amd."/".$year."/".$month);
					foreach ($days as $day) {
						if ( ! ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) ) {
							continue;
						}
						echo "       <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day.$datasetsurl)."\">";
						if ( $linkopts['amd'] === $amd && $linkopts['year'] === $year && $linkopts['month'] === $month && $linkopts['day'] === $day) {
							echo "<b>".$day."</b></a><br/>\n";
							if ( $linkopts['dataset'] === "ts") {
								echo "        <b>Time Stamps</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "ts")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts".$datasetsurl).
									"\">Time Stamps</a><br/>\n";
							}

							if ( $linkopts['dataset'] === "ss") {
								echo "        <b>Software Services</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "ss")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss".$datasetsurl).
									"\">Software Services</a><br/>\n";
							}
							if ( $linkopts['dataset'] === "sip") {
								echo "        <b>Server IP Addresses</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "sip")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip".$datasetsurl).
									"\">Server IP Addresses</a><br/>\n";
							}
							if ( $linkopts['dataset'] === "cip") {
								echo "        <b>Client IP Addresses</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "cip")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip".$datasetsurl).
									"\">Client IP Addresses</a><br/>\n";
							}
							if ( $linkopts['dataset'] === "ver") {
								echo "        <b>AMD Version</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "ver")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ver".$datasetsurl).
									"\">AMD Version</a><br/>\n";
							}
							if ( $linkopts['dataset'] === "fi") {
								echo "        <b>Archive Integrity Check</b><br/>\n".
									getdaydata($amd, $year, $month, $day, "fi")."\n";
							} else {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=fi".$datasetsurl).
									"\">Archive Integrity Check</a><br/>\n";
							}


							if ( (( $activeamd === $amd ) or ( $activeamd === "nothing" )) and ( strrpos($datasets, $amd.":".$year.":".$month.":".$day) === false  ) ) {
								echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&check=true".$datasetsurl).
									"\">Add to dataset</a> \n";
							} else {
								echo "        <font color=grey>Add to dataset</font>\n";
							}
						}
						else {
							echo $day."</a></li>\n"; }
					}
					echo "      </ul>\n";
					echo "     </li>\n";
				}
				else { 
					echo date_format(date_create($year."-".$month."-01"),"M")."</a>\n"; }
			}
			echo "    </ul>\n";
			echo "   </li>\n";
			echo "  </ul>\n";
		}
		echo " </li>\n";
	}
}
?>
</ul>
<?php 

if ( $datasets <> "" ) {
	echo "<h3>Create Dataset</h3>\n";
	$temp = explode("|", $datasets);
	$count = count($temp);
	for ( $i = 0; $i < $count; $i++) {
		if ( $temp[$i] === "" ) { 
			continue; 
		}
		$temp2 = explode(":", $temp[$i]);
		echo $temp2[0]." ".$temp2[1]."/".$temp2[2]."/".$temp2[3]." <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$temp2[0]."&year=".$temp2[1]."&month=".$temp2[2]."&day=".$temp2[3]."&uncheck=true".$datasetsurl)."\">Uncheck</a><br/>\n";
	}
	echo "<br/><a href=\"?link=".base64_encode("rand=".randnum()."&add_dataset=true".$datasetsurl).
		"\">Add to Archive AMD</a><br/>\n";
}
?>
<p><font size="-1"><a href="?">Clear</a></font></p>
</td>

<td width="50%" valign="top">
<h2>AMD Control</h2>
<ul class="list">
<?php
// load currently active data sets from config file

$filename = "activedatasets.conf";
$datalines = 0;
if ( file_exists($filename) ) {
	$file = fopen($filename,"r");
	while (($buffer = fgets($file)) !== false ) {
		$buffer = trim($buffer);
		if ( substr($buffer,0,1) === "#" ) { continue; }
		$data = explode(",", $buffer);
		if ( ($data[1] === $user) or ($localuser) ) {
			$datalines++;
			if ( $data[1] <> $user ) { $notyours = "NOT YOUR DATASET, Confirm with user at: $data[1]\\n"; } else { $notyours = "";}
			echo " <li>Logon: $data[2], Password: $data[3], Port: $data[4]<br/>\n ";
			$temp = explode("|", $data[5]);
			$count = count($temp);
			for ( $i = 0; $i < $count; $i++) {
				if ( $temp[$i] === "" ) { 
					continue; 
				}
				$temp2 = explode(":", $temp[$i]);
				echo $temp2[0]." ".$temp2[1]."/".$temp2[2]."/".$temp2[3]."<br/>\n";
			}
			echo "<a onclick=\"javascript:return confirm('$notyours\\nRemove active dataset:".str_replace("|","\\n",$data[5])."\\non port: $data[4]');\" href=\"?link=".base64_encode("rand=".randnum()."&"."remove_dataset=".$data[0])."\">";
			echo "<font size=-1>Remove this dataset from the Archive AMD</a>";
			if ( $localuser ) { echo " by $data[1]"; }
			$dir = BASEDIR.".temp/".$data[0];
			$size = getSymbolByQuantity(get_dir_size($dir));
			echo ' Dataset size: '.$size;
			echo "<br/>&nbsp;</font></li>\n";
		}
	}
	fclose($file);
}

if ( $datalines === 0 ) {
	echo " <li>No active data sets</li>\n";
}
?>
</uL>

<p><font size=-1>To use, in RUM Console add a new device, enter IP: <?php echo $serverip; ?>, answer <?php if ( $serverssl ) { echo "Yes"; } else { echo "No"; } ?> to use secure connection. Turn off Guided Configuration and SNMP.<br/>Use logon information above to collect the active data set.</font></p>
<p><font size=-1>Add that new AMD as a data source to a new empty CAS, and publish the config, the CAS will connect and collect the data files processing them for analysis.</font></p>
<p><font size=-1>Removing a dataset config is, after confirmation, instant and permanent - there's no undo.  It'll break any currently operating CAS processing that dataset.</font></p>
</td>
</tr>
<tr>
<td colspan="2">
<p><br/><font size=-1>
<?php
echo 'User name: '.$user.' ';
$dir = BASEDIR;
$size = getSymbolByQuantity(get_dir_size($dir));
echo 'Archive size: '.$size;

$free = getSymbolByQuantity(disk_free_space($dir));
$per_free = (disk_free_space($dir) / disk_total_space($dir)) * 100;
echo " - Free space: $free ";
printf("%.1f", $per_free);
echo "%";
if ( $per_free < 10 ) {
	echo "<font color=red size=2>LOW DISK SPACE!</red>";
}
?>
<br/><a target="_new" href="https://github.com/cvidler/rtmarchive/">Chris Vidler - Dynatrace DCRUM SME 2015</a>
</font></p>
</td>
</tr>
</table>

</body>
</html>

