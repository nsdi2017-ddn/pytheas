#/bin/bash

Host=""

if [ "$#" -lt 2 ]; then
echo "Error: need at least one argument"
echo "Format: sh run_decisionmaker.sh [-option] --frontend <host>"
exit
fi

Rebuild=false

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "Format: sh run_decisionmaker.sh [-option] -f <host>"
            echo "options:"
            echo "-h --help     show brief help"
            echo "-p --package  repackage before running"
            echo "-f --frontend set frontend host"
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
LOG_FILE=$REMOTE_LOG_ROOT"/log_decisionmaker"


echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Starting DecisionMaker on "$Host
echo "**************************************************************************"

if [ "$Rebuild" = true ] ; then
scp $PRE -r $FRONTEND_HOME/$SPARK/DecisionMaker $SSH:$REMOTE_USER_ROOT/$SPARK/
ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$SPARK'/DecisionMaker; mvn package > '$LOG_FILE
fi

##### get kafka pointer of the frontend
ssh $PRE $SSH  /sbin/ifconfig br-flat-lan-1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' > temp
FrontendKafka=$(cat temp)':9092'
FrontendZookeeper=$(cat temp)':2181'
rm temp
echo "Frontend Kafka="$FrontendKafka" / "$FrontendZookeeper

CONF=$REMOTE_USER_ROOT/$SPARK"/config.properties"
##### get updateTopic
TopicKey='updateTopic'
ssh $PRE $SSH "cat $CONF | grep $TopicKey'=' | cut -d= -f2 | awk '{ print \$1}'" > temp
TOPIC=$(cat temp)
rm temp

ssh $PRE $SSH "sh -c 'cd $REMOTE_SYS_ROOT/$SPARK; sudo bin/spark-submit --class frontend.DecisionMaker --master local --executor-memory 30G --total-executor-cores 1 --executor-cores 1 ~/spark/DecisionMaker/target/DecisionMaker-1.0-SNAPSHOT.jar $FrontendKafka $TOPIC decision 0.7 10 > $LOG_FILE 2>&1 &'"


echo "**************************************************************************"
echo "*       Done DecisionMaker on "$Host
echo "**************************************************************************"
echo ""
echo ""
echo ""

