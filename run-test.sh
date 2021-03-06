#!/bin/bash
# This file is part of Deemon.

# Deemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Deemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Deemon.  If not, see <http://www.gnu.org/licenses/>.

set -e

if [ $# -ne 8 ]; then
    echo "usage: ./run-test.sh <vm-name> <vm-ip> <test-name> <start-state-name> <selenese-test-file> <firefox-instance> <mosgi-port> <vilanoo-port>"
    exit 1
fi


#python="/usr/local/lib/python2.7.11/bin/python"
python="/usr/bin/python"
vm_name=$1
guest_ip=$2
base_url="http://${guest_ip}"
test_name=$3
start_state_name=$4
selenese_test_file=$5
firefox_instance=$6
mosgi_start_relative="./mosgi/src/run-mosgi.lisp"
vilanoo_start_relative="./vilanoo/src/"
vilanoo_folder="${HOME}/.vilanoo/"
timestamp=`date '+%Y%m%d%H%M'`
db_postfix=".db"
log_postfix=".log"
mosgi_port=$7
vilanoo_listen_port=$8
vilanoo_db_path="${vilanoo_folder}${test_name}-${timestamp}-vilanoo${db_postfix}"
mosgi_db_path="${vilanoo_folder}${test_name}-${timestamp}-mosgi${db_postfix}"
vilanoo_log_path="${vilanoo_folder}${test_name}-${timestamp}-vilanoo${log_postfix}"
mosgi_log_path="${vilanoo_folder}${test_name}-${timestamp}-mosgi${log_postfix}"
screenshot_path="${vilanoo_folder}${test_name}-${timestamp}-screenshot/"
selense_log_path="${vilanoo_folder}${test_name}-${timestamp}-selenese${log_postfix}"

tout=10


#default values for bitnami but else these need to become variables
inter_com_port=8844

mosgi_php_session_folder="/opt/bitnami/php/tmp/"
mosgi_xdebug_trace_file="/tmp/xdebug.xt"
mosgi_listen_interface="127.0.0.1"
mosgi_root_user="root"
mosgi_root_pwd="bitnami"


echo "Creating screnshot folder..."
mkdir -p $screenshot_path

#check if vm is already running
#yes -> error
#no  -> restore virgin snapshot
if vboxmanage list vms | grep --quiet "\"${vm_name}\""; then
    
    if vboxmanage list runningvms | grep --quiet "\"${vm_name}\""; then
    echo "test vm ${vm_name} is currently running - shut down before trying again with using die .vdi and polesno.sh"
    exit 1
    else
    echo "restoring snapshot"
    echo `vboxmanage snapshot ${vm_name} restore ${start_state_name}`
    echo "starting up machine"
    echo `vboxmanage startvm ${vm_name} --type headless`
    echo "everything done"
    fi
    
else
    echo "machine ${vm_name} is unknown"
    exit 1
fi


#setup mosgi_db_path
db_dump_schema="./data/DBSchemaDump.sql"
cat ${db_dump_schema} | sqlite3 ${mosgi_db_path}


#start vm"
echo "waiting for guest to finish starting up..."
sleep 4

echo "command:"
TMUX_SESSION=`echo ${test_name} | tr . _dot_`
echo tmux new -s ${TMUX_SESSION} "sbcl --dynamic-space-size 10000 --noinform --non-interactive --load ${mosgi_start_relative} --port ${mosgi_port} -P ${mosgi_php_session_folder} -x ${mosgi_xdebug_trace_file} -i ${mosgi_listen_interface} -t ${guest_ip} -r ${mosgi_root_user}  -c ${mosgi_root_pwd} -s ${mosgi_db_path} > >(tee ${mosgi_log_path}) 2> >(tee ${mosgi_log_path}); sleep 10" \; \
                                 split-window -h "sleep 8 ; cd ${vilanoo_start_relative}; ${python} vilanoo2.py -w $tout -p ${vilanoo_listen_port} -P ${mosgi_port} -s ${vilanoo_db_path} -S ${selenese_test_file} -l ${selense_log_path} --selenese-args \"--firefox ${firefox_instance} --baseurl ${base_url} --height 2048 --width 2048\" > >(tee ${vilanoo_log_path}) 2> >(tee ${vilanoo_log_path}); sleep 30" \; attach \;
echo "..."
tmux new -s ${TMUX_SESSION} "sbcl --dynamic-space-size 10000 --noinform --non-interactive --load ${mosgi_start_relative} --port ${mosgi_port} -P ${mosgi_php_session_folder} -x ${mosgi_xdebug_trace_file} -i ${mosgi_listen_interface} -t ${guest_ip} -r ${mosgi_root_user}  -c ${mosgi_root_pwd} -s ${mosgi_db_path} > >(tee ${mosgi_log_path}) 2> >(tee ${mosgi_log_path}); sleep 10" \; \
                                 split-window -h "sleep 20 ; cd ${vilanoo_start_relative}; ${python} vilanoo2.py -w $tout -p ${vilanoo_listen_port} -P ${mosgi_port} -s ${vilanoo_db_path} -S ${selenese_test_file} -l ${selense_log_path} --selenese-args \"--firefox ${firefox_instance} --baseurl ${base_url} --height 2048 --width 2048 -S ${screenshot_path}\" > >(tee ${vilanoo_log_path}) 2> >(tee ${vilanoo_log_path}); sleep 30" \; attach \;


#./vilanoo-run-checker.sh ${mosgi_log_path} ${vilanoo_log_path} ${selense_log_path}


echo `vboxmanage controlvm ${vm_name} poweroff`
