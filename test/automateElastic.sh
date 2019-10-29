#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

DNSPREFIX="${1:-}"
DOMAIN="${2:-northeurope.cloudapp.azure.com}"

for i in {0..2}
do
  inspec exec -t ssh://chef@$DNSPREFIX$i.$DOMAIN automateElastic/
done

