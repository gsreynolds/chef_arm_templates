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

    --fqdn)
      FQDN="$2"
    ;;

    --license)
      LICENSE="$2"
    ;;

    --secrets-location)
      SECRETSLOCATION="$2"
    ;;

    --secrets-token)
      SECRETSTOKEN="$2"
    ;;

    --elastic-prefix)
      ELASTICPREFIX="$2"
    ;;

  esac

  # move onto the next argument
  shift
done

log "--------------------------"
log "Chef Automate installation"
log "--------------------------"
log "AIRGAP: $AIRGAP"
log "ARTIFACTSLOCATION: $ARTIFACTSLOCATION"
log "ARTIFACTSTOKEN: $ARTIFACTSTOKEN"
log "FQDN: $FQDN"
log "LICENSE: $LICENSE"
log "SECRETSLOCATION: $SECRETSLOCATION"
log "SECRETSTOKEN: $SECRETSTOKEN"
log "ELASTICPREFIX: $ELASTICPREFIX"

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
## Mount
mkdir -p $MOUNT
mkfs.xfs /dev/$VG/$LV
echo "/dev/mapper/$VG-$LV $MOUNT xfs defaults 0 0" | sudo tee -a /etc/fstab
mount -a

echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf
echo vm.dirty_expire_centisecs=20000 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Install Automate
if [ "${AIRGAP}" = "yes" ]; then
  curl --retry 3 --silent --show-error -o chef-automate_linux_amd64.zip "$ARTIFACTSLOCATION/automate/chef-automate_linux_amd64.zip$ARTIFACTSTOKEN"
  curl --retry 3 --silent --show-error -o automate.aib "$ARTIFACTSLOCATION/automate/automate.aib$ARTIFACTSTOKEN"
  sudo unzip chef-automate_linux_amd64.zip
  sudo ./chef-automate init-config --upgrade-strategy none --fqdn "$FQDN"
else
  wget https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip
  sudo unzip chef-automate_linux_amd64.zip
  sudo ./chef-automate init-config --fqdn "$FQDN"
fi

# shellcheck disable=SC2028
log "---------------------------------------------"
log "Configure external ElasticSearch for Automate"
log "---------------------------------------------"
tee -a config.toml <<EOF
[global.v1.external.elasticsearch]
  enable = true
  nodes = ["https://${ELASTICPREFIX}0:9200", "https://${ELASTICPREFIX}1:9200", "https://${ELASTICPREFIX}2:9200"]
  [global.v1.external.elasticsearch.auth]
      scheme = "basic_auth"
      [global.v1.external.elasticsearch.auth.basic_auth]
        username = "admin"
        password = "admin"
  [global.v1.external.elasticsearch.ssl]
  server_name = "node-0.example.com"
  root_cert = "-----BEGIN CERTIFICATE-----\nMIID/jCCAuagAwIBAgIBATANBgkqhkiG9w0BAQsFADCBjzETMBEGCgmSJomT8ixk\nARkWA2NvbTEXMBUGCgmSJomT8ixkARkWB2V4YW1wbGUxGTAXBgNVBAoMEEV4YW1w\nbGUgQ29tIEluYy4xITAfBgNVBAsMGEV4YW1wbGUgQ29tIEluYy4gUm9vdCBDQTEh\nMB8GA1UEAwwYRXhhbXBsZSBDb20gSW5jLiBSb290IENBMB4XDTE4MDQyMjAzNDM0\nNloXDTI4MDQxOTAzNDM0NlowgY8xEzARBgoJkiaJk/IsZAEZFgNjb20xFzAVBgoJ\nkiaJk/IsZAEZFgdleGFtcGxlMRkwFwYDVQQKDBBFeGFtcGxlIENvbSBJbmMuMSEw\nHwYDVQQLDBhFeGFtcGxlIENvbSBJbmMuIFJvb3QgQ0ExITAfBgNVBAMMGEV4YW1w\nbGUgQ29tIEluYy4gUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC\nggEBAK/u+GARP5innhpXK0c0q7s1Su1VTEaIgmZr8VWI6S8amf5cU3ktV7WT9SuV\nTsAm2i2A5P+Ctw7iZkfnHWlsC3HhPUcd6mvzGZ4moxnamM7r+a9otRp3owYoGStX\nylVTQusAjbq9do8CMV4hcBTepCd+0w0v4h6UlXU8xjhj1xeUIz4DKbRgf36q0rv4\nVIX46X72rMJSETKOSxuwLkov1ZOVbfSlPaygXIxqsHVlj1iMkYRbQmaTib6XWHKf\nMibDaqDejOhukkCjzpptGZOPFQ8002UtTTNv1TiaKxkjMQJNwz6jfZ53ws3fh1I0\nRWT6WfM4oeFRFnyFRmc4uYTUgAkCAwEAAaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAf\nBgNVHSMEGDAWgBSSNQzgDx4rRfZNOfN7X6LmEpdAczAdBgNVHQ4EFgQUkjUM4A8e\nK0X2TTnze1+i5hKXQHMwDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4IB\nAQBoQHvwsR34hGO2m8qVR9nQ5Klo5HYPyd6ySKNcT36OZ4AQfaCGsk+SecTi35QF\nRHL3g2qffED4tKR0RBNGQSgiLavmHGCh3YpDupKq2xhhEeS9oBmQzxanFwWFod4T\nnnsG2cCejyR9WXoRzHisw0KJWeuNlwjUdJY0xnn16srm1zL/M/f0PvCyh9HU1mF1\nivnOSqbDD2Z7JSGyckgKad1Omsg/rr5XYtCeyJeXUPcmpeX6erWJJNTUh6yWC/hY\nG/dFC4xrJhfXwz6Z0ytUygJO32bJG4Np2iGAwvvgI9EfxzEv/KP+FGrJOvQJAq4/\nBU36ZAa80W/8TBnqZTkNnqZV\n-----END CERTIFICATE-----"
EOF

# echo '
# [global.v1.external.elasticsearch.backup.fs]
# path = "/var/opt/chef-automate/backups"
# ' >> config.toml

log "--------------------"
log "Deploy Chef Automate"
log "--------------------"
if [ "${AIRGAP}" = "yes" ]; then
  sudo ./chef-automate deploy --channel current --accept-terms-and-mlsa config.toml --airgap-bundle automate.aib
else
  sudo ./chef-automate deploy --channel current --accept-terms-and-mlsa config.toml
fi

log "-------------"
log "Apply License"
log "-------------"
sudo chef-automate license apply "$LICENSE"

log "-------------"
log "Store Secrets"
log "-------------"
chef-automate admin-token >> data-collector-token
curl --retry 3 --silent --show-error --upload-file automate-credentials.toml "$SECRETSLOCATION/automate-credentials.toml$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
curl --retry 3 --silent --show-error --upload-file data-collector-token "$SECRETSLOCATION/data-collector-token$SECRETSTOKEN" --header "x-ms-blob-type: BlockBlob"
