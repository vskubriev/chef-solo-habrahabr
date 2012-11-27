# encoding: utf-8

# Ставим нужные нам пакеты (вручную мы бы ставили их так: `sudo apt-get install <package_name>`)
package 'ntp'
package 'sysstat'

# Останавливаем и удаляем Apache2, потому что мы будем устанавливать nginx
package 'apache2.2-bin' do
  action :purge
  options "--force-yes"
end

package 'git'
package 'imagemagick'
package 'memcached'
package 'sqlite3'
package 'vim'
package 'nginx'
package 'apt'

# подключаю другой "рецепт"
include_recipe "mysql::server"

package 'libmysql-ruby'
package 'libmysqlclient-dev'

# таким образом мы можем следовать принципу DRY, вынося все
# изменяющиеся данные в solo.json
mysql_password = node[:mysql][:server_root_password]
mysql_user_name = node[:mysql][:user_name]
mysql_user_password = node[:mysql][:user_password]

execute "create MySQL user" do
  command "/usr/bin/mysql -u root -p#{mysql_password} -D mysql -r -B -N -e \"GRANT ALL PRIVILEGES ON *.* TO '#{mysql_user_name}'@'localhost' IDENTIFIED BY '#{mysql_user_password}' WITH GRANT OPTION;\""
  action :run
  not_if { `/usr/bin/mysql -u root -p#{mysql_password} -D mysql -r -B -N -e \"SELECT COUNT(*) FROM user where User='#{mysql_user_name}'"`.to_i == 1 }
end

hostname = node[:hostname]

# записываем данные в файл
file '/etc/hostname' do
  content "#{hostname}\n"
end

service 'hostname' do
  action :restart
end

# правим /etc/hosts
file '/etc/hosts' do
  content "127.0.0.1 localhost #{hostname}\n"
end

# нужно, чтобы этот каталог существовал
directory "/etc/nginx/sites-available" do
  action :create
end

nginx_config_filename = node[:nginx][:config_filename]

# этой командой мы копируем файл ./cookbooks/dims/files/default/<nginx_config_filename>
# в /etc/ng...
cookbook_file "/etc/nginx/sites-available/#{nginx_config_filename}"

# делаем симлинк
link "/etc/nginx/sites-enabled/#{nginx_config_filename}" do
  to "/etc/nginx/sites-available/#{nginx_config_filename}"
end

file "/etc/nginx/sites-enabled/default" do
  action :delete
end

# этот гем нам нужен для того, чтобы Chef мог создать нам пользователя
chef_gem "ruby-shadow"

# копируем файл `deploy_sudo` из нашей "поваренной книги" и ставим ему правильные права
cookbook_file '/etc/sudoers.d/deploy_sudo' do
  mode "0440"
end

# создаем пользователя
user "deploy" do
  comment "Rails App Deployer"
  gid "users"
  home "/home/deploy"
  shell "/bin/bash"
  # пароль должен быть уже предварительно зашифрован
  # командой `openssl passwd -1 "p@$$w0rd"`
  password node[:deploy_user][:encoded_password]
end

# создаем каталог с уже нужными правами и владельцем
directory "/home/deploy/.ssh" do
  action :create
  owner "deploy"
  mode "700"
  recursive true
end

# копирую заранее созданные ключи для SSH
cookbook_file "/home/deploy/.ssh/id_rsa" do
  mode "0600"
end
cookbook_file "/home/deploy/.ssh/id_rsa.pub" do
  mode "0644"
end

# Для того, чтобы сгенерировать эти ключи:
# 
# username = "deploy"
# execute "generate ssh skys for #{username}." do
#   user username
#   creates "/home/#{username}/.ssh/id_rsa.pub"
#   command "ssh-keygen -t rsa -q -f /home/#{username}/.ssh/id_rsa -P \"\""
# end

app_name = node[:app_name]

# создаю структуру каталогов для своего приложения
['/releases', '/shared/sockets', '/shared/log', '/shared/public', '/shared/pids'].each do |catalog|
  directory "/var/www/#{app_name}#{catalog}" do
    action :create
    user "deploy"
    group "users"
    recursive true
    mode "0755"
  end
end

# в случае с Rails нужно убедиться, что файл лога имеет определенные права
file "/var/www/#{app_name}/shared/log/production.log" do
  mode "0666"
end

# эта команда нужна для того, чтобы избежать ошибок при запуске программ,
# использующих C++ Boost, например, MongoDB
execute "Generate locales (to avoid 'boost' lib errors)" do
  command "locale-gen en_US.UTF-8 ru_RU.UTF-8"
end

# перезапускаем nginx, чтобы он подхватил новый конфиг
service 'nginx' do
  action :restart
end