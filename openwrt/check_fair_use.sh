#!/bin/bash
#checks for fair usage limits

DATA_DIR=/var/lib/fair_use
IP_START=2
#IP_START=180

count_usage_in_file() {
	FILENAME="$1"
	DAYS="$2"
	if [ ! -r "$FILENAME" ]; then
		echo "0"
		return
	fi
	counters=`tail -n $DAYS <$FILENAME | cut -d ' ' -f2 |tr '\012' ' ' |sed -e 's/ $//g'`
	bc_expr=`echo "$counters" |tr ' ' '+'`
	sum=`echo "$bc_expr" |bc -q`
	echo $sum
}


count_total_octets() {
	IP="$1"
	DAYS="$2"
	output_usage_file=$DATA_DIR/$IP.output
	input_usage_file=$DATA_DIR/$IP.input
	
	output_octets=`count_usage_in_file $output_usage_file $DAYS`
	input_octets=`count_usage_in_file $input_usage_file $DAYS`
	total_octets=$[ $output_octets + $input_octets ]
	echo "$total_octets"
}


#determine bandwidth class from usage
#input: ip (10.0.61.xxx)
#output: tier1/tier2/tier3/tier4
determine_ip_tier() {
	IP="$1"
	month_bytes=`count_total_octets $IP 30`
	if [ $month_bytes -ne 0 ]; then
		week_bytes=`count_total_octets $IP 7`
	else
		week_bytes=0
	fi
	
	#echo "$IP: month=$month_bytes week=$week_bytes" >&2
	if [ "$month_bytes" -eq 0 ]; then
		echo "tier1"
		return
	fi
	
	if [ "$month_bytes" -lt 20000000000 ]; then
		#tier 1 unless >=7GB this week
		if [ "$week_bytes" -le 7000000000 ]; then
			echo "tier1"
		else
			echo "tier2"
		fi
	elif [ "$month_bytes" -lt 40000000000 ]; then
		echo "tier2"
	elif [ "$month_bytes" -lt 50000000000 ]; then
		echo "tier3"
	elif [ "$month_bytes" -lt 60000000000 ]; then
		echo "tier4"
	elif [ "$month_bytes" -lt 80000000000 ]; then
		echo "tier5"
	else
		echo "tier6"
	fi
}


#check usage and output desired output speed
process_ip() {
	IP="$1"
	tier=`determine_ip_tier $IP`
	case "$tier" in
		tier1) #full speed
			output_speed=100mbit
			input_speed=100mbit
			;;
		tier2) #10Mbps/1Mbps
			output_speed=10mbit
			input_speed=1mbit
			;;
		tier3) #5Mbps/512Kbps
			output_speed=5mbit
			input_speed=512kbit
			;;
		tier4) #5Mbps/512Kbps
			output_speed=3mbit
			input_speed=384kbit
			;;
		tier5) #2MBps/128Kbps
			output_speed=2mbit
			input_speed=256kbit
			;;
		tier6) #1MBps/128Kbps
			output_speed=1mbit
			input_speed=128kbit
			;;
		*)
			return
	esac
	echo "$output_speed"
}


generate_tc_script() {
	echo "tc qdisc del dev vlan61 root handle 1:0"
	echo "tc qdisc add dev vlan61 root handle 1:0 htb default 500"
	echo "tc class add dev vlan61 parent 1:0 classid 1:1 htb rate 100mbit burst 500k cburst 500k"
	echo " tc class add dev vlan61 parent 1:1 classid 1:500 htb rate  384kbit ceil 100mbit burst 500k cburst 500k"
	ip4=$IP_START
	while [ $ip4 -le 254 ]; do
		output_speed=`process_ip "10.0.61.$ip4"`
		echo " tc class add dev vlan61 parent 1:1 classid 1:$ip4 htb rate  384kbit ceil $output_speed burst 500k cburst 500k"
		ip4=$[ $ip4 + 1 ]
	done
	ip4=$IP_START
	while [ $ip4 -le 254 ]; do
		echo "tc filter add dev vlan61 protocol ip parent 1:0 prio 1 u32 match ip dst 10.0.61.$ip4 classid 1:$ip4"
		ip4=$[ $ip4 + 1 ]
	done
}

generate_tc_script > /tmp/tc_script || exit
chmod +x /tmp/tc_script
/tmp/tc_script
