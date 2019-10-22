#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

DISK="sdc"
VG="automateelastic"
LV="data"
MOUNT="/var/lib/elasticsearch"

# Enable Elastic
firewall-cmd --zone=public --permanent --add-port=9200/tcp
firewall-cmd --zone=public --permanent --add-port=9300/tcp
firewall-cmd --reload

# LVM+XFS for data disk
## Create single partition with Linux LVM type (8e)
echo ',,8e;' | sfdisk /dev/$DISK
## Create LVM PV, VG and LV
pvcreate /dev/${DISK}1
vgcreate $VG /dev/${DISK}1
lvcreate -l 100%FREE -n $LV $VG
## Mount
mkdir -p $MOUNT
mkfs.xfs /dev/$VG/$LV
echo "/dev/mapper/$VG-$LV $MOUNT xfs defaults 0 0" | sudo tee -a /etc/fstab
mount -a

# Install Open Distro for ElasticSearch
echo '[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/oss-6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

[opendistroforelasticsearch-artifacts-repo]
name=Release RPM artifacts of OpenDistroForElasticsearch
baseurl=https://d3g5vo6xdbdb9a.cloudfront.net/yum/noarch/
enabled=1
gpgkey=https://d3g5vo6xdbdb9a.cloudfront.net/GPG-KEY-opendistroforelasticsearch
gpgcheck=1
repo_gpgcheck=1
autorefresh=1
type=rpm-md' > /etc/yum.repos.d/opendistroforelasticsearch-artifacts.repo
yum updateinfo -y
yum install -y java-11-openjdk-devel
yum install -y opendistroforelasticsearch-0.7.0-1

# Test ElasticSearch
# curl -XGET https://localhost:9200 -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cat/nodes?v -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cat/plugins?v -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cluster/health?pretty -u admin:admin --insecure
# curl -XGET "https://localhost:9200/_cat/indices?v&pretty" -u admin:admin --insecure

echo "
node.name: $HOSTNAME
" >> /etc/elasticsearch/elasticsearch.yml

echo '
cluster.name: chef-insights
network.host: 0.0.0.0
discovery.zen.ping.unicast.hosts: ["automateElastic0", "automateElastic1", "automateElastic2"]
' >> /etc/elasticsearch/elasticsearch.yml
systemctl start elasticsearch.service
