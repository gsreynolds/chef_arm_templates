# Chef ARM Templates

![Overview](/images/overview.svg)

## Before using

* Add elastic search root CA and use securityadmin.sh to replace demo certificates (https://opendistro.github.io/for-elasticsearch-docs/docs/security-configuration/)
* Change any hard-coded credentials/certificates for Chef Server
* Consider Azure Key Vault/Blob Storage for secrets

```
az group deployment create --name vnet --resource-group RGNAMEHERE --template-file vnet/template.json --parameters @vnet/parameters.json
az group deployment create --name automateElastic --resource-group RGNAMEHERE --template-file automateElastic/template.json --parameters @automateElastic/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)" --parameters dnsLabelPrefix=AUTOMATEELASTICDNSPREFIXHERE
az group deployment create --name automate --resource-group RGNAMEHERE --template-file automate/template.json --parameters @automate/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)" --parameters dnsLabelPrefix=AUTOMATEDNSPREFIXHERE
az group deployment create --name chefLB --resource-group RGNAMEHERE --template-file chefLB/template.json --parameters=@chefLB/parameters.json --parameters dnsLabelPrefix=CHEFLBDNSPREFIXHERE
az group deployment create --name chefBackend --resource-group RGNAMEHERE --template-file chefBackend/template.json --parameters @chefBackend/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)" --parameters dnsLabelPrefix=CHEFBACKENDDNSPREFIXHERE
az group deployment create --name chefFrontend --resource-group RGNAMEHERE --template-file chefFrontend/template.json --parameters @chefFrontend/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)" --parameters dnsLabelPrefix=CHEFFRONTENDDNSPREFIXHERE
```

```
VNET: 10.1.0.0/24
automateElastic: 10.1.0.4, 10.1.0.5, 10.1.0.6
automate: 10.1.0.7
chefBackend: 10.1.0.10, 10.1.0.11, 10.1.0.12
chefFrontEnd: 10.1.0.20, 10.1.0.21
```

## Manual steps

* Retrieve Chef Automate credentials from `/var/lib/waagent/custom-script/download/0/automate-credentials.toml`
* After creating Chef Server Frontends, copy `/etc/opscode/private-chef-secrets.json` and `/var/opt/opscode/upgrades/migration-level` from `chefFrontEnd0` to `chefFrontend1`. Create empty file `/var/opt/opscode/bootstrapped` on `chefFrontEnd1`. Run `chef-server-ctl reconfigure --chef-license=accept`.
* Create data collector token on Chef Automate e.g. `chef-automate admin-token`
* Set data collector token on both Chef Server Frontends. `chef-server-ctl set-secret data_collector token TOKEN && chef-server-ctl restart nginx && chef-server-ctl restart opscode-erchef`.
* Create users and orgs on Chef Server Frontends e.g.
```
chef-server-ctl org-create test TestOrg -f test-validator.pem
chef-server-ctl user-create admin Admin User admin@example.com TestPassword -o test -f admin.pem
chef-server-ctl grant-server-admin-permissions admin
```
