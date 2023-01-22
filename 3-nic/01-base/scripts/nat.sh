#! /bin/bash

apt update -y
apt install -y tcpdump dnsutils

# bucketz (gcs bucket test script)
#---------------------------------------------------

cat <<EOF > /usr/local/bin/bucketz
echo -e "\n storage.googleapis.com - \$(host storage.googleapis.com)\n"
%{ for env,bucket in TARGETS_BUCKET ~}
echo -e " \$(gsutil cat gs://${bucket})\n"
%{ endfor ~}
EOF
chmod a+x /usr/local/bin/bucketz
