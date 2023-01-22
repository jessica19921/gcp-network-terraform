#! /bin/bash

apt-get update
apt-get install apache2 -y
a2ensite default-ssl
a2enmod ssl
vm_hostname="$(curl -H "Metadata-Flavor:Google" \
http://169.254.169.254/computeMetadata/v1/instance/name)"
echo "Hostname: $vm_hostname" | \
tee /var/www/html/index.html
systemctl restart apache2

mkdir /var/flaskapp
mkdir /var/flaskapp/flaskapp
mkdir /var/flaskapp/flaskapp/static
mkdir /var/flaskapp/flaskapp/templates

cat <<EOF > /var/flaskapp/flaskapp/udp.py
#!/usr/bin/python3
import socket,struct
def loop_on_socket(s):
  while True:
    d, addr = s.recvfrom(1500)
    print(d, addr)
    s.sendto("ECHO: ".encode('utf8')+d, addr)

if __name__ == "__main__":
   HOST, PORT = "0.0.0.0", 60002
   sock = socket.socket(type=socket.SocketKind.SOCK_DGRAM)
   sock.bind((HOST, PORT))
   loop_on_socket(sock)
EOF

nohup python3 /var/flaskapp/flaskapp/udp.py &

cat <<EOF > /var/tmp/startup.sh
nohup python3 /var/flaskapp/flaskapp/udp.py &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab_flask.txt
crontab /var/tmp/crontab_flask.txt
