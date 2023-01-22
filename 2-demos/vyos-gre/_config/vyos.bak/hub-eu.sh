#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
configure
#!
set interfaces loopback lo address 11.11.11.11/32
#!
set protocols bgp 65001 neighbor 10.1.11.3 remote-as '65011'
set protocols bgp 65001 neighbor 10.1.11.3 address-family ipv4-unicast soft-reconfiguration inbound
set protocols bgp 65001 neighbor 10.1.11.3 timers holdtime '60'
set protocols bgp 65001 neighbor 10.1.11.3 timers keepalive '20'
set protocols bgp 65001 neighbor 10.1.11.3 ebgp-multihop 4
#!
set protocols bgp 65001 neighbor 10.1.11.4 remote-as '65011'
set protocols bgp 65001 neighbor 10.1.11.4 address-family ipv4-unicast soft-reconfiguration inbound
set protocols bgp 65001 neighbor 10.1.11.4 timers holdtime '60'
set protocols bgp 65001 neighbor 10.1.11.4 timers keepalive '20'
set protocols bgp 65001 neighbor 10.1.11.4 ebgp-multihop 4
#!
set protocols bgp 65001 parameters graceful-restart
#!
commit
#!
run reset ip bgp 10.1.11.3
run reset ip bgp 10.1.11.4
save
exit
