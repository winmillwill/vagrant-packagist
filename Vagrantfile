# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'precise64'
  config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
  config.vm.network :private_network, ip: '192.168.33.10'
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

  config.vm.synced_folder 'work/', '/home/vagrant/work', :nfs => true

  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = './cookbooks'
    chef.add_recipe 'packagist_cookbook'
    chef.json = {
      packagist: {
        web_root: '/home/vagrant/work',
        repository: 'https://github.com/winmillwill/packagist',
        ref: 'drupal'
      }
    }
    chef.json.merge!(JSON.parse(File.read('./chef.json')))
  end
end
