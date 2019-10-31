#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

AIRGAP="${1:-no}"
ARTIFACTSLOCATION="${2:-}"
ARTIFACTSTOKEN="${3:-}"
SECRETSLOCATION="${4:-}"
SECRETSTOKEN="${5:-}"

DISK="sdc"
VG="chefbackend"
LV="data"
MOUNT="/var/opt/chef-backend"

# Enable chef-backend ports
# https://docs.chef.io/install_server_ha.html#network-port-requirements
firewall-cmd --zone=public --permanent --add-port=2379/tcp
firewall-cmd --zone=public --permanent --add-port=2380/tcp
firewall-cmd --zone=public --permanent --add-port=5432/tcp
firewall-cmd --zone=public --permanent --add-port=7331/tcp
firewall-cmd --zone=public --permanent --add-port=9200-9400/tcp
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

if [ "${AIRGAP}" = "yes" ]; then
  curl --retry 3 --silent --show-error -o chef-backend.rpm "$ARTIFACTSLOCATION/chefBackend/chef-backend.rpm$ARTIFACTSTOKEN"
  rpm -ivh chef-backend.rpm
else
  curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P chef-backend -d /tmp -v 2.0.30
fi

mkdir -p /etc/chef-backend
echo "publish_address '$(hostname -i)'" >> /etc/chef-backend/chef-backend.rb

if [ "${HOSTNAME: -1}" = "0" ]; then
  echo "Initial leader"
  chef-backend-ctl create-cluster --accept-license -y
  curl --retry 3 --silent --show-error --upload-file /etc/chef-backend/chef-backend-secrets.json "$SECRETSLOCATION/chef-backend-secrets.json$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
  for i in {0..2}
  do
    chef-backend-ctl gen-server-config chefFrontend$i -f chef-server.rb.chefFrontend$i
    curl --retry 3 --silent --show-error --upload-file chef-server.rb.chefFrontend$i "$SECRETSLOCATION/chef-server.rb.chefFrontend$i$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
  done
else
  echo "Initial follower"
  # backend1 waits 120 seconds, backend2 waits 240 seconds
  sleep "$((120 * ${HOSTNAME: -1}))"
  curl --retry 3 --silent --show-error -o chef-backend-secrets.json "$SECRETSLOCATION/chef-backend-secrets.json$SECRETSTOKEN"
  chef-backend-ctl join-cluster chefBackend0 --accept-license -s chef-backend-secrets.json -y
fi
