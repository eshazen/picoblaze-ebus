set PATH_REPO "[file normalize [file dirname [info script]]]/../"

#https://www.xilinx.com/support/answers/72570.html
set PYTHONPATH $::env(PYTHONPATH)
set PYTHONHOME $::env(PYTHONHOME)
set PATH $::env(PATH)
unset env(PYTHONPATH)
unset env(PYTHONHOME)
unset env(PATH)
set env(PATH) "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

set make_cmd "cd $PATH_REPO/picoblaze/src && make"
puts [exec bash -c $make_cmd]

set env(PYTHONPATH) $PYTHONPATH
set env(PYTHONHOME) $PYTHONHOME
set env(PATH) $PATH
