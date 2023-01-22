#! /bin/bash

apt update -y
apt install -y tcpdump apache2-utils

mkdir static
mkdir static/browse
mkdir static/cart
mkdir static/checkout
mkdir static/feeds
cd static
echo $HOSTNAME > index.html
echo $HOSTNAME > browse/index.html
echo $HOSTNAME > cart/index.html
echo $HOSTNAME > checkout/index.html
echo $HOSTNAME > feeds/index.html
python3 -m http.server ${PORT} &

cat <<EOF > /usr/local/bin/probez
#! /bin/bash
i=0
while [ \$i -lt 4 ]; do
  %{ for target in TARGETS ~}
  ab -n \$1 -c \$2 ${target} > /dev/null 2>&1
  %{ endfor ~}
  let i=i+1
  sleep 2
done
EOF
chmod a+x /usr/local/bin/probez

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/local/bin/probez 30 2 2>&1 > /dev/null
*/1 * * * * /usr/local/bin/probez 30 1 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
