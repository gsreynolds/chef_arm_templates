# Chef ARM Templates

```
az group deployment create --name vnet --resource-group RGNAMEHERE --template-file vnet/template.json --parameters @vnet/parameters.json
az group deployment create --name automateElastic --resource-group RGNAMEHERE --template-file automateElastic/template.json --parameters @automateElastic/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
az group deployment create --name automate --resource-group RGNAMEHERE --template-file automate/template.json --parameters @automate/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
az group deployment create --name chefLB --resource-group RGNAMEHERE --template-file chefLB/template.json --parameters=@chefLB/parameters.json
```


VNET: 10.1.0.0/24
automateElastic: 10.1.0.4, 10.1.0.5, 10.1.0.6
automate: 10.1.0.7
