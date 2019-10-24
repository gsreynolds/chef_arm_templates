#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

SECRETSLOCATION="${1:-}"
SECRETSTOKEN="${2:-}"

DISK="sdc"
VG="opscode"
LV="data"
MOUNT="/var/opt/opscode"

# Enable HTTPS
firewall-cmd --zone=public --permanent --add-service=https
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

curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P chef-server -d /tmp -v 13.0.17
mkdir -p /etc/opscode

curl -o /etc/opscode/chef-server.rb "$SECRETSLOCATION/chef-server.rb.chefFrontend${HOSTNAME: -1}$SECRETSTOKEN"

echo "
# Data collector & compliance
data_collector['root_url'] =  'https://automate/data-collector/v0/'
data_collector['proxy'] = true
profiles['root_url'] = 'https://automate'
opscode_erchef['max_request_size'] = 2000000
insecure_addon_compat false
" >> /etc/opscode/chef-server.rb

if [ "${HOSTNAME: -1}" = "0" ]; then
  echo "First frontend"
  chef-server-ctl reconfigure --chef-license=accept
  curl --retry 3 --silent --show-error --upload-file /etc/opscode/private-chef-secrets.json "$SECRETSLOCATION/private-chef-secrets.json$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
  curl --retry 3 --silent --show-error --upload-file /var/opt/opscode/upgrades/migration-level "$SECRETSLOCATION/migration-level$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
else
  echo "Other frontends"
  sleep 300
  curl --retry 3 --silent --show-error -o /etc/opscode/private-chef-secrets.json "$SECRETSLOCATION/private-chef-secrets.json$SECRETSTOKEN"
  mkdir -p /var/opt/opscode/upgrades/
  curl --retry 3 --silent --show-error -o /var/opt/opscode/upgrades/migration-level "$SECRETSLOCATION/migration-level$SECRETSTOKEN"
  touch /var/opt/opscode/bootstrapped
  chef-server-ctl reconfigure --chef-license=accept
fi

# Configure data collector
# chef-server-ctl set-secret data_collector token TOKEN
# chef-server-ctl restart nginx && chef-server-ctl restart opscode-erchef
