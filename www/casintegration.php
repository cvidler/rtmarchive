<?php
// POC code to test SOAP integration with CAS.
// Chris Vidler 

// Config



// CV hard set some info for the POC.
define("ADDR","http://192.168.93.184");
define("SVC_PATH","/services/VantageManagerService");
define("USER", "adminuser");
define("PASS", "Password1");



// new SOAP object
$client = new SoapClient(ADDR.SVC_PATH."?wsdl",array('login' => USER, 'password' => PASS));
//var_dump($client->__getFunctions()); 
//var_dump($client->__getTypes()); 

$amds = $client->GetAMDs();
var_dump($amds);

// count AMDs returned.
echo "AMDs configured on CAS: ".count($amds->getAMDsReturn)."\n";

foreach ($amds->getAMDsReturn as $amd) {
	echo $amd->ipAddress;
	echo ":";
	echo $amd->port;
	echo " (";
	echo $amd->alias;
	echo ")";
	if ($amd->enabled == false){ echo " disabled"; }
	echo "\n";
}


?>


