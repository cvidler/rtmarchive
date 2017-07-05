<?php
// POC code to test SOAP integration with CAS.
// Chris Vidler 

// Config



// CV hard set some info for the POC.
define("ADDR","http://192.168.93.184");
define("SVC_PATH","/services/VantageManagerService");
define("USER", "adminuser");
define("PASS", "Password1");


class setamds {
	public $probes;
}

class probedata {
	function probedata($alias = NULL, $enabled = true, $ipAddress = NULL, $params = "rtm", $port = 443, $priority = false, 
						$row_id = 0, $secAddrType = 0, $secIpAddress = NULL, $secPort = 0, $secUserName = NULL, 
						$secUserPswd = NULL, $state = 73, $type = 0, $userName = NULL, $userPswd = NULL, $version = 0) {
		$this->alias = $alias;
		$this->enabled = $enabled;
		$this->ipAddress = $ipAddress;
		$this->params = $params;
		$this->port = $port;
		$this->priority = $priority;
		$this->row_id = $row_id;
		$this->secAddrType = $secAddrType;
		$this->secIpAddress = $secIpAddress;
		$this->secPort = $secPort;
		$this->secUserName = $secUserName;
		$this->secUserPswd = $secUserPswd;
		$this->state = $state;
		$this->type = $type;
		$this->userName = $userName;
		$this->userPswd = $userPswd;
		$this->version = $version;
	}
}


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

$testdata = new setamds;
$testdata->probes[] = new probedata("test",true,"10.1.1.1","rtm",9091,false,0,0,NULL,0,NULL,NULL,73,0,"user1","pass1");
$testdata->probes[] = new probedata("test2",true,"10.2.2.2");

var_dump($testdata);

$response = $client->SetAMDs($testdata);
var_dump($response);

?>


