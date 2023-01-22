#! /bin/bash

touch /usr/local/bin/probez
chmod a+x /usr/local/bin/probez
cat <<EOF > /usr/local/bin/probez
nping -c 1 --tcp -p 80 ${TARGET1}
nping -c 1 --tcp -p 80 ${TARGET2}
EOF

echo "*/5 * * * * /usr/local/bin/probez 2>&1 > /dev/null" > /tmp/crontab.txt
crontab /tmp/crontab.txt
