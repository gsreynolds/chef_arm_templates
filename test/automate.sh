#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

DNSPREFIX="${1:-}"
DOMAIN="${2:-northeurope.cloudapp.azure.com}"

inspec exec -t ssh://chef@$DNSPREFIX.$DOMAIN automate/
