#!/bin/bash

#    Provides a basic DNS to IP firewall updater for dynamic DNS.
#    Copyright (C) 2015 Sam Wilson
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Usage:
# Create a iptables template from your existing rules
# iptables-save >> /etc/sysconfig/iptables.template
#
# Change your static IP to a dynamic placeholder
# sed -i 's/your.static.ip.address/__DNS__/g' /etc/sysconfig/iptables.template
#
# Install a cron entry
# */1 * * * * ~/ddns-firewall.sh your.ddns.gtld ip.of.name.server 2>&1 | /usr/bin/logger -t ddns-firewall.sh

set -uex
set -o pipefail

DNS=$1
IP=`/usr/bin/dig +short @$2 $DNS`
echo "Resolved $DNS to $IP"

if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  cp -vf /etc/firewalld/zones/public.xml.template /etc/firewalld/zones/public.xml
  sed -i 's/__DNS__/'$IP'/g' /etc/firewalld/zones/public.xml
  service firewalld reload
  exit 0
else
  echo "Failed to resolve DNS"
  exit 1
fi
