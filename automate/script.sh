#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

FQDN="${1:-}"
LICENSE="${2:-}"
DISK="sdc"
VG="automate"
LV="data"
MOUNT="/hab"

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
## Mount as /hab
mkdir $MOUNT
mkfs.xfs /dev/$VG/$LV
echo "/dev/mapper/$VG-$LV $MOUNT xfs defaults 0 0" | sudo tee -a /etc/fstab
mount -a

# Install Automate
wget https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip
sudo unzip chef-automate_linux_amd64.zip
echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf
echo vm.dirty_expire_centisecs=20000 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf
sudo ./chef-automate init-config --fqdn "$FQDN"
sudo ./chef-automate deploy --channel current --upgrade-strategy none --accept-terms-and-mlsa config.toml
sudo chef-automate license apply "$LICENSE"
