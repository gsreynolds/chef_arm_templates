#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

DISK="sdc"
VG="automateelastic"
LV="data"
MOUNT="/hab"

# Enable HTTPS
# firewall-cmd --zone=public --permanent --add-service=https
# firewall-cmd --reload

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
