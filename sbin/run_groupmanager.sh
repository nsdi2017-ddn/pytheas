#/bin/bash

Host=""
KafkaNode=""
Logic=""

if [ "$#" -lt 6 ]; then
echo "Error: need at least six arguments"
echo "Format: sh run_groupmanager.sh [-option] --logic logic --frontend host --kafka kafkanode"
exit
fi

Rebuild=false

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "Format: sh run_groupmanager.sh [-option] host"
            echo "options:"
            echo "-h --help     show brief help"
            echo "-p --package  repackage before running"
            echo "-f --frontend set frontend host"
            echo "-l --logic    set logic type (EG/UCB)"
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
	 -k|--kafka)
            KafkaNode=$2
            shift
            ;;
        -l|--logic)
            Logic=$2
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
SSHKAFKA="junchenj"@$KafkaNode
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
LOG_FILE=$REMOTE_LOG_ROOT"/log_groupmanager"


echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Starting GroupManager on "$Host
echo "**************************************************************************"

if [ "$Rebuild" = true ] ; then
scp $PRE -r $FRONTEND_HOME/$FRONT_SERVER/GroupManager $SSH:$REMOTE_USER_ROOT/$FRONT_SERVER/
ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$FRONT_SERVER'/GroupManager; mvn package > '$LOG_FILE
fi

ssh $PRE $SSHKAFKA  /sbin/ifconfig br-flat-lan-1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' > temp
KafkaIp=$(cat temp)
echo "Got IP="$KafkaIp
rm temp
ssh $PRE $SSH "sh -c 'cd $REMOTE_USER_ROOT/$FRONT_SERVER/GroupManager && java -cp target/GroupManager-1.0-SNAPSHOT.jar frontend.GroupManager frontend1 $KafkaIp ../gmConfig $Logic > $LOG_FILE 2>&1 &'"

echo "**************************************************************************"
echo "*       Done GroupManager on "$Host
echo "**************************************************************************"
echo ""
echo ""
echo ""

