backups
=======

Intial Setup

 1) As root create a new keypair
  $ gpg2 --gen-key
 2) Use RSA and RSA key types
 3) Use keylength 2048 or greater
 4) Specify 2y for key expiration
 5) Specify real name as your hosts fqdn
 6) Specify email as hostname@domain
 7) Specify comment as offsite backups

Usage

 1) Make sure your MySQL creds exist in /root/.my.cnf and chmod 0600
 ```
 [mysqldump]
 user = username
 password = password
 ```
 2) Make sure your GPG passphrase is on the first line in /root/.backups.conf and chmod 0400
 ```
 password
 ```
 3) Include your MySQL credentials in the global MySQL config /etc/my.cnf
 ```
 !include /root/.my.cnf
 ```
 4) Run via cron
 24 10 * * * root /root/backup.sh
