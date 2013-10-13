#!/usr/bin/env sh
#
# GPG encrypted backups using tar for the-mesh.org hosts
#
# 13 Oct 2013 Sam Wilson <kahn@the-mesh.org>
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
# echo "!include /root/.my.cnf" >> /etc/my.cnf
# 4) Run via cron!
# 24 10 * * * root /root/backup.sh
 
date=`date +%F-%H`
# Specify a database name or -A for all (includes mysql table)
database="-A"
 
# Bash debugging
#set -x

# Backup databases
cd /root/
/usr/bin/mysqldump -u root $database > $date.sql
/bin/tar -cJf $date.sql.txz $date.sql
# Add a "-r your@email.address" for each key you want to encrypt to. Short or Long ID's should work too.
/usr/bin/gpg2 --homedir /root/.gnupg --batch --yes -a --passphrase-file /root/.backups.conf -r kahn@the-mesh.org --sign --encrypt --trust-model always $date.sql.txz
checksum="$(/usr/bin/sha512sum $date.sql*)"
# Copy the encrypted archive to temp so mail can get to it.
cp $date.sql.txz.asc /tmp/
chmod 0444 /tmp/$date.sql.txz.asc
# Cleanup files in the clear
rm $date.sql
rm $date.sql.txz
rm $date.sql.txz.asc
# Mail encrypted database to root user
#echo "$checksum" | mail -s "MySQL Backup: $database" -a /tmp/$date.sql.txz.asc root

# Backup system files and include database backup
time tar -cvJf /var/backup/charles.$date.txz / /tmp/$date.sql.txz.asc --exclude=/var/backup --exclude=/dev --exclude=/proc --exclude=/sys --exclude=/lost+found --exclude=/cgroup --exclude=/selinux --exclude=/tmp --exclude=/var/www/archive
# Encrypt tar content
/usr/bin/gpg2 --homedir /root/.gnupg --batch --yes -a --passphrase-file /root/.backups.conf -r kahn@the-mesh.org --sign --encrypt --trust-model always /var/backup/charles.$date.txz

# Offsite push - Update your details here for remote hosts
/usr/bin/rsync -avz -e ssh /var/backups/charles.$date.txz.asc offsite@rsync.net:

# Cleanup encrypted files
rm /tmp/$date.sql.txz.asc
rm /var/backup/charles.$date.txz
rm /var/backup/charles.$date.txz.asc
