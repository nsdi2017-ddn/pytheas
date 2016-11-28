#!/bin/bash

# Auto install httpd and configure the environment
#
# Author: Shijie Sun
# Email: septimus145@gmail.com
# August, 2016

if [[ $UID != 0  ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Install editor
sudo apt-get update
which vim >&/dev/null || sudo apt-get install -y vim
which tmux >&/dev/null || sudo apt-get install -y tmux

# Install jdk and maven
which javac >&/dev/null || sudo apt-get install -y default-jdk
which mvn >&/dev/null || sudo apt-get install -y maven
if [ -z $JAVA_HOME ]; then
  JAVA_HOME=$(sudo update-java-alternatives -l | head -n 1 | sed -e 's/ \+/ /g' | cut -f3 -d' ')
  echo JAVA_HOME=\"$JAVA_HOME\" | sudo tee --append /etc/environment
  export JAVA_HOME=$JAVA_HOME
fi

# Install httpd and php5
sudo apt-get install -y apache2 php libapache2-mod-php

# Configure the httpd
#sudo cp update.php /var/www/html
#sudo cp player.php /var/www/html
#sudo cp player_EG.php /var/www/html
sudo mkdir /var/www/info
sudo chmod 777 /var/www/info
sudo sed -i -e "s/\(KeepAlive \).*/\1"Off"/" \
    /etc/apache2/apache2.conf
sudo service apache2 reload

echo Success
exit 0
