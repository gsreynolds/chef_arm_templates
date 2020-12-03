# curl -XGET http://localhost:10144
# curl -XGET http://localhost:10144/_cat/nodes?v
# curl -XGET http://localhost:10144/_cat/plugins?v
# curl -XGET http://localhost:10144/_cluster/health?pretty
# curl -XGET "http://localhost:10144/_cat/indices?v&pretty"

control 'automate-es-gateway' do
  title 'Automate ElasticSearch gateway'
  desc  ''

  describe command('curl -XGET http://localhost:10144') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('"cluster_name" : "chef-insights"') }
    its('stdout') { should match ('"number" : "6.8.12"') }
  end

  describe command('curl -XGET http://localhost:10144/_cat/nodes?v') do
    its('exit_status') { should eq 0 }
    (0..2).each do |i|
      its('stdout') { should match ("automateElastic#{i}") }
    end
  end

  describe command('curl -XGET http://localhost:10144/_cat/plugins?v') do
    its('exit_status') { should eq 0 }
    (0..2).each do |i|
      its('stdout') { should match ("automateElastic#{i} opendistro_security") }
    end
  end

  describe command('curl -XGET http://localhost:10144/_cluster/health?pretty') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('"status" : "green"') }
    its('stdout') { should match ('"number_of_nodes" : 3') }
  end

  describe command('curl -XGET "http://localhost:10144/_cat/indices?v&pretty"') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('.opendistro_security') }
    its('stdout') { should match ('node-state') }
    its('stdout') { should match ('profiles') }
    its('stdout') { should match ('node-attribute') }
    its('stdout') { should match ('eventfeed') }
  end
end

control 'automate-status' do
  title 'Automate status'
  desc  ''
  describe command('sudo chef-automate status') do
    its('exit_status') { should eq 0 }
  end

  describe command('sudo chef-automate diagnostics run') do
    its('exit_status') { should eq 0 }
  end
end
