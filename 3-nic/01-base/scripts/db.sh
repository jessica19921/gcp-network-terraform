#! /bin/bash

apt update -y
apt install -y tcpdump apache2-utils

mkdir static
cd static
echo $HOSTNAME > index.html
python3 -m http.server ${PORT} &

%{ if TARGETS != [] ~}
cat <<EOF > /usr/local/bin/insightz
#! /bin/bash
i=0
while [ \$i -lt 4 ]; do
  %{ for target in TARGETS_INSIGHT ~}
  ab -n \$1 -c \$2 ${target} > /dev/null 2>&1
  %{ endfor ~}
  let i=i+1
  sleep 2
done
EOF
chmod a+x /usr/local/bin/insightz

cat <<EOF > /tmp/crontab.txt
*/1 * * * * /usr/local/bin/insightz 30 2 2>&1 > /dev/null
*/1 * * * * /usr/local/bin/insightz 30 1 2>&1 > /dev/null
EOF
crontab /tmp/crontab.txt
%{ endif ~}
