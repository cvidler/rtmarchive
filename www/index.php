<?php
	// Config
	define("BASEDIR", "/var/spool/rtmarchive/");


	// Script below, do not edit.


	if ( is_dir(BASEDIR) ) {} else {
		echo "***FATAL: ".BASEDIR." does not exist.\n";
	}


	function getdaydata($amd, $year, $month, $day, $dataset = "ss") {
		// return the extracted zdata stats for browsing

		if ($dataset == "ss") {
			$filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst";
			$file = fopen($filename,"r");
			$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
			fclose($file);
		} elseif ($dataset == "sip") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/serverips.lst";
        	        $file = fopen($filename,"r");
                	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	                fclose($file);
		} elseif ($dataset == "cip") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/clientips.lst";
        	        $file = fopen($filename,"r");
                	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	                fclose($file);
		} elseif ($dataset == "ts") {
	                $filename = BASEDIR.$amd."/".$year."/".$month."/".$day."/timestamps.lst";
        	        $file = fopen($filename,"r");
                	$data = str_replace("\n","<br/>",htmlspecialchars(urldecode(fread($file, filesize($filename)))));
	                fclose($file);
		} elseif ($dataset == "fi") {
			$arcname = BASEDIR.$amd."/".$year."/".$month."/".$amd."-".$year."-".$month."-".$day.".tar.bz2.sha512";
			//chdir(BASEDIR.$amd."/".$year."/".$month."/");
			$retval = "";
			$retval = exec('sha512sum --status -c "'.$arcname.'" ; echo $?');
			if ($retval) {
				$data = "Archive integrity check: <b>FAILED</b><br/>";
			} else {
				$data = "Archive integrity check: OK<br/>";
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
	$linkopts['actives'] = "";

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


	function randnum() {
		return mt_rand();
	}

	//print_r($linkopts);
	


	$serverip = $_SERVER['SERVER_ADDR'];
	$serverport = $_SERVER['SERVER_PORT'];
	$serverssl = $_SERVER['HTTPS'];
	$user = $_SERVER['REMOTE_ADDR'];


	if ( isset($linkopts['remove_dataset']) )  {
		// Remove dataset command

		// open/read config file
		$filename = "activedatasets.conf";
		$datalines = 0;
		if ( file_exists($filename) ) {
		        $file = fopen($filename,"r");
		        while (($buffer = fgets($file)) !== false ) {
		                $buffer = trim($buffer);
				$temp = explode(",", $buffer);
				
				if ( ($temp[0] == $linkopts['remove_dataset']) and ($temp[1] == $user) ) {
					//do nothing, this one is being removed.
					$output = $output;
				} else {
					$output = $output."\n".$buffer;
				}

		        }
		        fclose($file);
			$file = fopen($filename, "w") or die("***FATAL: Unable to update config file.");
			fwrite($file, $output);
			fclose($file);
		}
		
	}


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
			echo " <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd)."\">";
			if ( $linkopts['amd'] == $amd ) { echo "<b>".$amd."</b>";} else { echo $amd; }
			echo "</a>\n";
			$years = scandir(BASEDIR.$amd);
			foreach ($years as $year) {
				if ( is_numeric($year) ) {
					echo "  <ul>\n";
					echo "   <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year)."\">";
					if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year ) { echo "<b>".$year."</b>";} else { echo $year; }
					echo "</a>\n";
					echo "    <ul/>\n";
					$months = scandir(BASEDIR.$amd."/".$year);
					foreach ($months as $month) {
						if ( is_numeric($month) ) {
							echo "     <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month)."\">";
							if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month) { 
								echo "<b>".date_format(date_create($year."-".$month."-01"),"M")."</b>";} 
							else { 
								echo date_format(date_create($year."-".$month."-01"),"M"); }
							echo "</a>\n";
							echo "      <ul>\n";
							$days = scandir(BASEDIR.$amd."/".$year."/".$month);
							foreach ($days as $day) {
								if ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) {
									echo "       <li><a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day)."\">";
									if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month && $linkopts['day'] == $day) { 
										echo "<b>".$day."</b></a><br/>\n";
										if ( $linkopts['dataset'] == "ts") {
											echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts")."\"><b>Time Stamps</b></a></br>\n";
											echo getdaydata($amd, $year, $month, $day, "ts")."\n";
										} else {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts")."\">Time Stamps</a></br>\n";
										}
										if ( $linkopts['dataset'] == "ss") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss")."\"><b>Software Services</b></a></br>\n";
                                                                                        echo getdaydata($amd, $year, $month, $day, "ss")."\n";
                                                                                } else {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss")."\">Software Services</a></br>\n";
										} 
										if ( $linkopts['dataset'] == "sip") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip")."\"><b>Server IP Addresses</b></a></br>\n";
                                                                                        echo getdaydata($amd, $year, $month, $day, "sip")."\n";
                                                                                } else {
											echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip")."\">Server IP Addresses</a></br>\n";

										} 
										if ( $linkopts['dataset'] == "cip") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip")."\"><b>Client IP Addresses</b></a></br>\n";
                                                                                        echo getdaydata($amd, $year, $month, $day, "cip")."\n";
                                                                                } else {

	                                                                                echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip")."\">Client IP Addresses</a></br>\n";
										}
                                                                               if ( $linkopts['dataset'] == "fi") {
                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=fi")."\"><b>Archive Integrity Check</b></a></br>\n";
                                                                                        echo getdaydata($amd, $year, $month, $day, "fi")."\n";
                                                                                } else {

                                                                                        echo "        <a href=\"?link=".base64_encode("rand=".randnum()."&"."amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=fi")."\">Archive Integrity Check</a></br>\n";
                                                                                }

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
		$data = explode(",", $buffer);
		if ( $data[1] == $user ) {
			$datalines++;
			echo " <li>Logon: $data[2], Password: $data[3]<br/>\n ".str_replace("|","<br/>\n ",$data[4])."<br/>\n <a href=\"?link=".base64_encode("rand=".randnum()."&"."remove_dataset=".$data[0]).
			"\"><font size=-1>Remove this dataset from the Archive AMD</font></a></li>\n";
		}
	}
	fclose($file);
}

if ( $datalines == 0 ) {
        echo " <li>No active data sets</li>\n";
}


?>
</uL>

<p><font size=-1>To use, in RUM Console add a new device, enter IP: <?php echo $serverip; ?> and port: <?php echo $serverport; ?>, answer <?php if ( $serverssl ) { echo "Yes"; } else { echo "No"; } ?> to use secure connection.<br/>Use logon information above to collect the active data set.</font></p>
<p><font size=-1>Add that new AMD as a data source to a new empty CAS, and publish the config, the CAS will connect and collect the data files processing them for analysis.</font></p>
</td>
</tr>
</table>

</body>
</html>

