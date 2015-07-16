## OpenWRT Traffic Shaper

As a background this script was build to be used to manage a "fair" allocation of very limited monthly bandwidth for my mothers ADSL link. With two kids and a facebook habit 5GB of data per month leads to monthly shaping by the ISP very quickly.

To help solve this problem with technology this script implements exactly the same thing just on the local side of the last mile. I implemented this using 6 traffic classes by taking the slowest target speed and doubling it for each class. This gave me;

    Class  Speed    Quota
    01     4Mbit    64MB
    02     2Mbit    128MB
    03     1Mbit    256MB
    04     512Kbit  512MB
    05     256Kbit  1024MB
    06     128Kbit  N/A

### Assumptions

I have not pushed this too far yet and made a lot of assumptions based on my use case.

* This is deployed on OpenWRT so avoid hitting flash where possible
* Monthly restart at 00:00 on day 01 to "reset" counters
* Counters are not persistent and will be cleared on power-cycle (It's a feature so "remote hands" can reset counters manually).
* DHCP leases are 30 days to keep some persistence in clients addresses
* The LAN subnet is /24
* OpenWRT's QOS scripts are running as well
* We don't need to tell clients when they change traffic classes
* **There is no client to client traffic on the local network**
* The system is logging somewhere remotely so use logger over echo for all messages

### Usage

I implemented this using a MikroTik RouterBOARD 951Ui-2HnD running OpenWRT 14.07. I also make use of the 951's red port 5 LED to indicate that the rc.local is still executing and only disable it last.

#### Installing

1. SCP the **traffic-shaper.sh** to /root/ on your router
1. Set the executable bit on /root/traffic-shaper.sh
1. Add the initial run to **/etc/rc.local**

    ```
    # Run traffic shaper
    sh /root/traffic-shaper.sh
    # Turn off red port 5 LED
    echo 0 > /sys/devices/virtual/gpio/gpio2/value
    ```

1. Add a new cron entry

    ```
    $ crontab -e
    0 0 1 * * sh /root/traffic-shaper.sh
    ```

1. At this point reboot the router and confirm the script applies automatically at boot

#### Checking individual quotas

To check on how a user is progressing through their quota, show the iptables rules. Rules where the quota counter has reached zero will no longer apply their marks and the rules above will take effect.

    root@OpenWRT:~# iptables -t mangle -vnL | grep 192.168.88.127
     8022 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       MARK set 0x6
     8022 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       -m quota --name tc-05-127  --quota 92482941  MARK set 0x5
     8022 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       -m quota --name tc-04-127  --quota 502082941  MARK set 0x4
     8022 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       -m quota --name tc-03-127  --quota 246082941  MARK set 0x3
     8020 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       -m quota --name tc-02-127  --quota 118083053  MARK set 0x2
     8020 9917K MARK       all  --  *      *       0.0.0.0/0            192.168.88.127       -m quota --name tc-01-127  --quota 54083053  MARK set 0x1

#### Checking queue traffic

We use the HTB queues to enforce target speeds. These can be displayed to check if your receiving marked packets correctly.

    root@OpenWRT:~# tc -s class show dev br-lan
    class htb 2:1 root prio 0 rate 4096Kbit ceil 4096Kbit burst 500Kb cburst 500Kb
     Sent 12106972 bytes 13584 pkt (dropped 172, overlimits 0 requeues 0)
     rate 39824bit 9pps backlog 0b 0p requeues 0
     lended: 13584 borrowed: 0 giants: 0
     tokens: 15621521 ctokens: 15621521

    class htb 2:2 root prio 0 rate 2048Kbit ceil 2048Kbit burst 500Kb cburst 500Kb
     Sent 97 bytes 1 pkt (dropped 0, overlimits 0 requeues 0)
     rate 0bit 0pps backlog 0b 0p requeues 0
     lended: 1 borrowed: 0 giants: 0
     tokens: 31244079 ctokens: 31244079

    class htb 2:3 root prio 0 rate 1024Kbit ceil 1024Kbit burst 500Kb cburst 500Kb
     Sent 432 bytes 4 pkt (dropped 0, overlimits 0 requeues 0)
     rate 0bit 0pps backlog 0b 0p requeues 0
     lended: 4 borrowed: 0 giants: 0
     tokens: 62491943 ctokens: 62491943

    class htb 2:4 root prio 0 rate 512Kbit ceil 512Kbit burst 500Kb cburst 500Kb
     Sent 226 bytes 1 pkt (dropped 0, overlimits 0 requeues 0)
     rate 0bit 0pps backlog 0b 0p requeues 0
     lended: 1 borrowed: 0 giants: 0
     tokens: 124944824 ctokens: 124944824

    class htb 2:5 root prio 0 rate 256Kbit ceil 256Kbit burst 500Kb cburst 500Kb
     Sent 932 bytes 2 pkt (dropped 0, overlimits 0 requeues 0)
     rate 0bit 0pps backlog 0b 0p requeues 0
     lended: 2 borrowed: 0 giants: 0
     tokens: 249658983 ctokens: 249658983

    class htb 2:6 root prio 0 rate 128Kbit ceil 128Kbit burst 500Kb cburst 500Kb
     Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
     rate 0bit 0pps backlog 0b 0p requeues 0
     lended: 0 borrowed: 0 giants: 0
     tokens: 500000000 ctokens: 500000000

## Thanks

I leaned heavily on some great doco along the way.

* OpenWRT - http://wiki.openwrt.org/
* Ivan's fair use scripts - http://i1.dk/misc/fair_use/
* LARTC - http://www.lartc.org/
