<?php
	// Config
	define("BASEDIR", "/var/spool/rtmarchive/");	// base directory of teh archive data structure.
	define("BASEPORT",9090);			// needs to match available/listening ports in Apache config, or it won't work so well.
	define("NUMPORTS",10);				// "


	// Script below, do not edit.


	if ( is_dir(BASEDIR) ) {} else {
		echo "***FATAL: ".BASEDIR." does not exist.\n";
	}


	function getdaydata($amd, $year, $month, $day, $dataset = "ss") {
		// return the extracted zdata stats for browsing
		$data = "";

		if ($dataset == "ss") {
			$filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst";
			if ( file_exists($filename) ) {
				$file = fopen($filename,"r");
				$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
				fclose($file);
			}
		} elseif ($dataset == "sip") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/serverips.lst";
			if ( file_exists($filename) ) {
	        	        $file = fopen($filename,"r");
        	        	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	        	        fclose($file);
			}
		} elseif ($dataset == "cip") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/clientips.lst";
			if ( file_exists($filename) ) {
	        	        $file = fopen($filename,"r");
        	        	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	        	        fclose($file);
			}
		} elseif ($dataset == "ts") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/timestamps.lst";
			if ( file_exists($filename) ) {
	        	        $file = fopen($filename,"r");
        	        	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	        	        fclose($file);
			}
		} elseif ($dataset == "fi") {
			$arcname = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$year."-".$month."-".$day.".tar.bz2.sha512";
			//chdir(BASEDIR.$amd."/".$year."/".$month."/");
			if ( file_exists($arcname) ) {
				$retval = "";
				$retval = exec('sha512sum --status -c "'.$arcname.'" ; echo $?');
				if ($retval) {
					$data = "Archive integrity check: <b>FAILED</b><br/>";
				} else {
					$data = "Archive integrity check: OK<br/>";
				}
			}
		} else {
			$data = "";
		}
		if ( $data == "" ) { $data = "No Data Available.<br/>"; }
		return $data;
	}

	//init linkopts variables
	$linkopts['rand'] = "";
	$linkopts['amd'] = "";
	$linkopts['year'] = "";
	$linkopts['month'] = "";
	$linkopts['day'] = "";
	$linkopts['dataset'] = "";
	$linkopts['datasets'] = "";

	if (count($_GET)) {
	$link = base64_decode($_GET["link"]);
	if ( strlen($link) ) {
		$options = explode("&", $link);
		//print_r($options);
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
	if ( isset($_SERVER['HTTPS']) ) { $serverssl = $_SERVER['HTTPS']; } else { $serverssl = ""; }
	$user = $_SERVER['REMOTE_ADDR'];
	if ( $user == "::1" or $user == "127.0.0.1" ) { $localuser = 1; } else { $localuser = ""; }



	// multi select data set code
	$tmpdatasets = ""; $datasets = "";
	if ( isset($linkopts['datasets']) ) { $tmpdatasets = explode("|", $linkopts['datasets']); }

	if ( isset($linkopts['check']) ) {

		$count = count($tmpdatasets);
		$tmpdatasets[$count + 1] = $linkopts['amd']."-".$linkopts['year']."-".$linkopts['month']."-".$linkopts['day'];
		sort($tmpdatasets);		
	}

	if ( isset($linkopts['uncheck']) ) {
	
		$count = count($tmpdatasets);
		for ( $i = 0; $i < $count; $i++ ) {
			$temp = $linkopts['amd']."-".$linkopts['year']."-".$linkopts['month']."-".$linkopts['day'];
			if ( $tmpdatasets[$i] == $temp ) { unset($tmpdatasets[$i]); array_values($tmpdatasets); }
		}
		sort($tmpdatasets);
        }
	
	$datasets = implode("|", $tmpdatasets);
	$datasetsurl = "";
	if ( $datasets <> "" ) { $datasetsurl = "&datasets=".$datasets; }


	// eAMD config setting code
	if ( isset($linkopts['remove_dataset']) )  {
		// Remove dataset command

		// open/read config file
		$filename = "activedatasets.conf";
		$datalines = 0;
		$output = "";
		if ( file_exists($filename) ) {
		        $file = fopen($filename,"r");
		        while (($buffer = fgets($file)) !== false ) {
		                $buffer = trim($buffer);
				$temp = explode(",", $buffer);
				
				if ( ($temp[0] == $linkopts['remove_dataset']) and ($temp[1] == $user or $localuser) ) {
					// this one is being removed.
					$tempdir = BASEDIR.".temp/".$temp[0];
					
				} elseif ( $buffer == "" ) {
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
                                `rm -rf $tempdir`;
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
				if ( substr($buffer,0,1) == "#" ) { continue; }
				$temp = explode(",", $buffer);
				$usedports[$temp[4]] = 1;
			}

			// find first unused port
			$port = 0;
			$lastport = BASEPORT + NUMPORTS;
			for ($i = BASEPORT; $i <= $lastport; $i++) {
				if ( isset($usedports[$i]) ) { continue; } else { $port = $i; break; }
			}
			if ( $port <> 0 ) { 
				// append to config file
				$file = fopen($filename, "a") or die("***FATAL: Unable to open config file for appending.");
				if ( $datasets <> "" ) { 
					$temp = $datasets;
				} else { 
					$temp = "|".$linkopts['amd']."-".$linkopts['year']."-".$linkopts['month']."-".$linkopts['day'];
				}
				$uuid = randnum();	
				$output = $uuid.",".$user.",".generateRandomString().",".generateRandomString().",".$port.",".$temp."\n";
				
				fwrite($file, $output);
				fclose($file);
				// create temp dir and extract archives to it
				$tempdir = BASEDIR.".temp/".$uuid;
				`mkdir -p $tempdir`;
			        $temp = explode("|", $temp);
			        $count = count($temp);
			        for ( $i = 0; $i < $count; $i++) {
			                if ( $temp[$i] == "" ) { continue; }
			                $temp2 = explode("-", $temp[$i]);
					$amd = $temp2[0]; $year = $temp2[1]; $month = $temp2[2]; $day = $temp2[3];
					$arcname = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$year."-".$month."-".$day.".tar.bz2";
					if ( !file_exists($arcname) ) { die("***FATAL: Archive $arcname not found. Aborting."); }
					`cd $tempdir && /usr/bin/tar -xjf $arcname --transform='s/.*\///'`;
					`rm -f $tempdir/*.lst`;
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


// now onto html

?>
<html>
<head>
<title>rtmarchive System</title>
</head>
<body>
<h1>rtmarchive System</h1>
<h6>Chris Vidler - Dynatrace DCRUM SME 2015</h6>

<table>
<tr>
<td width="50%" valign="top">
<h2>Archive Sources</h2>
<ul class="list">
<?php
	$basedir = scandir(BASEDIR);
	foreach ($basedir as $amd) {
		if (file_exists(BASEDIR.$amd."/prevdir.lst")) {
			echo " <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd.$datasetsurl)."\">";
			if ( $linkopts['amd'] == $amd ) { echo "<b>".$amd."</b>";} else { echo $amd; }
			echo "</a>\n";
			$years = scandir(BASEDIR.$amd);
			foreach ($years as $year) {
				if ( is_numeric($year) ) {
					echo "  <ul>\n";
					echo "   <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year.$datasetsurl)."\">";
					if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year ) { echo "<b>".$year."</b>";} else { echo $year; }
					echo "</a>\n";
					echo "    <ul/>\n";
					$months = scandir(BASEDIR.$amd."/".$year);
					foreach ($months as $month) {
						if ( is_numeric($month) ) {
							echo "     <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month.$datasetsurl)."\">";
							if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month) { 
								echo "<b>".date_format(date_create($year."-".$month."-01"),"M")."</b>";} 
							else { 
								echo date_format(date_create($year."-".$month."-01"),"M"); }
							echo "</a>\n";
							echo "      <ul>\n";
							$days = scandir(BASEDIR.$amd."/".$year."/".$month);
							foreach ($days as $day) {
								if ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) {
									echo "       <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day.$datasetsurl)."\">";
									if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month && $linkopts['day'] == $day) { 
										echo "<b>".$day."</b></a><br/>\n";
										if ( $linkopts['dataset'] == "ts") {
											echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts".$datasetsurl).
											"\"><b>Time Stamps</b></a><br/>\n".
											getdaydata($amd, $year, $month, $day, "ts")."\n";
										} else {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts".$datasetsurl).
											"\">Time Stamps</a><br/>\n";
										}
										if ( $linkopts['dataset'] == "ss") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss".$datasetsurl).
											"\"><b>Software Services</b></a><br/>\n".
                                                                                        getdaydata($amd, $year, $month, $day, "ss")."\n";
                                                                                } else {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss".$datasetsurl).
											"\">Software Services</a><br/>\n";
										} 
										if ( $linkopts['dataset'] == "sip") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip".$datasetsurl).
											"\"><b>Server IP Addresses</b></a><br/>\n".
                                                                                        getdaydata($amd, $year, $month, $day, "sip")."\n";
                                                                                } else {
											echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip".$datasetsurl).
											"\">Server IP Addresses</a><br/>\n";

										} 
										if ( $linkopts['dataset'] == "cip") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip".$datasetsurl).
											"\"><b>Client IP Addresses</b></a><br/>\n".
                                                                                        getdaydata($amd, $year, $month, $day, "cip")."\n";
                                                                                } else {

	                                                                                echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip".$datasetsurl).
											"\">Client IP Addresses</a><br/>\n";
										}
                                                                               if ( $linkopts['dataset'] == "fi") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=fi".$datasetsurl).
											"\"><b>Archive Integrity Check</b></a><br/>\n".
                                                                                        getdaydata($amd, $year, $month, $day, "fi")."\n";
                                                                                } else {

                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=fi".$datasetsurl).
											"\">Archive Integrity Check</a><br/>\n";
                                                                                }
										echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&check=true".$datasetsurl).
                                                                                "\">Add to dataset</a> \n";


									} 
									else { 
										echo $day."</a></li>\n"; }
								}
							}
							echo "      </ul>\n";
							echo "     </li>\n";
						}
					}
					echo "    </ul>\n";
					echo "   </li>\n";
					echo "  </ul>\n";
				}
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
		if ( $temp[$i] == "" ) { continue; }
		$temp2 = explode("-", $temp[$i]);
		echo $temp2[0]." ".$temp2[1]."/".$temp2[2]."/".$temp2[3]." <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$temp2[0]."&year=".$temp2[1]."&month=".$temp2[2]."&day=".$temp2[3]."&uncheck=true".$datasetsurl)."\">Uncheck</a><br/>\n";
	}
		echo "<br/><a href=\"?link=".base64_encode("rand=".randnum()."&add_dataset=true".$datasetsurl).
	             "\">Add to Archive AMD</a><br/>\n";
}

?>
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
		if ( substr($buffer,0,1) == "#" ) { continue; }
		$data = explode(",", $buffer);
		if ( ($data[1] == $user) or ($localuser) ) {
			$datalines++;
			if ( $data[1] <> $user ) { $notyours = "NOT YOUR DATASET, Confirm with user at: $data[1]\\n"; } else { $notyours = "";}
			echo " <li>Logon: $data[2], Password: $data[3], Port: $data[4]<br/>\n ";
        		$temp = explode("|", $data[5]);
		        $count = count($temp);
		        for ( $i = 0; $i < $count; $i++) {
		                if ( $temp[$i] == "" ) { continue; }
		                $temp2 = explode("-", $temp[$i]);
		                echo $temp2[0]." ".$temp2[1]."/".$temp2[2]."/".$temp2[3]."<br/>\n";
		        }
			echo "<a onclick=\"javascript:return confirm('$notyours\\nRemove active dataset:".str_replace("|","\\n",$data[5])."\\non port: $data[4]');\" href=\"?link=".base64_encode("rand=".randnum()."&"."remove_dataset=".$data[0])."\">";
			echo "<font size=-1>Remove this dataset from the Archive AMD</a>";
			if ( $localuser ) { echo " by $data[1]"; }
			echo "<br/>&nbsp;</font></li>\n";
		}
	}
	fclose($file);
}

if ( $datalines == 0 ) {
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
<p><font size=-2>
<?php
    $dir = BASEDIR;
    $size = `/usr/bin/du -sh $dir`;
    $size = substr($size, 0, strpos($size, "\t"));
    echo 'Archive size: '.$size;

    $size = `/usr/bin/df -h $dir | tail -n 1`;
    $size = preg_split("/\s+/",$size);
    $free = 100 - $size[4];
    echo ' Free space: '.$size[3]." ".$free."%";

?>
</font></p>
</td>
</tr>
</table>

</body>
</html>

