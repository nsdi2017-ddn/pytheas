#/bin/bash



SSH="junchenj@"$1
PRE=-o\ "StrictHostKeyChecking=no"

FRONT_SERVER="front_server"
SPARK="spark"
KAFKA="kafka"
TRACE="trace"

REMOTE_USER_ROOT="/users/junchenj"
REMOTE_SYS_ROOT="/usr/share"
REMOTE_LOG_ROOT="/users/junchenj/log"
LOG_FILE=$REMOTE_LOG_ROOT"/log_zookeeper"

if [ "$#" -ne 1 ]; then
echo "Error: need exactly one argument"
echo "Format: sh run_zookeeper.sh host"
exit
fi

echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Running zookeeper on "$1
echo "**************************************************************************"

ssh $PRE $SSH -t 'cd '$REMOTE_SYS_ROOT/$KAFKA'; sudo bin/zookeeper-server-stop.sh'
ssh $PRE $SSH "sh -c 'cd $REMOTE_SYS_ROOT/$KAFKA && sudo nohup bin/zookeeper-server-start.sh config/zookeeper.properties > $LOG_FILE 2>&1 &'"

echo "**************************************************************************"
echo "*       Done zookeeper on "$1
echo "**************************************************************************"
echo ""
echo ""
echo ""

