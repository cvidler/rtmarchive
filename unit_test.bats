#!/usr/local/bin/bats

##
## Setup
##
TMPDIR=
BASEDIR=
APACHECONF=
setup() {
  # create temproary directory structure
  TMPDIR="$(mktemp -d)"
  BASEDIR="$TMPDIR/base"
  mkdir -p "$BASEDIR"

  # create fake RUMC API output
  APACHECONF="/etc/httpd/conf.d/rtmarchivetestsuite.conf"
  echo -e "GOOD,http,127.0.0.1,80,adminuser,93b184697989337ae6904f43c3adf1c7\n" > "$TMPDIR/RUMCGOOD.cfg"
  echo -e "BADLOGIN,http,127.0.0.1,80,nouser,93b184697989337ae6904f43c3adf1c7\n" > "$TMPDIR/RUMCBADLOGIN.cfg"
  echo -e "BADRESP,http,127.0.0.1,81,adminuser,93b184697989337ae6904f43c3adf1c7\n" > "$TMPDIR/RUMCBADRESP.cfg"

}

teardown() {
  rm -rf "$TMPDIR"
}

##
## queryrumc.sh tests
##

@test "queryrumc.sh: test config files present" {
  [ -r $TMPDIR/RUMCGOOD.cfg ]
  [ -r $TMPDIR/RUMCBADLOGIN.cfg ]
  [ -r $TMPDIR/RUMCBADRESP.cfg ]
}

@test "queryrumc.sh: present" {
  [ -r ./queryrumc.sh ]
}

@test "queryrumc.sh: executable" {
  [ -x ./queryrumc.sh ]
}

@test "queryrumc.sh: help" {
  run ./queryrumc.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./queryrumc.sh [-h] [-u] [-a amdlist] [-c rumcconfig] [-e]" ] 
}

@test "queryrumc.sh: invalid parameter" {
  run ./queryrumc.sh -g
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** FATAL: Invalid argument -g." ]
  [ "${lines[1]}" == "*** INFO: Usage: ./queryrumc.sh [-h] [-u] [-a amdlist] [-c rumcconfig] [-e]" ] 
}

@test "queryrumc.sh: password encoding, matching passwords, known hash" {
  run ./queryrumc.sh -e < <(echo -e "TestPassword1\nTestPassword1")
  [ $status -eq 0 ]
  echo $output
  len=${#output}
  output=${output:$len-32}
  echo [$output]
  [ "${output}" == "93b184697989337ae6904f43c3adf1c7" ]
}

@test "queryrumc.sh: password encoding, mismatched passwords" {
  run ./queryrumc.sh -e < <(echo -e "TestPassword1\nTestPassword2")
  [ $status -eq 1 ]
  echo $output
  len=${#output}
  output=${output:$len-32}
  [ "$output" == "Passwords don't match, aborting." ]
}

@test "queryrumc.sh: password decoding, known hash" {
  run ./queryrumc.sh -z 93b184697989337ae6904f43c3adf1c7
  [ $status -eq 0 ]
  len=${#output}
  output=${output:$len-15}
  [ "$output" == "[TestPassword1]" ]
}

@test "queryrumc.sh: RUMC API testing, Valid test" {
  skip "test not yet working"
  # create required apache config and fake response files
  sudo echo -e "# temporary apache config for BATS test suite of rtmarchive system\n<Directory """$TMPDIR""s">\n  AuthType Basic\n  AuthName ""AuthenticationRequired""\n  AuthUserFile ""$TMPDIR""/.htpasswd""\n  Require valid-user\n</Directory>\n\nAlias /cxf/rest/backup $TMPDIR/RUMCGOOD.xml\nAlias /RtmDataServlet $TMPDIR/VERRESP.txt" > "$APACHECONF"
  #echo -e 'AuthType Basic\nAuthName "Authentication Required"\nAuthUserFile "'"$TMPDIR"'/.htpasswd"\nRequire valid-user\n' > "$TMPDIR/.htaccess"
  `htpasswd -c -b $TMPDIR/.htpasswd adminuser TestPassword1`
  echo -e "RtmDummyResponse 1.0.0\n" > "$TMPDIR/VERRESP.txt"
  echo -e '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><backup><devices><id>10</id><name>CAS</name><type>10</type><version>18.0.0.592</version><os>-</os><created>1496121311523</created><parameters><entries key="IS_HTTPS" value="false"/><entries key="PORT" value="80"/><entries key="LICENSING" value="V1"/><entries key="SERVER_UUID" value="b3b25761-195a-4a89-bf35-2c5e629a321c"/><entries key="IP" value="127.0.0.1"/><entries key="SERVER_ROLE" value="STANDALONE"/><entries key="USE_CSS_AUTH" value="true"/></parameters></devices><devices><id>17</id><name></name><type>0</type><version>17.0.3.112</version><os>CentOS Linux release 7.4.1708 (Core) </os><created>1519270710157</created><parameters><entries key="DEVICE_MODE" value="HS"/><entries key="IS_HTTPS" value="true"/><entries key="PASSWORD" value="3d1ba9e048daedb2d378202e51affbb4"/><entries key="PORT" value="443"/><entries key="LICENSING" value="V1"/><entries key="IP" value="192.168.93.132"/><entries key="AMD_UUID" value="3104477010"/><entries key="USER" value="adlex"/></parameters></devices><importPlainTextPasswords>false</importPlainTextPasswords></backup>' > "$TMPDIR/RUMCGOOD.xml"
  # reload apache config
  sudo apachectl graceful

  run ./queryrumc.sh -c "$TMPDIR/RUMCGOOD.cfg"
  echo -e $output
  [ $status -eq 1 ]

  # remove apache config
  rm -f "$APACHECONF"
  sudo apachectl graceful
}



##
## rtmarchive.sh tests
##

@test "rtmarchive.sh: config file amdlist.cfg present" {
  [ -r /etc/amdlist.cfg ]
}

@test "rtmarchive.sh: present" {
  [ -r ./rtmarchive.sh ]
}

@test "rtmarchive.sh: executable" {
  [ -x ./rtmarchive.sh ]
}

@test "rtmarchive.sh: help" {
  run ./rtmarchive.sh -h
  [ $status -eq 0 ]
  [ "${lines[1]}" == "*** INFO: Usage: ./rtmarchive.sh [-h] [-a amdlist] [-b basearchivedir]" ] 
}

@test "rtmarchive.sh: invalid parameter" {
  run ./rtmarchive.sh -g
  [ $status -eq 0 ]
  len=${#lines[1]}
  result=${lines[1]:$len-31}
  [ "${result}" == "*** FATAL: Invalid argument -g." ]
}



##
## archiveamd.sh tests
##

@test "archiveamd.sh: present" {
  [ -r ./rtmarchive.sh ]
}

@test "archiveamd.sh: executable" {
  [ -x ./archiveamd.sh ]
}

@test "archiveamd.sh: help" {
  run ./archiveamd.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./archiveamd.sh [-h] [-s] -n amdname -u amdurl -b basearchivedir" ] 
}

@test "archiveamd.sh: invalid parameter" {
  run ./archiveamd.sh -g
  [ $status -eq 0 ]
  len=${#lines[0]}
  result=${lines[0]:$len-31}
  [ "${result}" == "*** FATAL: Invalid argument -g." ]
}



##
## spaceman.sh tests
##

@test "spaceman.sh: present" {
  [ -r ./spaceman.sh ]
}

@test "spaceman.sh: executable" {
  [ -x ./spaceman.sh ]
}

@test "spaceman.sh: help" {
  run ./spaceman.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./spaceman.sh [-h] [-d]" ] 
}

@test "spaceman.sh: invalid parameter" {
  run ./spaceman.sh -g
  [ $status -eq 0 ]
  len=${#lines[0]}
  result=${lines[0]:$len-31}
  [ "${result}" == "*** FATAL: Invalid argument -g." ]
}



##
## archivemgmt.sh tests
##

@test "archivemgmt.sh: present" {
  [ -r ./archivemgmt.sh ]
}

@test "archivemgmt.sh: executable" {
  [ -x ./archivemgmt.sh ]
}

@test "archivemgmt.sh: help" {
  run ./archivemgmt.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./archivemgmt.sh [-h] [-b basearchivedir] [-u yyyy-mm-dd -a amdname] [-f]" ] 
}

@test "archivemgmt.sh: invalid parameter" {
  run ./archivemgmt.sh -g
  [ $status -eq 0 ]
  len=${#lines[0]}
  result=${lines[0]: -20}
  [ "${result}" == "Invalid argument -g." ]
}



##
## archivemgmtindex.sh tests
##

@test "archivemgmtindex.sh: present" {
  [ -r ./archivemgmtindex.sh ]
}

@test "archivemgmtindex.sh: executable" {
  [ -x ./archivemgmtindex.sh ]
}

@test "archivemgmtindex.sh: help" {
  run ./archivemgmtindex.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./archivemgmtindex.sh [-h] [-f] [-b basearchivedir]" ] 
}

@test "archivemgmtindex.sh: invalid parameter" {
  run ./archivemgmtindex.sh -g
  [ $status -eq 0 ]
  len=${#lines[0]}
  result=${lines[0]:$len-31}
  [ "${result}" == "*** FATAL: Invalid argument -g." ]
}



##
## amd_diag.sh tests
##

@test "amd_diag.sh: present" {
  [ -r ./amd_diag.sh ]
}

@test "amd_diag.sh: executable" {
  [ -x ./amd_diag.sh ]
}

@test "amd_diag.sh: help" {
  run ./amd_diag.sh -h
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./amd_diag.sh [-h] [-b basearchivedir] -a amdname" ] 
}

@test "amd_diag.sh: invalid parameter" {
  run ./amd_diag.sh -g
  [ $status -eq 0 ]
  len=${#lines[0]}
  result=${lines[0]:$len-31}
  [ "${result}" == "*** FATAL: Invalid argument -g." ]
}



##
## apache config
##

@test "0_rtmarchive.conf: Apache config present" {
  [ -r www/0_rtmarchive.conf ]
}



##
## vamd.php
##

@test "vamd.php: present" {
  [ -r www/vamd.php ]
}

@test "vamd.php: compiles" {
  run php www/vamd.php
  [ $status -eq 0 ]
}

@test "vamd.php: version" {
  run php-cgi -f www/vamd.php cmd=version
  [ $status -eq 0 ]
  [ "$output" == "Not authorized" ]
}



##
## search.php
##

@test "search.php: present" {
  [ -r www/search.php ]
}

@test "search.php: compiles" {
  run php www/search.php
  [ $status -eq 0 ]
}

@test "search.php: test search" {
  run php-cgi -f www/search.php searchtxt=version
  [ $status -eq 0 ]
  [[ "$output" =~ "<title>rtmarchive Search - version</title>" ]]
}



##
## index.php
##

@test "index.php: present" {
  [ -r www/index.php ]
}

@test "index.php: compiles" {
  run php www/index.php
  [ $status -eq 0 ]
}

@test "index.php: page title" {
  run php-cgi -f www/index.php
  [ $status -eq 0 ]
  [[ "$output" =~ "<title>rtmarchive System</title>" ]]
}



