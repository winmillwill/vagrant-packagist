%w{
  subversion
  mercurial
  redis-server
  tomcat6
  solr-common
  solr-tomcat
  php5-json
  php5-fpm
  php5-mysql
  curl
}.each do |pkg|
  package pkg do
    action [:install, :upgrade]
  end
end

# nginx
template "/etc/nginx/sites-available/packagist" do
  mode 0644
  source "packagist.conf.erb"
end

bash "nginx disable default" do
  only_if { File.exists?("/etc/nginx/sites-enabled/default") }
  code "nxdissite default"
end

bash "nginx enable packagist" do
  not_if { File.exists?("/etc/nginx/sites-enabled/packagist") }
  code "nxensite packagist"
end

# composer
bash "install composer" do
  not_if { File.exists?("/usr/local/bin/composer") }
  code <<-EOC
    cd ~
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
  EOC
end

bash "update composer" do
  code <<-EOC
    sudo composer self-update
  EOC
end

# php redis

git "/tmp/phpredis" do
  repository "https://github.com/nicolasff/phpredis"
  action :checkout
end

bash "install phpredis" do
  not_if "php -m | grep redis"
  code <<-EOC
    cd /tmp/phpredis
    phpize
    ./configure
    make
    make install
    echo "extension=redis.so" > /etc/php5/mods-available/redis.ini
    php5enmod redis
  EOC
end

directory node.packagist.web_root do
  recursive true
end

# web user must be able to create ~/.composer
directory '/var/www' do
  owner 'www-data'
end

packagist_path = File.join(node.packagist.web_root, 'packagist')
git packagist_path do
  user node.packagist.user
  repository node.packagist.repository
  reference node.packagist.ref
  action :checkout
end

ruby_block 'packagist yaml' do
  block do
    require 'yaml'
    params = YAML.load_file(File.join(packagist_path, "app/config/parameters.yml.dist"))
    params['parameters']['github.client_id'] = node.github.client_id
    params['parameters']['github.client_secret'] = node.github.client_secret
    params['parameters']['packagist_host'] = node.packagist.packagist_host
    params['parameters']['database_password'] = node.mysql.server_root_password
    params['nelmio_solarium'] = {
      'clients' => {
        'default' => {
          'dsn' => 'http://localhost:8080/solr'
        }
      }
    }

    File.open(File.join(packagist_path, 'app/config/parameters.yml'), 'w') do |f|
      f.write params.to_yaml
    end
  end
end

bash "resolve dependencies of packagist" do
  user node.packagist.user
  not_if { File.exists?("/home/vagrant/work/packagist/vendor") }
  code <<-EOC
    cd /home/vagrant/work/packagist
    composer install
  EOC
end

# cron doesn't like \n
update = "cd #{packagist_path} && \
  app/console packagist:update --no-debug --env=prod && \
  app/console packagist:dump --no-debug --env=prod && \
  app/console packagist:index --no-debug --env=prod --all"

cron 'symfony-update' do
  minute '*/5'
  command update
end

execute "cp #{packagist_path}/doc/schema.xml /usr/share/solr/conf/"
service 'tomcat6' do
  action :restart
end

bash "symfony install" do
  user node.packagist.user
  cwd packagist_path
  returns [0, 1]
  code %Q{
    ./app/console -q -n --no-ansi assets:install --symlink web &&
    ./app/console -q -n --no-ansi doctrine:database:create &&
    ./app/console -q -n --no-ansi doctrine:schema:create &&
    ./app/console -q -n --no-ansi cache:clear --env prod &&
    #{update}
  }
end
