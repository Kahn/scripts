#!/bin/bash

#records usage from the iptables counters and puts them into /var/lib/fair_use

DATA_DIR=/var/lib/fair_use
TIMESTAMP=`TZ=UTC date +%Y-%m-%d`

parse_bytes() {
	if [ "$1" == 0 ]; then
		echo 0
		return
	fi

	case "$1" in
		*K)
			multiplier="1024"
			;;
		*M)
			multiplier="1024*1024"
			;;
		*G)
			multiplier="1024*1024*1024"
			;;
		*)
			multiplier=1
			;;
	esac
	units=`echo "$1" | tr -c -d '[0-9]'`
	bytes=$[ $units * $multiplier ]
	echo "$bytes"
}

split_usage_output() {
	while read pkts bytes prot opt in out source destination; do
		[ "$prot" != "all" ] && continue
		real_bytes=`parse_bytes $bytes`
		echo "$TIMESTAMP $real_bytes" >>$DATA_DIR/${destination}.output
	done
}

split_usage_input() {
echo "split_usage_input called" >>/tmp/called
	while read pkts bytes prot opt in out source destination; do
		[ "$prot" != "all" ] && continue
		real_bytes=`parse_bytes $bytes`
		echo "$TIMESTAMP $real_bytes" >>$DATA_DIR/${source}.input
	done
}

/usr/sbin/iptables -vn -L -Z vlan61_input | split_usage_input
/usr/sbin/iptables -vn -L -Z vlan61_output | split_usage_output
