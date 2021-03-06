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

    --secrets-location)
      SECRETSLOCATION="$2"
    ;;

    --secrets-token)
      SECRETSTOKEN="$2"
    ;;

  esac

  # move onto the next argument
  shift
done

log "-------------------------"
log "Chef Backend installation"
log "-------------------------"
log "AIRGAP: $AIRGAP"
log "ARTIFACTSLOCATION: $ARTIFACTSLOCATION"
log "ARTIFACTSTOKEN: $ARTIFACTSTOKEN"
log "SECRETSLOCATION: $SECRETSLOCATION"
log "SECRETSTOKEN: $SECRETSTOKEN"

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
  log "--------------"
  log "Initial leader"
  log "--------------"
  chef-backend-ctl create-cluster --accept-license -y
  log "-------------"
  log "Store Secrets"
  log "-------------"
  curl --retry 3 --silent --show-error --upload-file /etc/chef-backend/chef-backend-secrets.json "$SECRETSLOCATION/chef-backend-secrets.json$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
  for i in {0..2}
  do
    chef-backend-ctl gen-server-config chefFrontend$i -f chef-server.rb.chefFrontend$i
    curl --retry 3 --silent --show-error --upload-file chef-server.rb.chefFrontend$i "$SECRETSLOCATION/chef-server.rb.chefFrontend$i$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
  done
else
  log "----------------"
  log "Initial follower"
  log "----------------"
  # backend1 waits 120 seconds, backend2 waits 240 seconds
  sleep "$((120 * ${HOSTNAME: -1}))"
  curl --retry 3 --silent --show-error -o chef-backend-secrets.json "$SECRETSLOCATION/chef-backend-secrets.json$SECRETSTOKEN"
  chef-backend-ctl join-cluster chefBackend0 --accept-license -s chef-backend-secrets.json -y
fi
