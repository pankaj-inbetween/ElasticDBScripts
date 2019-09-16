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

echo "Creating ES User"
insureuser elasticsearch 980

echo "Current java verion is: " java -version

echo "Downloading JDK RPM started"
wget https://artifactory/jdk/jdk-8u191-linux-x64.rpm
echo "Downloading JDK RPM completed"

echo "Installing JDK RPM started"
rpm -ivh jdk-8u191-linux-x64.rpm
echo "Installing JDK RPM completed"

echo "Setting up java.sh started"
echo "export JAVA_HOME=/usr/java/jdk1.8.0_191-amd64;export PATH=$PATH:$JAVA_HOME/bin" > /etc/profile.d/java.sh
echo "Setting up java.sh completed"

echo "Changing permissions for java.sh started"
chmod 644 /etc/profile.d/java.sh; source /etc/profile.d/java.sh;
echo "Changing permissions for java.sh completed"

echo "New java verion is: " $JAVA_HOME/bin/java -version

echo "Downloading ES RPM started"
wget https://artifactory/rpms/elasticsearch/5.5.1/elasticsearch-5.5.1.rpm
echo "Downloading ES RPM completed"

echo "Downloading x-pack started"
wget https://artifactory/plugins/x-pack-5.5.1.zip
echo "Downloading x-pack completed"

echo "Installing ES RPM started"
rpm -ivh elasticsearch-5.5.1.rpm
echo "Installing ES RPM completed"

echo "Systemctl"
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service

echo "Creating dirs"
mkdir -p /data/elasticsearch/data
mkdir -p /data/elasticsearch/log
mkdir -p /data/elasticsearch/conf

echo "CONF_DIR=/data/elasticsearch/conf" >> /etc/sysconfig/elasticsearch
echo "DATA_DIR=/data/elasticsearch/data" >> /etc/sysconfig/elasticsearch
echo "ES_GROUP=elasticsearch" >> /etc/sysconfig/elasticsearch
echo "ES_HOME=/usr/share/elasticsearch" >> /etc/sysconfig/elasticsearch
echo "ES_USER=elasticsearch" >> /etc/sysconfig/elasticsearch
echo "LOG_DIR=/data/elasticsearch/log" >> /etc/sysconfig/elasticsearch
echo "MAX_LOCKED_MEMORY=unlimited" >> /etc/sysconfig/elasticsearch
echo "MAX_OPEN_FILES=65536" >> /etc/sysconfig/elasticsearch
echo "ES_JVM_OPTIONS=/data/elasticsearch/conf/jvm.options" >> /etc/sysconfig/elasticsearch

cp -R /etc/elasticsearch/* /data/elasticsearch/conf

echo "
---
bootstrap.memory_lock: true
cluster.name: sandy-test-es-cluster
discovery.zen.ping.unicast.hosts:
- 1.1.1.1
- 1.1.1.2
discovery.zen.ping_timeout: 10s
network.host: _site_
node.attr.tag: sandy-test
node.attr.zone: sandy-test-useast
node.data: 'true'
node.master: 'true'
node.name: $1
path.data: "/data/elasticsearch/data"
path.logs: "/data/elasticsearch/log"
xpack.monitoring.enabled: true
xpack.monitoring.exporters.id1.type: local
xpack.security.audit.enabled: true
xpack.security.audit.logfile.events.include: access_denied, anonymous_access_denied,
  authentication_failed, connection_denied, tampered_request
xpack.security.enabled: true
" > /data/elasticsearch/conf/elasticsearch.yml

/usr/share/elasticsearch/bin/elasticsearch-plugin install file:///root/x-pack-5.5.1.zip --batch
chown -R elasticsearch:elasticsearch /data

sed -i 's/#LimitMEMLOCK=infinity/LimitMEMLOCK=infinity/' /usr/lib/systemd/system/elasticsearch.service

echo "Systemctl"
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service

sudo systemctl start elasticsearch.service
