#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

FQDN="${1:-}"
LICENSE="${2:-}"

# Enable HTTPS
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload

# LVM+XFS for data disk
## Create single partition with Linux LVM type (8e)
echo ',,8e;' | sfdisk /dev/sdc
## Create LVM PV, VG and LV
pvcreate /dev/sdc1
vgcreate automate /dev/sdc1
lvcreate -l 100%FREE -n data automate
## Mount as /hab
mkdir /hab
mkfs.xfs /dev/automate/data
echo "/dev/mapper/automate-data /hab xfs defaults 0 0" | sudo tee -a /etc/fstab
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
