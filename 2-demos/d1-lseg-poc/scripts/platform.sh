#! /bin/bash

apt install -y tcpdump python3-pip python3-dev
pip3 install Flask requests

# web server
#-----------------------------------

mkdir /var/flaskapp
mkdir /var/flaskapp/flaskapp
mkdir /var/flaskapp/flaskapp/static
mkdir /var/flaskapp/flaskapp/templates

cat <<EOF > /var/flaskapp/flaskapp/__init__.py
import socket
from flask import Flask, request
app = Flask(__name__)

@app.route("/")
def default():
    hostname = socket.gethostname()
    address = socket.gethostbyname(hostname)
    data_dict = {}
    data_dict['name'] = hostname
    data_dict['address'] = address
    data_dict['remote'] = request.remote_addr
    data_dict['headers'] = dict(request.headers)
    return data_dict

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=${WEB_PORT}, debug = True)
EOF
nohup python3 /var/flaskapp/flaskapp/__init__.py &

cat <<EOF > /var/tmp/startup.sh
nohup python3 /var/flaskapp/flaskapp/__init__.py &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab_flask.txt
crontab /var/tmp/crontab_flask.txt

# proxy
#-----------------------------------

export INT="http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/"
export ENS4_ADDR=$(curl -H "Metadata-Flavor: Google" $INT/0/ip)
%{~ for t in DNAT_TARGETS }
iptables -A PREROUTING -t nat -d $ENS4_ADDR -s ${t.s} -p ${t.p} --dport ${t.dport} -m state --state NEW,ESTABLISHED -j DNAT --to-destination ${t.dnat}
%{~ endfor }
iptables -t nat -A POSTROUTING -j SNAT --to-source $ENS4_ADDR

sysctl -w net.ipv4.conf.all.forwarding=1
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

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
