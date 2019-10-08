#!/bin/sh
wget https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip
sudo unzip chef-automate_linux_amd64.zip
echo vm.max_map_count=262144 | sudo tee -a /etc/sysctl.conf
echo vm.dirty_expire_centisecs=20000 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf
# sudo ./chef-automate init-config --fqdn ""
sudo ./chef-automate init-config
sudo ./chef-automate deploy --channel current --upgrade-strategy none --accept-terms-and-mlsa config.toml
# sudo chef-automate license apply ""
