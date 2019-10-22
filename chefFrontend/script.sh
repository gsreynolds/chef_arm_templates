#!/bin/sh

set -o errexit
set -o pipefail
set -o nounset

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

echo "# This file generated by chef-backend-ctl gen-server-config
# Modify with extreme caution.

fqdn '$(hostname)'

use_chef_backend true
chef_backend_members ['10.1.0.10', '10.1.0.11', '10.1.0.12']

haproxy['remote_postgresql_port'] = 5432
haproxy['remote_elasticsearch_port'] = 9200

# Specify that postgresql is an external database, and provide the
# VIP of this cluster.  This prevents the chef-server instance
# from creating it's own local postgresql instance.
postgresql['external'] = true
postgresql['vip'] = '127.0.0.1'
postgresql['db_superuser'] = 'chef_pgsql'
postgresql['db_superuser_password'] = '111d8798051edbf25e60a1932c4aed8b55b1e4c9096a0fdbea0990bf9d972e7bda83867c33c24f6f2a28d30f755dcadff5cd'

# These settings ensure that we use remote elasticsearch
# instead of local solr for search.  This also
# set search_queue_mode to 'batch' to remove the indexing
# dependency on rabbitmq, which is not supported in this HA configuration.
opscode_solr4['external'] = true
opscode_solr4['external_url'] = 'http://127.0.0.1:9200'
opscode_erchef['search_provider'] = 'elasticsearch'
opscode_erchef['search_queue_mode'] = 'batch'

# HA mode requires sql-backed storage for bookshelf.
bookshelf['storage_type'] = :sql

# RabbitMQ settings

# At this time we are not providing a rabbit backend. Note that this makes
# this incompatible with reporting and analytics unless you're bringing in
# an external rabbitmq.
rabbitmq['enable'] = false
rabbitmq['management_enabled'] = false
rabbitmq['queue_length_monitor_enabled'] = false

# Opscode Expander
#
# opscode-expander isn't used when the search_queue_mode is batch.  It
# also doesn't support the elasticsearch backend.
opscode_expander['enable'] = false

# Prevent startup failures due to missing rabbit host
dark_launch['actions'] = false

# Cookbook Caching
opscode_erchef['nginx_bookshelf_caching'] = :on
opscode_erchef['s3_url_expiry_window_size'] = '50%'
" >> /etc/opscode/chef-server.rb

if [ "${HOSTNAME: -1}" = "0" ]; then
  echo "First frontend"
  chef-server-ctl reconfigure --chef-license=accept
else
  echo "Other frontends"
  sleep 120
  # cp private-chef-secrets.json /etc/opscode/private-chef-secrets.json
  mkdir -p /var/opt/opscode/upgrades
  # cp migration-level /var/opt/opscode/upgrades/migration-level
  touch /var/opt/opscode/bootstrapped
  # chef-server-ctl reconfigure --chef-license=accept
fi

# chef-server-ctl status
# Configure data collector
# chef-server-ctl set-secret data_collector token TOKEN
# chef-server-ctl restart nginx && chef-server-ctl restart opscode-erchef
# ...


