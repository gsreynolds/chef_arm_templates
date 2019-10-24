control 'frontend-status' do
  title 'Chef Infra Server Frontend status'
  desc  ''
  describe command('sudo chef-server-ctl status') do
    its('exit_status') { should eq 0 }
    %w(bookshelf haproxy nginx oc_bifrost oc_id opscode-erchef redis_lb).each do |service|
      its('stdout') { should match ("run: #{service}") }
    end
    %w(opscode-solr4 postgresql).each do |service|
      its('stdout') { should match ("run: #{service}: connected OK") }
    end
  end

  describe command('sudo chef-server-ctl test') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('0 failures') }
  end
end
