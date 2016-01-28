#!/bin/bash

rm sepolicy.mod sepolicy.pp
checkmodule -M -m -o sepolicy.mod sepolicy.te
semodule_package -o sepolicy.pp -m sepolicy.mod
semodule -i sepolicy.pp
