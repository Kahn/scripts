#!/usr/bin/env sh
#
# GPG encrypted backups using tar for the-mesh.org hosts
#
# 15 Oct 2013 Sam Wilson <kahn@the-mesh.org>
#
# Setup
# 1) As root create a new keypair
#  $ gpg2 --gen-key
# 2) Use RSA and RSA key types
# 3) Use keylength 2048 or greater
# 4) Specify 2y for key expiration
# 5) Specify real name as your hosts fqdn
# 6) Specify email as hostname@domain
# 7) Specify comment as offsite backups
#
# Usage
# 1) Make sure your MySQL creds exist in /root/.my.cnf and chmod 0600
# [mysqldump]
# user = username
# password = password
# 2) Make sure your GPG passphrase is on the first line in /root/.backups.conf and chmod 0400
# password
# 3) Include your MySQL credentials in the global MySQL config
# echo "\!include /root/.my.cnf" >> /etc/my.cnf
# 4) Run via cron! Take note on how long a one shot job takes to complete to set no overlapping windows!
# 59 11 * * * root /root/backup.sh daily
# 59 13 * * 2 root /root/backup.sh weekly
# 59 15 15 * * root /root/backup.sh monthly

# Config
backupdir=~
remotedir=`hostname --short`
backuphost='offsite@rsync.net'
backupkey='-i /root/.ssh/id_rsa'
# Specify a database name or -A for all (includes mysql table)
database="-A"
# Retention in days. You do the math
daily=7
weekly=30
monthly=90
# Get todays date
date=`date +%s`
# Debug
set -x

# Backup function
function backup {
        # Backup databases
        /usr/bin/mysqldump -u root $database > /var/backup/$date.sql
        /bin/tar -cJf /var/backup/$date.sql.txz /var/backup/$date.sql
        # Add a "-r your@email.address" for each key you want to encrypt to. Short or Long ID's should work too.
        /usr/bin/gpg2 --homedir /root/.gnupg --batch --yes -a --passphrase-file /root/.backups.conf -r kahn@the-mesh.org --sign --encrypt --trust-model always /var/backup/$date.sql.txz
        checksum="$(/usr/bin/sha512sum /var/backup/$date.sql*)"
        # Cleanup files in the clear
        rm /var/backup/$date.sql
        rm /var/backup/$date.sql.txz
        # Mail encrypted database to root user
        #echo "$checksum" | mail -s "MySQL Backup: $database" -a /var/backup/$date.sql.txz.asc root

        # Backup system files and include database backup
        time tar -cvJf /var/backup/charles.$date.txz / /var/backup/$date.sql.txz.asc --exclude=/var/backup --exclude=/dev --exclude=/proc --exclude=/sys --exclude=/lost+found --exclude=/cgroup --exclude=/selinux --exclude=/tmp --exclude=/var/www/archive
        # Encrypt tar content
        /usr/bin/gpg2 --homedir /root/.gnupg --batch --yes -a --passphrase-file /root/.backups.conf -r kahn@the-mesh.org --sign --encrypt --trust-model always /var/backup/charles.$date.txz
}

case $1 in
daily)
# Rotate dailys
ssh $backuphost $backupkey -C mkdir -v -p $remotedir/daily
expiredDaily=`ssh $backuphost $backupkey -C find $remotedir/daily -type f -ctime $daily`
for i in $expiredDaily; do
echo 'Expired file' $i
ssh $backuphost $backupkey -C rm -v $remotedir/daily/$i
done
# Call backup
backup
rsync -avz --log-file=/var/log/rsync.log -e ssh /var/backup/charles.$date.txz.asc $backuphost:$remotedir/daily/
;;
weekly)
# Rotate weeklys
ssh $backuphost $backupkey -C mkdir -v -p $remotedir/weekly
expiredWeekly=`ssh $backuphost $backupkey -C find $remotedir/weekly -type f -ctime $weekly`
for i in $expiredWeekly; do
echo 'Expired file' $i
ssh $backuphost $backupkey -C rm -v $remotedir/weekly/$i
done
# Call backup
backup
rsync -avz --log-file=/var/log/rsync.log -e ssh /var/backup/charles.$date.txz.asc $backuphost:$remotedir/weekly/
;;
monthly)
# Rotate monthlys
ssh $backuphost $backupkey -C mkdir -v -p $remotedir/monthly
expiredMonthly=`ssh $backuphost $backupkey -C find $remotedir/monthly -type f -ctime $monthly`
for i in $expiredMonthly; do
echo 'Expired file' $i
ssh $backuphost $backupkey -C rm -v $remotedir/monthly/$i
done
# Call backup
backup
rsync -avz --log-file=/var/log/rsync.log -e ssh /var/backup/charles.$date.txz.asc $backuphost:$remotedir/monthly/
;;
*)
echo "Notice: Script has been called without a time, not rotating backups"
backup
rsync -avz --log-file=/var/log/rsync.log -e ssh /var/backup/charles.$date.txz.asc $backuphost:$remotedir/
;;
esac

# Cleanup encrypted files
rm /var/backup/$date.sql.txz.asc
rm /var/backup/charles.$date.txz
rm /var/backup/charles.$date.txz.asc