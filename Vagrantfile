# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'saucy64'
  config.vm.box_url = 'http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_ubuntu-13.10_chef-provisionerless.box'
  config.vm.network :private_network, ip: '192.168.33.10'
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

  config.vm.synced_folder 'work/', '/home/vagrant/work', :nfs => true

  config.omnibus.chef_version = :latest
  config.berkshelf.enabled = true

  config.vm.provision :chef_solo do |chef|
    chef.roles_path = './roles'
    chef.data_bags_path = './data_bags'
    chef.add_recipe 'apt'
    chef.add_recipe 'build-essential'
    chef.add_recipe 'chef-solo-search'
    chef.add_role 'db_master'
    chef.add_recipe 'git'
    chef.add_recipe 'php'
    chef.add_recipe 'nginx'
    chef.add_recipe 'packagist'
    chef.json = {
      packagist: {
        web_root: '/home/vagrant/work',
      },
      mysql: {
        server_root_password: 'password',
        server_repl_password: 'password',
        server_debian_password: 'password'
      }
    }
    chef.json.merge!(JSON.parse(File.read('./chef.json')))
  end
end
