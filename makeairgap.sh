#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

function log() {
  message=$1

  echo -e "${message}"
}

usage()
{
    echo "usage: makeairgap.sh [[[-l location] [-t token]] | [-h]]"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
else
  while [[ $# -gt 0 ]]
  do
    key="$1"
    case $key in
      -l|--artifacts-location)
        ARTIFACTSLOCATION="$2"
      ;;

      -t|--artifacts-token)
        ARTIFACTSTOKEN="$2"
      ;;
      -h | --help )
        usage
        exit
      ;;
    esac
    # move onto the next argument
    shift
  done
fi

log "Create airgap bundle"
log "--------------------"
log "ARTIFACTSLOCATION: $ARTIFACTSLOCATION"
log "ARTIFACTSTOKEN: $ARTIFACTSTOKEN"

log "Upload all scripts"
find . -name 'script.sh' -type f -exec curl --retry 3 --upload-file {} ${ARTIFACTSLOCATION}/{}${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;

mkdir -p .airgaptmp

# Automate Elasticsearch cluster
mkdir -p .airgaptmp/automateElastic

log "Download elasticsearch-oss"
wget --quiet https://artifacts.elastic.co/packages/oss-6.x/yum/6.5.4/elasticsearch-oss-6.5.4.rpm -O .airgaptmp/automateElastic/elasticsearch-oss-6.5.4.rpm

odfe=( "opendistro-alerting-0.7.0.0.rpm" "opendistro-security-0.7.0.1.rpm" "opendistro-sql-0.7.0.0.rpm" "opendistro-performance-analyzer-0.7.0.0.rpm" "opendistroforelasticsearch-0.7.0.rpm" )
for rpm in "${odfe[@]}"
do
  log "Download ${rpm}"
	wget --quiet https://d3g5vo6xdbdb9a.cloudfront.net/yum/noarch/${rpm} -O .airgaptmp/automateElastic/${rpm} 
done

# Automate
mkdir -p .airgaptmp/automate
cd .airgaptmp/automate
wget https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip -O chef-automate_linux_amd64.zip
unzip -o chef-automate_linux_amd64.zip
./chef-automate airgap bundle create automate.aib
rm ./chef-automate
cd -

# Chef Backend
mkdir -p .airgaptmp/chefBackend
wget https://packages.chef.io/files/stable/chef-backend/2.0.30/el/7/chef-backend-2.0.30-1.el7.x86_64.rpm -O .airgaptmp/chefBackend/chef-backend.rpm

# Chef Frontend
mkdir -p .airgaptmp/chefFrontend
wget https://packages.chef.io/files/stable/chef-server/13.0.17/el/7/chef-server-core-13.0.17-1.el7.x86_64.rpm -O .airgaptmp/chefFrontend/chef-server-core.rpm

log "Upload the .airgaptmp directory to your _artifactsLocation ${ARTIFACTSLOCATION}"

# FIXME: Azure File RequestBodyTooLarge for the airgap bundle, chef-backend and chef-server-core.rpm
# Use https://github.com/Azure/blobxfer, Azure Storage Explorer app or other methods

# log "Upload all artifacts for automateElastic"
# find .airgaptmp/automateElastic -name '*' -type f -execdir curl --retry 3 --upload-file {} ${ARTIFACTSLOCATION}/automateElastic/{}${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;

# log "Upload all artifacts for automate"
# find .airgaptmp/automate -name '*.zip' -type f -execdir curl --retry 3 --upload-file {} ${ARTIFACTSLOCATION}/automate/{}${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;

# log "Upload RPM for chefBackend"
# curl --retry 3 --upload-file .airgaptmp/chefBackend/chef-backend.rpm ${ARTIFACTSLOCATION}/chefBackend/chef-backend.rpm${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;

# log "Upload RPM for chefFrontend"
# curl --retry 3 --upload-file .airgaptmp/chefFrontend/chef-server-core.rpm ${ARTIFACTSLOCATION}/chefFrontend/chef-server-core.rpm${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;
