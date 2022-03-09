set PRJDIR "[file dirname [info script]]"
source "$PRJDIR/../create-ebus-types.tcl"
set make_cmd "cd $PATH_REPO/picoblaze/psm && make"
puts [exec bash -c $make_cmd]
