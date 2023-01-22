#!/usr/bin/env bash

# setup VXLAN
ip link add vxlan0 type vxlan id 42 local ${VXLAN_DEV_ADDR} ttl 16 dev eth0
ip addr add ${VXLAN_ADDR}/${VXLAN_MASK} dev vxlan0
ip link set vxlan0 up
ip route add 224.0.0.0/4 dev vxlan0
%{~ for peer in VXLAN_PEERS }
bridge fdb append 00:00:00:00:00:00 dev vxlan0 dst ${peer}
%{~ endfor }

# web server
#-----------------------------------
## web server is only configured here
## but not used for probing
echo $HOSTNAME > index.html
python3 -m http.server ${WEB_PORT} &

cat <<EOF > /var/tmp/startup.sh
echo $HOSTNAME > index.html
python3 -m http.server ${WEB_PORT} &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab_python_web.txt
crontab /var/tmp/crontab_python_web.txt

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

# iperf source
#-----------------------------------
cat <<EOF > /usr/local/bin/mcast-send
iperf -c ${MCAST_SEND_ADDR} -p ${MCAST_PORT} -u -T 32 -t 100 -i 1
EOF
chmod a+x /usr/local/bin/mcast-send

# iperf sink
#-----------------------------------
cat <<EOF > /usr/local/bin/mcast-listen
iperf -s -u -B ${MCAST_SEND_ADDR} -p ${MCAST_PORT} -i 1
EOF
chmod a+x /usr/local/bin/mcast-listen

# tblisten
#-----------------------------------
cat <<EOF > /usr/local/bin/tblisten
tibrvlisten -service ${MCAST_PORT} -network "${VXLAN_ADDR};${MCAST_LISTEN_ADDR}" -daemon tcp:7777 TESTING.*
EOF
chmod a+x /usr/local/bin/tblisten

# tbsend
#-----------------------------------
cat <<EOF > /usr/local/bin/tbsend
read -p "Message? [hello-world]: " TIBRV_SEND_MESSAGE
TIBRV_SEND_MESSAGE=\$${TIBRV_SEND_MESSAGE:-hello-world}
i=0
while [ \$i -lt 300 ]; do
tibrvsend -service ${MCAST_PORT} -network "${VXLAN_ADDR};${MCAST_SEND_ADDR}" -daemon tcp:7777 TESTING.MESSAGE "\$TIBRV_SEND_MESSAGE"
echo "message \$i sent..."
let i=i+1
sleep 1
done
EOF
chmod a+x /usr/local/bin/tbsend

# motd
cat <<EOF > /etc/motd
---------------------------------------------------------------------------
This host is configured to allow multicast testing via VXLAN.
Tibco middleware software: RV is installed to provide real world use-cases.

Test Script are provided:
1) ping test - /usr/local/bin/playz
2) iPerf multicast sender - /usr/local/bin/mcast-send
3) iPerf multicast listener - /usr/local/bin/mcast-listen
4) tibrvsend message source- /usr/local/bin/tbsend
5) tibrvlisten message sink - /usr/local/bin/tblisten

Run up a version on your allocated sender and receiver(s).
--------------------------------------------------------------------------
EOF
