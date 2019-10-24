control 'backend-status' do
  title 'Chef Infra Server Backend status'
  desc  ''
  describe command('sudo chef-backend-ctl status') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match ('health: green; healthy nodes: 3/3') }
  end

  describe command('sudo chef-backend-ctl cluster-status') do
    its('exit_status') { should eq 0 }
    (0..2).each do |i|
      its('stdout') { should match ("chefBackend#{i}") }
    end
  end
end
