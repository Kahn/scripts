#!/bin/bash
### BEGIN INIT INFO
# Provides:          mm_monitor_d
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Daemon script activatin wwan when needed
# Description:       This script start the modem manager monitor working
#                    around bug 848164 
# See https://bugs.launchpad.net/ubuntu/+source/network-manager/+bug/848164
#
# Source at https://launchpadlibrarian.net/122190131/mm_monitor
### END INIT INFO

# Author: Leo 'TheHobbit' Cacciari <leothehobbit@gmail.com>
#
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin
DESC="Workaround for bug #848164"
NAME=mm_monitor
SCRIPT=/etc/init.d/$NAME
## using this means that the script must be run as root 
RUNDIR=/var/run



### Log related functions
LOGGER=/usr/bin/logger
LOG_FACILITY=daemon
_log_message() {
  local level=$1
  shift
  $LOGGER -p "$LOG_FACILITY.$level" -t "$NAME ($$)" "$*"
}

log_message() {
  _log_message info "$@"
}

log_debug() {
  _log_message debug "DEBUG $@"
}


log_warning() {
 _log_message warning "WARNING $@"
}

log_error() {
 _log_message error "ERROR $@"
}

log_fatal() {
 local rc=$1
 shift
 _log_message crit "FATAL $@"
 exit "$rc"
}
#####################################

#### Daemon related variables and functions
PIDFILE=$RUNDIR/$NAME.pid
KILLFILE=$RUNDIR/$NAME.kill

create_pidfile() {
  echo $$ > $PIDFILE
}

remove_pidfile() {
  rm -f $PIDFILE
}

daemonize() {
  local outfile=${1-}
  local errfile=${2-}
  [ -z "$errfile" ] && [ -n "$outfile" ] && errfile=$outfile
  exec 3>&-
  if [ -z "$outfile" ]; then
    exec 1>&-
  else
    exec 1>>$outfile
  fi
  if [ -z "$errfile" ]; then
    exec 2>&-
  else
    exec 2>>$errfile
  fi
}

checkterm() {
  [ -f $KILLFILE ] || return 0
  rm $KILLFILE
  return 1
}

###### Network Manager action
NMCLI=/usr/bin/nmcli
LC_ALL=C

check_wwan() {
  local status=$($NMCLI -t -f WWAN nm wwan)
  [ $status = enabled ] || return 1
  return 0
}

activate_wwan() {
 log_debug "calling '$NMCLI nm wwan on'"
 $NMCLI nm wwan on > /dev/null 2>&1
 if [ $rc -ne 0 ]; then
      log_error "activation of wwan failed"
 elif ! check_wwan; then
      log_warning "activation sucesfull but still not enabled"
 else
      log_message "activated" 
 fi
}


###################################################
## main function
INTERFACE=org.freedesktop.ModemManager
SIGNAL=DeviceAdded

DBUS_MONITOR=/usr/bin/dbus-monitor
PIPE=$RUNDIR/$NAME.fifo
SUB_PID=

start_subprocess() {
 rm -f $PIPE
 mkfifo $PIPE
 $DBUS_MONITOR --system --profile "type='signal',interface='$INTERFACE',member='$SIGNAL'" > $PIPE &
#  tail -n0 -f /tmp/porcodio > $PIPE &
 SUB_PID=$!
 log_message "subprocess $SUB_PID writing on $PIPE"
} 

stop_subprocess() {
 log_message "stopping subprocess $SUB_PID"
 kill $SUB_PID
 rm -f $PIPE
}

do_it() {
 log_message "do_it function called"
 start_subprocess
 while checkterm; do
    read -t 1 line || continue
    log_debug "got $line"
    echo $line | grep -q $SIGNAL
    [ $? -eq 0 ] || continue 
    if check_wwan; then
      log_debug "wwan already active"
    else
      log_message "calling activate_wan"
      activate_wwan
    fi
 done < $PIPE
 stop_subprocess
 log_message "do_it terminated"
}



######## Handle parameters
action=${1-help}
param=${2-}

log_message "called $0 $action $param"
case "$action" in
 status)
   if [ ! -f $PIDFILE ]; then
     echo "$NAME not running"
     exit 1
   else 
     test_pid=$(cat $PIDFILE)
     ps $test_pid > /dev/null 2>&1
     if [ $? -eq 0 ]; then
       echo "$NAME is running"
       exit 0
     else
       echo "$NAME not running"
       remove_pidfile
       exit 1
     fi
   fi
   ;;
 start)
   log_message "starting daemon"
   $0 run $param &
   log_message "started"
   ;;
 stop)
  log_message "stopping daeemon"
  $0 status > /dev/null 2>&1
  if [ $? -eq 1 ]; then
    log_message "not running"
    exit 0
  fi
  touch $KILLFILE
  ;;
 restart)
  $0 stop 
  $0 start $param
  ;;
 help)
  echo "Usage: $SCRIPT  [ start | stop | restart | stat | help ] [dry-run|n|no]"
  ;;
 run)
   arg=
   case "$param" in
     dry-run | n | no)
       arg=yes
       ;;
   esac
   daemonize
   create_pidfile
   do_it $arg
   remove_pidfile
   ;;
esac

:
