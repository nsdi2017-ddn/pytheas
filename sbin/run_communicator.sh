#/bin/bash

Host=""
Backend=""

if [ "$#" -lt 4 ]; then
echo "Error: need at least four argument"
echo "Format: sh run_communicator.sh [-option] --frontend host --backend host"
exit
fi

Rebuild=false

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "Format: sh run_communicator.sh [-option] host"
            echo "options:"
            echo "-h --help     show brief help"
            echo "-p --package  repackage before running"
            echo "-f --frontend set frontend host"
            echo "-b --backend  set backend host"
            exit 0
            ;;
        -p|--package)
            Rebuild=true
            shift
            ;;
        -f|--frontend)
            Host=$2
            shift
            ;;
        -b|--backend)
            Backend=$2
            shift
            ;;
        -*)
            echo "invalid option "$1
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

SSH="junchenj@"$Host
PRE=-o\ "StrictHostKeyChecking=no"

if [ -z "${PYTHEAS_HOME}" ]; then
  export PYTHEAS_HOME="$(cd "`dirname "$0"`"/..; pwd)"
fi

FRONTEND_HOME=${PYTHEAS_HOME}/frontend
FRONT_SERVER="front_server"
SPARK="spark"
KAFKA="kafka"
TRACE="trace"

REMOTE_USER_ROOT="/users/junchenj"
REMOTE_SYS_ROOT="/usr/share"
REMOTE_LOG_ROOT="/users/junchenj/log"
LOG_FILE=$REMOTE_LOG_ROOT"/log_communicator"


echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Starting Communicator on "$Host
echo "**************************************************************************"

CONF=$REMOTE_USER_ROOT/$SPARK"/config.properties"

if [ "$Rebuild" = true ] ; then
scp $PRE -r $FRONTEND_HOME/$SPARK/Communicator $SSH:$REMOTE_USER_ROOT/$SPARK/
ssh $PRE $SSH 'cd '$REMOTE_USER_ROOT/$SPARK/Communicator'; mvn package > '$LOG_FILE
fi

##### get kafka pointer of the frontend
ssh $PRE $SSH  /sbin/ifconfig br-flat-lan-1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' > temp
FrontendKafka=$(cat temp)':9092'
FrontendZookeeper=$(cat temp)':2181'
rm temp
echo "Frontend Kafka="$FrontendKafka" / "$FrontendZookeeper

##### get kafka pointer of the frontend
ssh $PRE junchenj@$Backend  /sbin/ifconfig br-flat-lan-1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' > temp
BackendKafka=$(cat temp)':9092'
BackendZookeeper=$(cat temp)':2181'
rm temp
echo "Backend Kafka="$BackendKafka" / "$BackendZookeeper

##### get and add topics
for TopicKey in 'updateTopic' 'uploadTopic' 'decisionTopic' 'subscribeTopic' 'forwardTopic' 'sampleTopic' 'aliveTopic'
do
ssh $PRE $SSH "cat $CONF | grep $TopicKey'=' | cut -d= -f2 | awk '{ print \$1}'" > temp
TOPIC=$(cat temp)
rm temp
ssh $PRE $SSH -t 'cd '$REMOTE_SYS_ROOT/$KAFKA'; sudo bin/kafka-topics.sh --create --zookeeper '$FrontendZookeeper' --topic '$TOPIC' --partition 1 --replication-factor 1'
echo "Added topic "$TopicKey"="$TOPIC
done

ssh $PRE $SSH -t "sed -i 's/frontend1=10.11.10.3:9092/frontend1="$FrontendKafka"/g' "$CONF
ssh $PRE $SSH -t "sed -i 's/backendBrokers=10.11.10.2:9092/backendBrokers="$BackendKafka"/g' "$CONF
ssh $PRE $SSH -t "sed -i 's/frontend2=10.11.10.4:9092//g' "$CONF

ssh $PRE $SSH "sh -c 'cd $REMOTE_SYS_ROOT/$SPARK && sudo bin/spark-submit --class frontend.Communicator --master local --executor-memory 30G --total-executor-cores 1 --executor-cores 1 ~/spark/Communicator/target/Communicator-1.0.jar $CONF > $LOG_FILE 2>&1 &'"

echo "**************************************************************************"
echo "*       Done Communicator on "$Host
echo "**************************************************************************"
echo ""
echo ""
echo ""

