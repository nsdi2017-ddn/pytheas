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
LOG_FILE=$REMOTE_LOG_ROOT"/log_kafka"

if [ "$#" -ne 1 ]; then
echo "Error: need exactly one argument"
echo "Format: sh run_kafka.sh host"
exit
fi

echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Running kafka on "$1
echo "**************************************************************************"

echo log file $LOG_FILE
ssh $PRE $SSH -t 'cd '$REMOTE_SYS_ROOT/$KAFKA'; sudo bin/kafka-server-stop.sh'
ssh $PRE $SSH "sh -c 'cd $REMOTE_SYS_ROOT/$KAFKA && sudo bin/kafka-server-start.sh config/server.properties > $LOG_FILE 2>&1 &'"

echo "**************************************************************************"
echo "*       Done kafka on "$1
echo "**************************************************************************"
echo ""
echo ""
echo ""

