#!/usr/bin/env sh
#
# tunnel.sh - version 1.0.0
# Provides a "best efforts" reverse SSH tunnel that can be managed via cronjob
# 20130908 Sam Wilson kahn@the-mesh.org
#
# Usage:
# /etc/crontab
# */1 * * * * root /root/tunnel.sh > /dev/null 2>&1
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Tunnel Setup
SSHKEY="/path/to/your/.ssh/id_rsa"
SSHUSER="ssh-user"
SSHHOST="127.0.0.1"
REMOTEPORT="22"
LOCALPORT="22"

createTunnel() {
  /bin/ssh -f -i $SSHKEY $SSHUSER@$SSHHOST -R $REMOTEPORT:127.0.0.1:$LOCALPORT -N
}
/sbin/pidof ssh > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  createTunnel
fi
