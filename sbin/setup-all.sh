#!/usr/bin/env bash

[ -z $PYTHEAS_HOME ] && export PYTHEAS_HOME=$(cd `dirname $0`/..; pwd)

PYTHEAS_CONF_DIR=${PYTHEAS_HOME}/conf
PYTHEAS_BIN_DIR=${PYTHEAS_HOME}/bin
PYTHEAS_LOG_DIR=${PYTHEAS_HOME}/log
debug=${DEBUG:-1}

mkdir -p $PYTHEAS_LOG_DIR
mkdir -p ${PYTHEAS_LOG_DIR}/setup
rm -rf ${PYTHEAS_LOG_DIR}/setup/*

for frontend in `ls ${PYTHEAS_CONF_DIR}/frontends/frontend-*`; do
    echo "**************************************************************************"
    echo "*       Setting up ${frontend##*/}"
    echo "**************************************************************************"
    machinelist=$(cat $frontend | sed "s/#.*$//;/^$/d")
    for host in $machinelist
    do
        log_file=${PYTHEAS_LOG_DIR}/setup/${frontend##*/}
        echo -e "Setting up $host.\nSee $log_file for log"
        if [[ ${debug} -ne 0 ]]; then
            bash ${PYTHEAS_HOME}/sbin/install.sh $host ${frontend##*/} $PYTHEAS_BIN_DIR | tee -a $log_file
        else
            bash ${PYTHEAS_HOME}/sbin/install.sh $host ${frontend##*/} $PYTHEAS_BIN_DIR >> $log_file
        fi
    done
done
