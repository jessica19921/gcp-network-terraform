#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
configure
#!
#!
set interfaces loopback lo address 1.1.1.1/32
set protocols static route 10.10.0.0/16 next-hop 10.10.1.1
set protocols static route 10.1.11.2/32 next-hop 10.10.1.1
#!
#!
#!
set interfaces tunnel tun0 address 172.16.1.1/24
set interfaces tunnel tun0 encapsulation gre
set interfaces tunnel tun0 local-ip 10.10.1.2
set interfaces tunnel tun0 remote-ip 10.1.11.2
#!
set protocols bgp 65010 parameters router-id '1.1.1.1'
set protocols bgp 65010 neighbor 172.16.1.2 remote-as '65001'
set protocols bgp 65010 neighbor 172.16.1.2 address-family ipv4-unicast soft-reconfiguration inbound
set protocols bgp 65010 neighbor 172.16.1.2 timers holdtime '60'
set protocols bgp 65010 neighbor 172.16.1.2 timers keepalive '20'
set protocols bgp 65010 neighbor 172.16.1.2 ebgp-multihop 4
#!
set protocols bgp 65010 parameters graceful-restart
#!
set protocols bgp 65010 address-family ipv4-unicast network 10.10.0.0/16
#!
#!
#!
#!
commit
#!
run reset ip bgp 172.16.1.2
save
exit
