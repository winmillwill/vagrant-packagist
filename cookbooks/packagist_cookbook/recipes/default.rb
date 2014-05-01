execute "apt-get" do
  command "apt-get update"
end

%w{
  make
  git-core
  subversion
  mercurial
  nginx
  php5-dev
  php5-mysql
  php5-cli
  php5-fpm
  php5-intl
  php5-curl
  php5-xdebug
  php-apc
  php-pear
  mysql-server
  redis-server
  libhiredis-dev
  tomcat6
  solr-common
  solr-tomcat
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

bash "nginx config - 1" do
  only_if { File.exists?("/etc/nginx/sites-enabled/default") }
  code "rm /etc/nginx/sites-enabled/default"
end

bash "nginx config - 2" do
  not_if { File.exists?("/etc/nginx/sites-enabled/packagist") }
  code "ln -s /etc/nginx/sites-available/packagist /etc/nginx/sites-enabled/packagist"
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
if !File.exists?("/usr/lib/php5/20090626/phpiredis.so")
  git "/tmp/phpiredis" do
    repository "https://github.com/nrk/phpiredis"
    reference "1b3195f9debc34b8058d2b2a36b40ab27bc62f27"
    action :checkout
  end
end

bash "install phpiredis" do
  not_if { File.exists?("/usr/lib/php5/20090626/phpiredis.so") }
  code <<-EOC
    cd /tmp/phpiredis
    phpize
    ./configure --enable-phpiredis --with-hiredis-dir=/usr/local
    make
    make install
    echo "extension=phpiredis.so" > /etc/php5/conf.d/phpiredis.ini
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
    params['nelmio_solarium']['clients']['default']['dsn'] = 'http://localhost:8080/solr'

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

bash "symfony install" do
  user node.packagist.user
  cwd packagist_path
  returns [0, 1]
  code <<-EOC
  ./app/console -q -n --no-ansi assets:install --symlink web &&
  ./app/console -q -n --no-ansi doctrine:database:create &&
  ./app/console -q -n --no-ansi doctrine:schema:create
EOC
end

%w{
  mysql
  redis-server
  tomcat6
  php5-fpm
  nginx
}.each do |service_name|
  service service_name do
    action [:start, :restart]
  end
end
