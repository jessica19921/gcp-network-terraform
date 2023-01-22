#! /bin/bash

apt update
apt install -y tcpdump python3-pip python3-dev
pip3 install Flask requests

# probe web server
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
    app.run(host= '0.0.0.0', port=${PROBE_WEB_SERVER_PORT}, debug = True)
EOF
nohup python3 /var/flaskapp/flaskapp/__init__.py &

cat <<EOF > /var/tmp/startup.sh
nohup python3 /var/flaskapp/flaskapp/__init__.py &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab_flask.txt
crontab /var/tmp/crontab_flask.txt

# probes
#-----------------------------------

cat <<EOF > /usr/local/bin/probez
#! /bin/bash
i=0
while [ \$i -lt 15 ]; do
  %{ for target in PROBE_TARGETS ~}
  ab -n \$1 -c \$2 http://${target}/ > /dev/null 2>&1
  %{ endfor ~}
  let i=i+1
  sleep 3
done
EOF
chmod a+x /usr/local/bin/probez

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/local/bin/probez 5 7 2>&1 > /dev/null
*/2 * * * * /usr/local/bin/probez 7 5 2>&1 > /dev/null
*/3 * * * * /usr/local/bin/probez 10 5 2>&1 > /dev/null
*/5 * * * * /usr/local/bin/probez 15 7 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt

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
