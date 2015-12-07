<?php
	define("BASEDIR", "/var/spool/rtmarchive/");


	if ( is_dir(BASEDIR) ) {} else {
		echo "***FATAL: ".BASEDIR." does not exist.\n";
	}
?>
<html>
<head>
<title>rtmarchive System</title>
</head>
<body>
<h1>rtmarchive System</h1>
<p>Chris Vidler - Dynatrace DCRUM SME 2015</p>

<h2>AMD Sources</h2>
<ul>
<?php
	$basedir = scandir(BASEDIR);
	foreach ($basedir as $amd) {
		if (file_exists(BASEDIR.$amd."/prevdir.lst")) {
			echo "<li><a href=\"?amd=".$amd."\">".$amd."</a>\n";
			$years = scandir(BASEDIR.$amd);
			echo "<ul>\n";
			foreach ($years as $year) {
				if ( is_numeric($year) ) {
					echo "<li><a href=\"?amd=".$amd."&year=".$year.">".$year."</a>\n";
					echo "<br>\n";
					$months = scandir(BASEDIR.$amd."/".$year);
					foreach ($months as $month) {
						if ( is_numeric($month) ) {
							echo "a href=\"?amd=".$amd."&year=".$year."&month=".$month."\">".date_format(date_create($year."-".$month."-01"),"M")."</a> ";
						}
					}
					echo "</li>\n";
				}
			}
			echo "</ul>\n";
			echo "</ul>\n";
		}
	}
?>
</ul>


</body>
</html>

