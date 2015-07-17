#!/usr/bin/env bash

# A traffic shaping script to manage clients fair use of limited
# monthly bandwidth common with Australian Internet Service Providers
# Copyright (C) 2015  Sam Wilson
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -x
set -e
set -o pipefail

SCRIPT_NAME="OpenWRT-TrafficShaper"

# Interface device to rate limit
WAN_DEVICE=eth0
LAN_DEVICE=br-lan
# First three octets of your LAN subnet
LAN_PREFIX=192.168.88

# Clients are demoted from TC01 through to TC06 based on quotas
TC01_BANDWIDTH=4096kbit
TC02_BANDWIDTH=2048kbit
TC03_BANDWIDTH=1024kbit
TC04_BANDWIDTH=512kbit
TC05_BANDWIDTH=256kbit
TC06_BANDWIDTH=128kbit

# Quota for the iptables quota2 module in bytes
# 64MB
TC01_QUOTA=64000000
# 128MB
TC02_QUOTA=128000000
# 256MB
TC03_QUOTA=256000000
# 512MB
TC04_QUOTA=512000000
# 1GB
TC05_QUOTA=1024000000
# TC06 catches all clients exceeding $TC05_QUOTA

# Reload firewall to clear previous quotas
/etc/init.d/firewall restart || logger "ERROR: $SCRIPT_NAME Failed to restart firewall"

# Create traffic classes
# Use parent 2: to avoid trampling qos-scripts qdiscs
tc qdisc del dev $LAN_DEVICE root || logger "WARNING: Failed to remove existing tc root"
tc qdisc add dev $LAN_DEVICE root handle 2: htb default 1 || logger "ERROR: Failed to apply tc root"
tc class add dev $LAN_DEVICE parent 2: classid 2:1 htb rate $TC01_BANDWIDTH ceil $TC01_BANDWIDTH prio 0 burst 500k cburst 500k || logger "ERROR: Failed to apply tc leaf"
tc class add dev $LAN_DEVICE parent 2: classid 2:2 htb rate $TC02_BANDWIDTH ceil $TC02_BANDWIDTH prio 0 burst 500k cburst 500k
tc class add dev $LAN_DEVICE parent 2: classid 2:3 htb rate $TC03_BANDWIDTH ceil $TC03_BANDWIDTH prio 0 burst 500k cburst 500k
tc class add dev $LAN_DEVICE parent 2: classid 2:4 htb rate $TC04_BANDWIDTH ceil $TC04_BANDWIDTH prio 0 burst 500k cburst 500k
tc class add dev $LAN_DEVICE parent 2: classid 2:5 htb rate $TC05_BANDWIDTH ceil $TC05_BANDWIDTH prio 0 burst 500k cburst 500k
tc class add dev $LAN_DEVICE parent 2: classid 2:6 htb rate $TC06_BANDWIDTH ceil $TC06_BANDWIDTH prio 0 burst 500k cburst 500k
logger "INFO: Added traffic shaping policies on dev $LAN_DEVICE"

# Assign traffic classes
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 1 fw flowid 2:1
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 2 fw flowid 2:2
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 3 fw flowid 2:3
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 4 fw flowid 2:4
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 5 fw flowid 2:5
tc filter add dev $LAN_DEVICE parent 2: prio 0 protocol ip handle 6 fw flowid 2:6
logger "INFO: Assigned traffic classes on dev $LAN_DEVICE"

# Apply firewall marks to each IP in the local lan
# Assumes all LANs are /24
logger "DEBUG: Started apply firewall rules"
# Skip .1 since we don't want to affect ourselves
ip=2
while [ $ip -le 255 ];
do
# Logically ordered back to front here as each "faster" class rewrites the
# "default" mark until your in TC01. The quota2 module will no longer match
# packets once the quota is exceeded which "fails through" to the next traffic
# class
iptables -t mangle -A POSTROUTING -d $LAN_PREFIX.$ip -j MARK --set-mark 6
iptables -t mangle -A POSTROUTING -m quota2 --name tc-05-$ip --quota $TC05_QUOTA -d $LAN_PREFIX.$ip -j MARK --set-mark 5
iptables -t mangle -A POSTROUTING -m quota2 --name tc-04-$ip --quota $TC04_QUOTA -d $LAN_PREFIX.$ip -j MARK --set-mark 4
iptables -t mangle -A POSTROUTING -m quota2 --name tc-03-$ip --quota $TC03_QUOTA -d $LAN_PREFIX.$ip -j MARK --set-mark 3
iptables -t mangle -A POSTROUTING -m quota2 --name tc-02-$ip --quota $TC02_QUOTA -d $LAN_PREFIX.$ip -j MARK --set-mark 2
iptables -t mangle -A POSTROUTING -m quota2 --name tc-01-$ip --quota $TC01_QUOTA -d $LAN_PREFIX.$ip -j MARK --set-mark 1
ip=$[ $ip + 1 ]
done

logger "DEBUG: Completed apply firewall rules"
logger "INFO: $SCRIPT_NAME completed"
exit 0
