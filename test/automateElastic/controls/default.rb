# curl -XGET https://localhost:9200 -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cat/nodes?v -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cat/plugins?v -u admin:admin --insecure
# curl -XGET https://localhost:9200/_cluster/health?pretty -u admin:admin --insecure
# curl -XGET "https://localhost:9200/_cat/indices?v&pretty" -u admin:admin --insecure

control 'automate-elastic' do
  title 'Automate ElasticSearch cluster'
  desc  ''

  describe command('curl -XGET https://localhost:9200 -u admin:admin --insecure') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('"cluster_name" : "chef-insights"') }
    its('stdout') { should match ('"number" : "6.5.4"') }
  end

  describe command('curl -XGET https://localhost:9200/_cat/nodes?v -u admin:admin --insecure') do
    its('exit_status') { should eq 0 }
    (0..2).each do |i|
      its('stdout') { should match ("automateElastic#{i}") }
    end
  end

  describe command('curl -XGET https://localhost:9200/_cat/plugins?v -u admin:admin --insecure') do
    its('exit_status') { should eq 0 }
    (0..2).each do |i|
      its('stdout') { should match ("automateElastic#{i} opendistro_security") }
    end
  end

  describe command('curl -XGET https://localhost:9200/_cluster/health?pretty -u admin:admin --insecure') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('"status" : "green"') }
    its('stdout') { should match ('"number_of_nodes" : 3') }
  end

  describe command('curl -XGET "https://localhost:9200/_cat/indices?v&pretty" -u admin:admin --insecure') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('.opendistro_security') }
  end
end
