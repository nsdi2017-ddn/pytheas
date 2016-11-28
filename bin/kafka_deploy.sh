#!/bin/bash

# Auto install Kafka and configure the environment
#
# Author: Shijie Sun
# Email: septimus145@gmail.com
# July, 2016

if [ $# -lt 2  ]; then
  echo "Usage: sudo $0 <host_list> <host_number>"
  echo -e "\n\t<host_list> is all IP addresses of kafka servers, separated by comma"
  echo -e "\t<host_number> is the sequence number of current host in host_list"
  echo -e "\ne.g. if want to run kafka with two hosts(10.1.1.2,10.1.1.3) and IP of current host is 10.1.1.3. Then host_list=\"10.1.1.2,10.1.1.3\", host_number=2\n"
  exit 1
fi

if [[ $UID != 0  ]]; then
  echo "Please run this script with sudo:"
  echo "sudo $0 $*"
  exit 1
fi

host_list=(${1//,/ })

# Install editor
sudo apt-get update
which vim >&/dev/null || sudo apt-get install -y vim
which tmux >&/dev/null || sudo apt-get install -y tmux

# Install jre
which java >&/dev/null || sudo apt-get install -y default-jre
if [ -z $JAVA_HOME ]; then
  JAVA_HOME=$(sudo update-java-alternatives -l | head -n 1 | sed -e 's/ \+/ /g' | cut -f3 -d' ')
  echo JAVA_HOME=\"$JAVA_HOME\" | sudo tee --append /etc/environment
  export JAVA_HOME=$JAVA_HOME
fi

# Download kafka
kafka_path="/usr/share/kafka/"
wget http://www-eu.apache.org/dist/kafka/0.10.0.0/kafka_2.11-0.10.0.0.tgz
sudo tar -xvzf kafka_2.11-0.10.0.0.tgz -C /usr/share
sudo mv /usr/share/kafka_2.11-0.10.0.0 /usr/share/kafka
rm kafka_2.11-0.10.0.0.tgz

# Configure the zookeeper
cat zookeeper.properties | sudo tee --append $kafka_path/config/zookeeper.properties
i=0
while [ $i -lt ${#host_list[@]}  ]
do
    server_info="server."$(( i+1  ))"="${host_list[$i]}":2888:3888"
    echo $server_info | sudo tee --append $kafka_path/config/zookeeper.properties
    (( i++ ))
done
sudo mkdir -p /tmp/zookeeper
sudo touch /tmp/zookeeper/myid
echo $2 | sudo tee --append /tmp/zookeeper/myid

# Configure the kafka
znodes=${host_list[0]}":2181"
i=1
while [ $i -lt ${#host_list[@]}  ]
do
    znodes=$znodes","${host_list[$i]}":2181"
    (( i++ ))
done
sudo sed -i -e "s/\(broker.id=\).*/\1$2/" \
    -e "s/\(zookeeper.connect=\).*/\1$znodes/" $kafka_path/config/server.properties
echo "delete.topic.enable=true" | sudo tee --append $kafka_path/config/server.properties

echo Success
exit 0
