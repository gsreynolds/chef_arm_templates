# Chef ARM Templates

Templates to create:
* virtual network
* 3 node ElasticSearch cluster for Chef Automate
* Chef Automate server
* 3 node Chef Backend HA cluster
* 2 Chef Infra Server frontends
* load balancer for Chef Infra Server frontends

![Overview](/images/overview.svg)

## Before using

* Add elastic search root CA and use securityadmin.sh to replace demo certificates (https://opendistro.github.io/for-elasticsearch-docs/docs/security-configuration/)

```
az group deployment create --name vnet --resource-group RGNAMEHERE --template-file vnet/template.json --parameters @vnet/parameters.json
az group deployment create --name automateElastic --resource-group RGNAMEHERE --template-file automateElastic/template.json --parameters @automateElastic/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
az group deployment create --name automate --resource-group RGNAMEHERE --template-file automate/template.json --parameters @automate/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
az group deployment create --name chefLB --resource-group RGNAMEHERE --template-file chefLB/template.json --parameters=@chefLB/parameters.json
az group deployment create --name chefBackend --resource-group RGNAMEHERE --template-file chefBackend/template.json --parameters @chefBackend/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
az group deployment create --name chefFrontend --resource-group RGNAMEHERE --template-file chefFrontend/template.json --parameters @chefFrontend/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
```

```
VNET: 10.1.0.0/24
automateElastic: 10.1.0.4, 10.1.0.5, 10.1.0.6
automate: 10.1.0.7
chefBackend: 10.1.0.10, 10.1.0.11, 10.1.0.12
chefFrontEnd: 10.1.0.20, 10.1.0.21
```

## Manual steps

* Create users and orgs on a Chef Server Frontend:
```
chef-server-ctl org-create test TestOrg -f test-validator.pem
chef-server-ctl user-create admin Admin User admin@example.com TestPassword -o test -f admin.pem
chef-server-ctl grant-server-admin-permissions admin
```
