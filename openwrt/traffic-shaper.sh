# Deps: iptables-mod-quota2

# iptables -t mangle -I POSTROUTING -m quota2 --name tc-01 --quota 64000000 -d 192.168.1.116 -j MARK --set-mark 
0x1
# TODO: Apply TC01 to mark 0x1, TC02 to mark 0x2 etc etc
