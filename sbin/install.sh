#!/usr/bin/env bash


echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Setting up $2 : $HOST"
echo "**************************************************************************"
echo $0 $@
echo ""

if [ "$#" -lt 3 ]; then
    echo "Error: need at least three arguments"
    echo "Format: sh setup_install.sh <host> <cluster> <bin_dir>"
    exit 1;
fi

HOST=$1
SSH=junchenj@$HOST
PRE=-o\ "StrictHostKeyChecking=no"
LOCAL_BIN_DIR=$3
FRONT_SERVER=front_server
SPARK=spark
KAFKA=kafka
TRACE=trace

REMOTE_USER_ROOT="/users/junchenj"
REMOTE_LOG_ROOT="/users/junchenj/log"

echo "======== ${HOST}:     Creating ${REMOTE_USER_ROOT} ========"
ssh $PRE $SSH 'mkdir -p '$REMOTE_USER_ROOT
ssh $PRE $SSH 'mkdir -p '$REMOTE_LOG_ROOT

[ -z $SPARK ] || {
    echo "======== ${HOST}:     Setting up spark ========"
    ssh $PRE $SSH 'mkdir -p '$REMOTE_USER_ROOT/$SPARK
    scp $PRE $LOCAL_BIN_DIR/'spark_deploy.sh' $SSH:$REMOTE_USER_ROOT/$SPARK
    scp $PRE $LOCAL_BIN_DIR/'config.properties' $SSH:$REMOTE_USER_ROOT/$SPARK
    ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$SPARK'; sudo bash spark_deploy.sh'
}

[ -z $KAFKA ] || {
    echo "======== ${HOST}:     Setting up kafka ========"
    ssh $PRE $SSH 'mkdir -p '$REMOTE_USER_ROOT/$KAFKA
    scp $PRE $LOCAL_BIN_DIR/'kafka_deploy.sh' $SSH:$REMOTE_USER_ROOT/$KAFKA
    scp $PRE $LOCAL_BIN_DIR/'zookeeper.properties' $SSH:$REMOTE_USER_ROOT/$KAFKA
    IP=$(ssh $PRE $SSH getent hosts \$\(hostname\) | awk '{print $1}')
    echo "Got IP = $IP"
    ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$KAFKA'; sudo ./kafka_deploy.sh '$IP' 1'
}

[ -z $FRONT_SERVER ] || {
    echo "======== "$HOST":     Setting up front_server ========"
    ssh $PRE $SSH 'mkdir -p '$REMOTE_USER_ROOT/$FRONT_SERVER
    scp $PRE $LOCAL_BIN_DIR/'frontserver_deploy.sh' $SSH:$REMOTE_USER_ROOT/$FRONT_SERVER
    ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$FRONT_SERVER'; sudo ./frontserver_deploy.sh'
}

echo "**************************************************************************"
echo "*       Finish setup of $2 : $HOST"
echo "**************************************************************************"

#echo "**************************************************************************"
#echo "*       Done Setting up on "$host
#echo "*       NEXT STEP: Open 6 new windws"
#echo "*                  Run 'sh run_zookeeper.sh "$host"' in 1st window"
#echo "*                  Run 'sh run_kafka.sh "$host"' in 2nd window"
#echo "*                  Run 'sh run_groupmanager.sh -f "$host" -p' in 3rd window"
#echo "*                  Run 'sh run_communicator.sh -f "$host" -b backendhost -p' in 4th window"
#echo "*                  Run 'sh run_decisionmaker.sh -f "$host" -p' in 5th window"
#echo "*                  Run 'sh run_uploadtrace.sh "$host" tracefile -p' in 6th window"
#echo "**************************************************************************"
#echo ""
#echo ""
#echo ""
