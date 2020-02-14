#!/bin/bash

# Created: 
# 2020.01.09

# What does it do?
# Create user jenkagent and copy in SSH public key from user 'jenkins' from Jenkins server. This script will configure a CentOS server so that user jenkins on a Jenkins server can ssh/scp and gain sudo privilege.

#######################################################

userJenkinsAgent="jenkagent"
userJenkinsAgentSshPubKey="update-this"
# Above userJenkinsAgentSshPubKey pub key should be from user `jenkins` on Jenkins server.

scriptName="$(pwd)/$(basename $0)";

# For self deleting of the script after running.
# Note if the script is in /root/bin/_this_script_.sh and you execute it from a different directory (ex: /root/), self delete will not work.
function selfDelScript(){
  echo "${scriptName} will self delete." | tee -a /${logFile}
  echo "" >> /${logFile}
  rm -f /${scriptName};
 }


# Log output of this script
function func_log(){
  todayTimezone=`date +"%F-%Z"`
  logDirectory="root/logs"
  logFile="${logDirectory}/${todayTimezone}.log"  

  mkdir /${logDirectory} 2> /dev/null
  echo "########## `date -u +"%F--%H-%M-%Z"` ##########" | tee -a /${logFile}
}


# This function is used so that ${userJenkinsAgent} user can gain sudo privilege.
function func_sudoers() {
  wheelNoPassCount=`grep "^%wheel" /etc/sudoers | grep "NOPASSWD: ALL" | wc -l`
  if [ ${wheelNoPassCount} -ge 1 ]; then
    echo -e '\nwheel group already has sudo privilege. No change made to /etc/sudoers' | tee -a /${logFile}
  else
    echo "Updating /etc/sudoers" | tee -a /${logFile}
    sed -i 's/^# %wheel/%wheel/g' /etc/sudoers && echo "Granted to wheel group sudo root privilege." | tee -a /${logFile}
  fi
}


function func_jenkins_user() {
  checkUserExist=`getent passwd ${userJenkinsAgent} | wc -l`

  if [ $checkUserExist -eq 1 ]; then
    echo "User ${userJenkinsAgent} already exists, so nothing related to user ${userJenkinsAgent} will be changed. If this is not what you expected, please review /etc/passwd and authorized_keys of user ${userJenkinsAgent}." | tee -a /${logFile}
  else
    useradd ${userJenkinsAgent} 2> /dev/null
    usermod -aG wheel ${userJenkinsAgent} 2> /dev/null
    mkdir /home/${userJenkinsAgent}/.ssh 2> /dev/null
    touch /home/${userJenkinsAgent}/.ssh/authorized_keys 2> /dev/null

    echo "${userJenkinsAgentSshPubKey}" >> /home/${userJenkinsAgent}/.ssh/authorized_keys && echo -e "User ${userJenkinsAgent} has been created with necessary change in authorized_keys." | tee -a /${logFile}

    chmod 755 /home/${userJenkinsAgent}
    chmod 700 /home/${userJenkinsAgent}/.ssh
    chmod 644 /home/${userJenkinsAgent}/.ssh/authorized_keys
    chown -R ${userJenkinsAgent}: /home/${userJenkinsAgent}/.ssh

    func_sudoers
  fi
}


function func_log_blank() {
  echo "" | tee -a /${logFile}
}

trap rmScript SIGINT SIGTERM

func_log
func_jenkins_user
func_log_blank
# selfDelScript  

# selfDelScript is commented out to not self delete this script. All functions are idempotent anyway, and in case script aborts due to user already existing, we'd need to rerun it. 


