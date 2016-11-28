#/bin/bash



SSH="junchenj@"$1
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


if [ "$#" -ne 2 ]; then
echo "Error: need exactly two arguments"
echo "Format: sh run_uploadtrace.sh host tracefile"
exit
fi

echo ""
echo ""
echo ""
echo "**************************************************************************"
echo "*       Starting Uploading trace to "$1
echo "**************************************************************************"

Tracefile=$2
TraceUnsorted='trace_raw.txt'
scp $PRE -r $FRONTEND_HOME/$TRACE $SSH:$REMOTE_USER_
scp $PRE -r $Tracefile $SSH:$REMOTE_USER_ROOT/$TRACE/$TraceUnsorted

TraceSorted='trace_sort.txt'
ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$TRACE/'; ./tracesort.py '$TraceUnsorted' '$TraceSorted
ssh $PRE $SSH  /sbin/ifconfig br-flat-lan-1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}' > temp
FrontendIp=$(cat temp)
rm temp

scp $PRE httpd_deploy.sh $SSH:$REMOTE_USER_ROOT/$FRONT_SERVER/
ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$FRONT_SERVER/'; sudo sh httpd_deploy.sh'

ssh $PRE $SSH -t 'cd '$REMOTE_USER_ROOT/$TRACE/'; ./trace_parser.py http://'$FrontendIp'/player.php '$TraceSorted

echo "**************************************************************************"
echo "*       Done Uploading trace to "$1
echo "**************************************************************************"
echo ""
echo ""
echo ""

