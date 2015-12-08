<?php
	define("BASEDIR", "/var/spool/rtmarchive/");


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
		} else {
			$data = "";
		}

		return $data;
	}

	//init linkopts variables
	$linkopts['amd'] = "";
	$linkopts['year'] = "";
	$linkopts['month'] = "";
	$linkopts['day'] = "";
	$linkopts['dataset'] = "";

	if (count($_GET)) {
	$link = base64_decode($_GET["link"]);
	if ( strlen($link) ) {
		$options = split("&", $link);
		//print_r($options);
		$optcount = count($options);
		for($x = 0; $x < $optcount; $x++) {
			$opt = split("=",$options[$x]);
			$linkopts[$opt[0]] = $opt[1];
		}
	}
	}

	//print_r($linkopts);
	
?>
<html>
<head>
<title>rtmarchive System</title>
</head>
<body>
<h1>rtmarchive System</h1>
<h6>Chris Vidler - Dynatrace DCRUM SME 2015</h6>

<h2>AMD Sources</h2>
<ul class="list">
<?php
	$basedir = scandir(BASEDIR);
	foreach ($basedir as $amd) {
		if (file_exists(BASEDIR.$amd."/prevdir.lst")) {
			echo " <li><a href=\"?link=".base64_encode("amd=".$amd)."\">";
			if ( $linkopts['amd'] == $amd ) { echo "<b>".$amd."</b>";} else { echo $amd; }
			echo "</a>\n";
			$years = scandir(BASEDIR.$amd);
			foreach ($years as $year) {
				if ( is_numeric($year) ) {
					echo "  <ul>\n";
					echo "   <li><a href=\"?link=".base64_encode("amd=".$amd."&year=".$year)."\">";
					if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year ) { echo "<b>".$year."</b>";} else { echo $year; }
					echo "</a>\n";
					echo "    <ul/>\n";
					$months = scandir(BASEDIR.$amd."/".$year);
					foreach ($months as $month) {
						if ( is_numeric($month) ) {
							echo "     <li><a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month)."\">";
							if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month) { 
								echo "<b>".date_format(date_create($year."-".$month."-01"),"M")."</b>";} 
							else { 
								echo date_format(date_create($year."-".$month."-01"),"M"); }
							echo "</a>\n";
							echo "      <ul>\n";
							$days = scandir(BASEDIR.$amd."/".$year."/".$month);
							foreach ($days as $day) {
								if ( is_numeric($day) && file_exists(BASEDIR.$amd."/".$year."/".$month."/".$day."/softwareservice.lst" ) ) {
									echo "       <li><a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day)."\">";
									if ( $linkopts['amd'] == $amd && $linkopts['year'] == $year && $linkopts['month'] == $month && $linkopts['day'] == $day) { 
										echo "<b>".$day."</b></a><br/>";
										if ( $linkopts['dataset'] == "ts") {
											echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts")."\"><b>Time Stamps</b></a></br>";
											echo getdaydata($amd, $year, $month, $day, "ts");
										} else {
                                                                                        echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ts")."\">Time Stamps</a></br>";
										}
										if ( $linkopts['dataset'] == "ss") {
                                                                                        echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss")."\"><b>Software Services</b></a></br>";
                                                                                        echo getdaydata($amd, $year, $month, $day, "ss");
                                                                                } else {
                                                                                        echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=ss")."\">Software Services</a></br>";
										} 
										if ( $linkopts['dataset'] == "sip") {
                                                                                        echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip")."\"><b>Server IP Addresses</b></a></br>";
                                                                                        echo getdaydata($amd, $year, $month, $day, "sip");
                                                                                } else {
											echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=sip")."\">Server IP Addresses</a></br>";

										} 
										if ( $linkopts['dataset'] == "cip") {
                                                                                        echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip")."\"><b>Client IP Addresses</b></a></br>";
                                                                                        echo getdaydata($amd, $year, $month, $day, "cip");
                                                                                } else {

	                                                                                echo "<a href=\"?link=".base64_encode("amd=".$amd."&year=".$year."&month=".$month."&day=".$day."&dataset=cip")."\">Client IP Addresses</a></br>";
										}
									} 
									else { 
										echo $day."</a></li>"; }
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


</body>
</html>

