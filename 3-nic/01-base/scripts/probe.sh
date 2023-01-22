#! /bin/bash

apt-get update
apt-get install nmap tcpdump apache2-utils -y

mkdir static
cd static
echo $HOSTNAME > index.html
python3 -m http.server 80 &

# probe

%{ if TARGETS_INSIGHT != [] ~}
cat <<EOF > /usr/local/bin/insightz
%{ for target in TARGETS_INSIGHT ~}
nping -c 3 --${target.protocol} -p ${target.p} ${target.host} > /dev/null 2>&1
%{ endfor ~}
EOF
chmod a+x /usr/local/bin/insightz
%{ endif ~}

%{ if TARGETS_SLO != [] ~}
cat <<EOF > /usr/local/bin/sloz
#! /bin/bash
i=0
while [ \$i -lt 4 ]; do
  %{ for target in TARGETS_SLO ~}
  ab -n \$1 -c \$2 ${target} > /dev/null 2>&1
  %{ endfor ~}
  let i=i+1
  sleep 2
done
EOF
chmod a+x /usr/local/bin/sloz
%{ endif ~}

cat <<EOF > /tmp/crontab.txt
%{ if TARGETS_INSIGHT != [] ~}
*/1 * * * * /usr/local/bin/insightz 2>&1 > /dev/null
%{ endif ~}
%{ if TARGETS_SLO != [] ~}
*/1 * * * * /usr/local/bin/sloz 30 2 2>&1 > /dev/null
*/1 * * * * /usr/local/bin/sloz 30 1 2>&1 > /dev/null
%{ endif ~}
EOF
crontab /tmp/crontab.txt
