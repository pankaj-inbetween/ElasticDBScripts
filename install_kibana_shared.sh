#!/bin/bash

function insureuser() {
  name=$1
  uid=$2
  gid=$uid
  id -u "$name"
  if [ "$?" == "1" ]; then
    groupadd -g "$gid" "$name"
    if [ "$?" != "0" ]; then exit 1; fi
    useradd -r -u "$uid" -g "$name" "$name"
    if [ "$?" != "0" ]; then exit 1; fi
    echo "%  User created: $name `id -u $name`"
  fi
}

if [ "$#" -ne 1 ]; then
        echo "#############################################################"
        echo ""
        echo "? Usage: $0 <node_name>"
        echo "#############################################################"
        exit 1
fi

insureuser kibana 982

echo "Downloading Kibana RPM started"
wget https://artifactory/rpms/kibana/5.5.1/kibana-5.5.1-x86_64.rpm
echo "Downloading Kibana RPM completed"

echo "Installing Kibana RPM started"
rpm -ivh kibana-5.5.1-x86_64.rpm
echo "Installing Kibana RPM completed"

echo "Systemctl"
sudo systemctl daemon-reload
sudo systemctl enable kibana.service

mkdir -p /var/log/kibana/
chown -R kibana:kibana /var/log/kibana

echo "---
elasticsearch.password: changeme
elasticsearch.url: http://$HOSTNAME:9200
elasticsearch.username: kibana
logging.dest: "/var/log/kibana/kibana.log"
server.host: $1
server.port: 5601
elasticsearch.requestTimeout: 300000
xpack.reporting.enabled: false
elasticsearch.healthCheck.delay: 1800000
" > /etc/kibana/kibana.yml

chown -R kibana:kibana /usr/share/kibana
chown -R kibana:kibana /etc/kibana

sudo systemctl start kibana.service

/usr/share/kibana/bin/kibana-plugin install file:///root/x-pack-5.5.1.zip

chown -R kibana:kibana /usr/share/kibana
chmod -R 755 /usr/share/kibana

sudo systemctl restart kibana.service
