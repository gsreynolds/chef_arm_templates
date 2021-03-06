#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

function log() {
  message=$1

  echo -e "${message}"
}

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in

    --airgap)
      AIRGAP="$2"
    ;;

    --artifacts-location)
      ARTIFACTSLOCATION="$2"
    ;;

    --artifacts-token)
      ARTIFACTSTOKEN="$2"
    ;;

    --elastic-prefix)
      ELASTICPREFIX="$2"
    ;;

  esac

  # move onto the next argument
  shift
done

log "---------------------------"
log "Chef Automate ElasticSearch"
log "---------------------------"
log "AIRGAP: $AIRGAP"
log "ARTIFACTSLOCATION: $ARTIFACTSLOCATION"
log "ARTIFACTSTOKEN: $ARTIFACTSTOKEN"
log "ELASTICPREFIX: $ELASTICPREFIX"

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

# Install Java 11
yum install -y java-11-openjdk-devel

log "-------------------------------------"
log "Install Open Distro for ElasticSearch"
log "-------------------------------------"

if [ "${AIRGAP}" = "yes" ]; then
  odfe=( "opendistro-security-0.10.1.2.rpm" )
  for rpm in "${odfe[@]}"
  do
    log "Download ${rpm}"
    curl --retry 3 --silent --show-error -o "${rpm}" "${ARTIFACTSLOCATION}/automateElastic/${rpm}${ARTIFACTSTOKEN}"
  done

  rpm -ivh ./*.rpm
else
  tee /etc/yum.repos.d/opendistroforelasticsearch-artifacts.repo <<EOF
  [elasticsearch-6.x]
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
  type=rpm-md
EOF

  yum updateinfo -y
  yum install -y opendistro-security-0.10.1.2-0
fi

log "-----------------------"
log "Configure ElasticSearch"
log "-----------------------"

tee -a /etc/elasticsearch/elasticsearch.yml <<EOF
node.name: ${HOSTNAME}
cluster.name: chef-insights
network.host: 0.0.0.0
discovery.zen.ping.unicast.hosts: ["${ELASTICPREFIX}0", "${ELASTICPREFIX}1", "${ELASTICPREFIX}2"]
EOF

tee -a /etc/sysconfig/elasticsearch <<EOF
ES_JAVA_OPTS="-Djna.tmpdir=/var/lib/elasticsearch/tmp"
EOF

log "-------------------"
log "Start ElasticSearch"
log "-------------------"

systemctl start elasticsearch.service
