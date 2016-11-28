#!/bin/bash

# Auto install Spark Streaming and configure the environment
#
# Author: Shijie Sun
# Email: septimus145@gmail.com
# July, 2016

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

# Download the spark
spark_path="/usr/share/spark/"
wget http://www-eu.apache.org/dist/spark/spark-1.6.2/spark-1.6.2-bin-hadoop2.6.tgz
sudo tar -xvzf spark-1.6.2-bin-hadoop2.6.tgz -C /usr/share
sudo mv /usr/share/spark-1.6.2-bin-hadoop2.6 /usr/share/spark
rm spark-1.6.2-bin-hadoop2.6.tgz
echo "spark.io.compression.codec    lzf" | sudo tee --append /usr/share/spark/conf/spark-defaults.conf

#sudo mkdir -p /var/spark_tmp
#sudo cp ./entry.dat /var/spark_tmp/
echo Success
exit 0
