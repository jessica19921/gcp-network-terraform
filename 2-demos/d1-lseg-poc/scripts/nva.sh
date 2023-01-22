#! /bin/bash

apt update
apt install -y tcpdump

# routing
#-----------------------------------

sysctl -w net.ipv4.conf.all.forwarding=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"
export ENS5_ADDR=$(curl -H "Metadata-Flavor: Google" $INT/1/ip)
export ENS5_MASK=$(curl -H "Metadata-Flavor: Google" $INT/1/subnetmask)
export ENS5_DGW=$(curl -H "Metadata-Flavor: Google" $INT/1/gateway)

echo "1 rt5" | sudo tee -a /etc/iproute2/rt_tables

# all traffic from/to ens5 should use rt5 for lookup
# subnet mask is used to expand entire range
ip rule add from $ENS5_DGW/$ENS5_MASK table rt5
ip rule add to $ENS5_DGW/$ENS5_MASK table rt5
%{~ for RANGE in ENS5_LINKED_PREFIXES }
ip rule add to ${RANGE} table rt5
%{~ endfor }

# route for networks reachable via ENS5
%{~ for RANGE in ENS5_LINKED_PREFIXES }
ip route add ${RANGE} via $ENS5_DGW dev ens5 table rt5
%{~ endfor }

# playz
#-----------------------------------
cat <<EOF > /usr/local/bin/playz
echo -e "\n ping ...\n"
%{ for target in PING_TARGETS ~}
echo ${target} - \$(ping -qc2 -W1 ${target} 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"FAIL") }')
%{ endfor ~}
echo -e "\n curl ...\n"
%{ for target in CURL_TARGETS ~}
echo  "\$(curl -k --max-time 1 -w "%%{http_code} (%%{time_total}s)" -s -o /dev/null ${target}) - ${target}"
%{ endfor ~}
echo ""
EOF
chmod a+x /usr/local/bin/playz
