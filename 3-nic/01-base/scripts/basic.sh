#! /bin/bash

apt update -y
apt install -y tcpdump

mkdir static
cd static
echo $HOSTNAME > index.html
python3 -m http.server 80 &
