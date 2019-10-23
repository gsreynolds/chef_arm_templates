#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

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

curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P chef-backend -d /tmp -v 2.0.30
mkdir -p /etc/chef-backend
echo "publish_address '$(hostname -i)'" >> /etc/chef-backend/chef-backend.rb
echo '{
  "postgresql": {
    "db_superuser_password": "111d8798051edbf25e60a1932c4aed8b55b1e4c9096a0fdbea0990bf9d972e7bda83867c33c24f6f2a28d30f755dcadff5cd",
    "replication_password": "30408d653dfcd05ae1b6128a529b14b9e35a5ffc9d5db60fb59b2de18bef5e5798a388e383e6a7661db2934fdd8a93d2b6df"
  },
  "etcd": {
    "initial_cluster_token": "84bf482510ff4a431319a9310706ab601ed605b03c64fe28489c6445aab329c7cee3595d477ab8575d62457bbaef1c2ed1dd"
  },
  "elasticsearch": {
    "cluster_name": "ChefBackend-422d20f3"
  }
}' >> /etc/chef-backend/chef-backend-secrets.json

if [ "${HOSTNAME: -1}" = "0" ]; then
  echo "Initial leader"
  chef-backend-ctl create-cluster --accept-license -y
else
  echo "Initial follower"
  sleep 300
  chef-backend-ctl join-cluster chefBackend0 --accept-license -s /etc/chef-backend/chef-backend-secrets.json -y
fi

# chef-backend-ctl status
# chef-backend-ctl cluster-status
