#!/bin/bash

# This runs as root on the server

chef_binary=/usr/local/rvm/gems/ruby-1.9.3-p327/gems/chef-10.16.2/bin/chef-solo

# Are we on a vanilla system?
if ! test -f "$chef_binary"; then

    DEFAULT_RUBY_VERSION="1.9.3-p327"
    sudo apt-get update
    sudo apt-get -y install \
        curl git-core bzip2 build-essential zlib1g-dev libssl-dev \
        autoconf libtool libxml2-dev libxslt-dev libreadline-dev \
        libsqlite3-dev zlib1g-dev libyaml-dev openssl libreadline6 \
        libreadline6-dev zlib1g sqlite3 libc6-dev ncurses-dev \
        automake bison subversion pkg-config

    if [ -x /usr/local/rvm/bin/rvm ]; then 
      echo "RVM Found... Nothing to do";
    else
      echo "Installing RVM";
      
      curl -o /tmp/rvm-installer -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer
      chmod +x /tmp/rvm-installer
      sudo /tmp/rvm-installer stable
      has_rvm=`groups |grep -c rvm`; 
      if [ "$has_rvm" == "0" ]; then 
        sudo /usr/sbin/usermod -G `groups | tr ' ' ','`,rvm $USER
      fi
    fi

    source /etc/profile

    has_ruby_version=`rvm list | grep -c $DEFAULT_RUBY_VERSION`
    rvm pkg install readline
    rvm pkg install libyaml
    # rvm pkg install zlib
    # rvm pkg install openssl
    if [ $has_ruby_version == "0" ]; then
      rvm install $DEFAULT_RUBY_VERSION
      rvm alias create default $DEFAULT_RUBY_VERSION
    else
      echo "RVM has already installed Ruby v$DEFAULT_RUBY_VERSION"
    fi

    gem install chef --no-ri --no-rdoc
fi &&

/usr/local/rvm/rubies/default/bin/ruby "$chef_binary" -c solo.rb -j solo.json