#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

ARTIFACTSLOCATION="${1:-}"
ARTIFACTSTOKEN="${2:-}"

echo "Upload all scripts"
find . -name 'script.sh' -type f -exec curl --retry 3 --upload-file {} ${ARTIFACTSLOCATION}/{}${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;

mkdir .airgaptmp

# Automate Elasticsearch cluster
mkdir .airgaptmp/automateElastic

echo "Download elasticsearch-oss"
wget --quiet https://artifacts.elastic.co/packages/oss-6.x/yum/6.5.4/elasticsearch-oss-6.5.4.rpm -P .airgaptmp/automateElastic

odfe=( "opendistro-alerting-0.7.0.0.rpm" "opendistro-security-0.7.0.1.rpm" "opendistro-sql-0.7.0.0.rpm" "opendistro-performance-analyzer-0.7.0.0.rpm" "opendistroforelasticsearch-0.7.0.rpm" )
for rpm in "${odfe[@]}"
do
  echo "Download ${rpm}"
	wget --quiet https://d3g5vo6xdbdb9a.cloudfront.net/yum/noarch/${rpm} -P .airgaptmp/automateElastic
done

echo "Upload all artifacts for automateElastic"
find .airgaptmp/automateElastic -name '*' -type f -execdir curl --retry 3 --upload-file {} ${ARTIFACTSLOCATION}/automateElastic/{}${ARTIFACTSTOKEN} --header "x-ms-blob-type: BlockBlob" \;
