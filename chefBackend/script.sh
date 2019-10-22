#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

DISK="sdc"
VG="chefbackend"
LV="data"
MOUNT="/var/opt/chef-backend"

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

curl -L https://omnitruck.chef.io/install.sh | bash -s -- -P chef-backend -d /tmp -v 2.0.30

if [ "${HOSTNAME: -1}" = "0" ]; then
  # Initial leader
  chef-backend-ctl create-cluster --accept-license --quiet -y
else
  # Initial follower
  #
  # sudo chef-backend-ctl join-cluster --accept-license -s chef-backend-secrets.json -y --quiet
fi
