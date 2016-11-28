#!/usr/bin/env bash

function start_logic_node {
  host=$1
  . "${PYTHEAS_HOME}/sbin/run_decisionmaker.sh" -f $host -p
}

function start_comm_node {
  host=$1
  . "${PYTHEAS_HOME}/sbin/run_communicator.sh" -f $host -b $host -p
}

function start_pubsub_node {
  host=$1
  . "${PYTHEAS_HOME}/sbin/run_zookeeper.sh" $host
  . "${PYTHEAS_HOME}/sbin/run_kafka.sh" $host
}

function start_front_node {
  host=$1
  commnode=$2
  . "${PYTHEAS_HOME}/sbin/run_groupmanager.sh" -l UCB -f $host -k $commnode -p
}



if [ -z "${PYTHEAS_HOME}" ]; then
  export PYTHEAS_HOME="$(cd "`dirname "$0"`"/..; pwd)"
fi

PYTHEAS_CONF_DIR=${PYTHEAS_HOME}/conf
PYTHEAS_BIN_DIR=${PYTHEAS_HOME}/bin

FRONTENDLIST=`cat "${PYTHEAS_CONF_DIR}/frontends"`

for frontend in `echo "$FRONTENDLIST"|sed  "s/#.*$//;/^$/d"`; do
  echo "Setting up $frontend"
  set -f
  MACHINELIST=(${frontend//;/ })
  pubsubnode=${MACHINELIST[0]}
  echo "Starting publish/subcribe node $pubsubnode"
  start_pubsub_node $pubsubnode
  commnode=${MACHINELIST[0]}
  echo "Starting communication node $commnode"
  start_comm_node $commnode
  logicnode=${MACHINELIST[0]}
  echo "Starting computing node $logicnode"
  start_logic_node $logicnode
  for index in "${!MACHINELIST[@]}"; do
    if [ $index -ne 0 ]; then 
        frontnode=${MACHINELIST[$index]}
        echo "Starting front node $frontnode"
        start_front_node $frontnode $commnode
    fi
  done
done

