#!/bin/bash
#
# Created by Sebastian Grewe, Jammicron Technology - http://exchange.nagios.org/directory/Plugins/Operating-Systems/Linux/check_md_raid/details
#
# Extended to support local checking for a QNAP device - kahn@the-mesh.org

# Add email support - http://forum.qnap.com/viewtopic.php?t=18350#p81429
# First update /mnt/HDA_ROOT/.config/ssmtp/ssmtp.conf with a real hostname
#
# hostname=example.org
send_mail()
#   Send a mail message
#   $1 = subject
#   $2 = to
#   $3 = from
#   $4 = msg
{
   local tmpfile="/tmp/sendmail.tmp"
   /bin/echo -e "Subject: $1\r" > "$tmpfile"
   #/bin/echo -e "To: $2\r" >> "$tmpfile"
   #/bin/echo -e "From: $3\r" >> "$tmpfile"
   /bin/echo -e "\r" >> "$tmpfile"
   if [ -f "$4" ]; then
      cat "$4" >> "$tmpfile"
      /bin/echo -e "\r\n" >> "$tmpfile"
   else
      /bin/echo -e "$4\r\n" >> "$tmpfile"
   fi
   #/usr/sbin/sendmail -t < "$tmpfile"
   ssmtp $2 < "$tmpfile"
   rm $tmpfile
}

# Get count of raid arrays
RAID_DEVICES=`grep ^md -c /proc/mdstat`

# Get count of degraded arrays
#RAID_STATUS=`grep "\[.*_.*\]" /proc/mdstat -c`
RAID_STATUS=`egrep "\[.*(=|>|\.).*\]" /proc/mdstat -c`

# Is an array currently recovering, get percentage of recovery
RAID_RECOVER=`grep recovery /proc/mdstat | awk '{print $4}'`
RAID_RESYNC=`grep resync /proc/mdstat | awk '{print $4}'`

# Check raid status
# RAID recovers --> Warning
if [[ $RAID_RECOVER ]]; then
	STATUS="WARNING - Checked $RAID_DEVICES arrays, recovering : $RAID_RECOVER"
	EXIT=1
elif [[ $RAID_RESYNC ]]; then
	STATUS="WARNING - Checked $RAID_DEVICES arrays, resync : $RAID_RESYNC"
	EXIT=1
	# RAID ok
elif [[ $RAID_STATUS == "0" ]]; then
	STATUS="OK - Checked $RAID_DEVICES arrays."
	EXIT=0
	# All else critical, better save than sorry
else
	EXTEND_RAID_STATUS=`egrep "\[.*(=|>|\.|_).*\]" /proc/mdstat | awk '{print $2}' | uniq -c | xargs echo`
	STATUS="WARNING- Checked $RAID_DEVICES arrays, $RAID_STATUS have failed check: $EXTEND_RAID_STATUS "
	EXIT=1
fi

# Status and quit
if [[ $EXIT != 0 ]]; then
echo $STATUS
send_mail 'RAID ERROR' 'admin@example.org' 'qnap@example.org' $STATUS
fi

exit $EXIT
