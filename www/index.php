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
	foreach ($basedir as $dir) {
		if (file_exists(BASEDIR.$dir."/prevdir.lst")) {
			echo "<li>".$dir."</ul>\n";
		}
	}
?>
</ul>


</body>
</html>

