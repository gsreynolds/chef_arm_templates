# Chef ARM Templates

```
az group deployment create --name vnet --resource-group RGNAMEHERE --template-file vnet/template.json --parameters @vnet/parameters.json
az group deployment create --name automate --resource-group RGNAMEHERE --template-file automate/template.json --parameters @automate/parameters.json --parameters adminPublicKey="$(cat ~/.ssh/KEYNAMEHERE.pub)"
```
