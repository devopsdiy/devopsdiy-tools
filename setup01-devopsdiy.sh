#!/bin/bash

##########
# notes
##########

# func_log: create a log file to log
# func_firewalld: install/setup firewalld
# func_skel_vim: edit file /etc/skel/.vimrc
# func_root_vim: edit file /root/.vimrc
# func_utc: install ntp service (time service) and configure to use UTC
# func_rpms: install necessary rpms such as vim, wget, screen, etc
# func_adduser: add a new account named `usera` and add to group wheel
# func_adduser_test: add a new account named `testuser1` and add to group wheel
# func_sudoers: give sudo privilege to group wheel
# func_selinux_off: turn off selinux
# func_ansible: install ansible client and create user `ansibleuser` which is added to group wheel
# func_backupadmin: create group backupadmin and add `usera` and `ansibleuser`
# func_network_manager: disable NetworkManager
# func_motd: edit file /etc/motd and insert today's date hostname of the server
# lastly, the server will reboot itself


_user="usera"
_script="$(pwd)/$(basename $0)";
_release=`rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release)`  # ex: 6 or 7
_distro=`more /etc/redhat-release | tr '[A-Z]' '[a-z]' | cut -d' ' -f1`  # ex: centos
_os_ver_arch="${_distro}-${_release}"

_user_key="ssh-rsa PlaceHolderText p@MacBook.local"


# update /etc/skel/.vimrc
function func_skel_vim(){
  _vim_skel_test=`grep set /etc/skel/.vimrc 2> /dev/null | wc -l`

  if [ ${_vim_skel_test} -eq 4 ]; then
    echo -e "\n# /etc/skel/.vimrc already has required settings." | tee -a /${_logger}
  else
cat >>/etc/skel/.vimrc <<EOL
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

set paste
EOL
    echo -e "/vim/skel/.vimrc updated." | tee -a /${_logger}
  fi
}


# update /root/.vimrc
function func_root_vim(){
  _root_vimrc_test=`grep set /root/.vimrc 2> /dev/null | wc -l`
  if [ ${_root_vimrc_test} -eq 4 ]; then
    echo -e "\n# /root/.vimrc already has required settings." | tee -a /${_logger}
  else
cat >>/root/.vimrc <<EOL
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

set paste
EOL
    echo -e "/root/.vimrc updated." | tee -a /${_logger}
  fi
}


# Saves log of this script
function func_log(){
  _today=`date +"%F-%Z"`
  _log_dir="root/logs"
  _logger="${_log_dir}/${_today}.log"

  mkdir /${_log_dir} 2> /dev/null
  echo "#######################" | tee -a /${_logger}
  date -u +"%F--%H-%M-%Z" >> /${_logger}
}


function func_firewalld(){
  yum install -y firewalld
  systemctl start firewalld
  systemctl enable firewalld
  firewall-cmd --zone=public --list-services --permanent
  firewall-cmd --zone=public --permanent  --add-service=https
  firewall-cmd --zone=public --permanent  --add-service=http
  firewall-cmd --reload
  firewall-cmd --list-all | tee -a /${_logger}
}


# Change system time zone to UTC
function func_utc(){
  # Variables for verifying OS and version.
  rm /var/cache/yum/timedhosts.txt 2> /dev/null
  yum clean all
  yum --disableplugin=fastestmirror -y install ntp
#  sleep 2  # needed for ntpd service to start
  rm -f /etc/localtime
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime

  rm -f /etc/sysconfig/clock
cat <<EOM >/etc/sysconfig/clock
UTC=true
EOM

  echo -e "\n`date +%Y-%m-%d--%H-%M-%S-%Z` Server set to use UTC time." | tee -a /${_logger}
  if [[ ${_os_ver_arch} == *"centos-6"* ]]; then
    service ntpd restart
    chkconfig ntpd on
    echo -e "ntpd service started" | tee -a /${_logger}
  elif [[ ${_os_ver_arch} == *"centos-7"* ]]; then     # must be centos_
    systemctl restart ntpd
    systemctl enable ntpd
    echo -e "ntpd service started" | tee -a /${_logger}
  fi
}


# Install often used rpms. Converted to work with CentOS 7 only.
function func_rpms(){
   yum -y install epel-release vim curl wget man screen bind-utils rsync tmux && echo -e "rpms installed"  >> /${_logger}
}


# Grant sudo privilege to 'wheel' group.
function func_sudoers(){
  _wheel_test=`grep '^%wheel' /etc/sudoers | grep NOPASSWD | wc -l`
  if [ ${_wheel_test} -ge 1 ]; then
    echo -e '\n# %wheel group already has sudo privilege.' | tee -a /${_logger}
  else
    echo "Updating /etc/sudoers" | tee -a /${_logger}
    sed -i '/NOPASSWD/a %wheel\      ALL=(ALL)\      NOPASSWD:\ ALL' /etc/sudoers && echo "Granted to wheel group sudo root privilege."
  fi
}


# Add user account and set up ssh key. Add user to 'wheel' group.
function func_adduser(){
  useradd ${_user} 2> /dev/null
  usermod -a -G wheel ${_user} 2> /dev/null
  mkdir /home/${_user}/.ssh 2> /dev/null
  touch /home/${_user}/.ssh/authorized_keys 2> /dev/null

  if grep --quiet '^ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQfYTUuey' /home/${_user}/.ssh/authorized_keys; then
    echo -e "\n# SSH key for ${_user} is already in /home/${_user}/.ssh/authorized_keys.\n" | tee -a /${_logger}
  else
    echo "${_user_key}" >> /home/${_user}/.ssh/authorized_keys && echo -e "Added ${_user} and gave sudo privilege." | tee -a /${_logger}
  fi

  chmod 755 /home/${_user}/.ssh
  chmod 644 /home/${_user}/.ssh/authorized_keys
  chown -R ${_user}: /home/${_user}/.ssh
}


# Add testuser account and set up ssh key. Add user to 'wheel' group.
function func_adduser_test(){
  _user_test=testuser1
  useradd ${_user_test} 2> /dev/null
  usermod -a -G wheel ${_user_test} 2> /dev/null
  mkdir /home/${_user_test}/.ssh 2> /dev/null
  touch /home/${_user_test}/.ssh/authorized_keys 2> /dev/null
  #passwd $_user_test

  if grep --quiet '^ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQfYTUuey' /home/${_user_test}/.ssh/authorized_keys; then
    echo -e "\n# SSH key for ${_user_test} is already in /home/${_user_test}/.ssh/authorized_keys.\n" | tee -a /${_logger}
  else
    echo "${_user_key}" >> /home/${_user_test}/.ssh/authorized_keys && echo -e "Added ${_user_test} and gave sudo privilege." | tee -a /${_logger}
  fi

  chmod 755 /home/${_user_test}/.ssh
  chmod 644 /home/${_user_test}/.ssh/authorized_keys
  chown -R ${_user_test}: /home/${_user_test}/.ssh
}


# Disable selinux
function func_selinux_off(){
  sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config && echo -e "SELinux turned off." | tee -a /${_logger}
}


# Install rpm for Ansible client. Add user account for Ansible and set up ssh key. Add user to 'wheel' group.
function func_ansible() {
  _user_ansible="ansibleuser"
  yum install -y ansible
  useradd ${_user_ansible} 2> /dev/null
  usermod -aG wheel ${_user_ansible} 2> /dev/null
  mkdir /home/${_user_ansible}/.ssh 2> /dev/null
  touch /home/${_user_ansible}/.ssh/authorized_keys 2> /dev/null

  if grep --quiet '^ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFc' /home/${_user_ansible}/.ssh/authorized_keys; then
    echo -e "\n# public key for ${_user_ansible} is already in /home/${_user_ansible}/.ssh/authorized_keys." | tee -a /${_logger}
  else
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFcFcKOi8yNuE05UJbe32UnXL0SMdthHlbhGrH+gAqH2D+2SgrBj0ynOg+oMIIiJntjSju84tTOYPs/snh8O3qYzXEB4ET8qupf7azyjhzJIR9PhO8W78r0rzhFBWyrhdQ4UpaHVElCth9LMS1YSVnc4zw2jSbuW1ZEENYLU4ieARuqVU+sdH//WfZyUGKu6bWATpGMqKs/3teJP7+S+4gcpjDQtbX7m4oEM6gr0VkModUuRp4KSJuT/okxQuTt2z4/U+yygM/F91sV38Z87L6RkYL9Zzzt4qR0kXVCAO3YfuOPkncfsvURkZdP6mTICX11Vc49zrDfRQx91iLDQRf paul@Mac-542696cebd0b" >> /home/${_user_ansible}/.ssh/authorized_keys && echo -e "Ansible client installed." | tee -a /${_logger}
  fi

  chmod 755 /home/${_user_ansible}
  chmod 644 /home/${_user_ansible}/.ssh/authorized_keys
  chown -R ${_user_ansible}: /home/${_user_ansible}/.ssh
}


# Create group backupadmin for handling backups. Add users ${_user} and ${_user_ansible} to the group
function func_backupadmin(){
  _groupname="backupadmin"
  groupadd ${_groupname} 2> /dev/null
  usermod -aG ${_groupname} ${_user} 2> /dev/null
  usermod -aG ${_groupname} ${_user_ansible} 2> /dev/null
}


# Stop and disable NetworkManager service on CentOS 7
function func_network_manager(){
if [[ ${_os_ver_arch} == *"centos-7"* ]]; then
  systemctl stop NetworkManager
  systemctl disable NetworkManager
  echo -e "NetworkManager service on CentOS 7 stopped and disabled." | tee -a /${_logger}
fi
}


# Populate /etc/motd.
function func_motd(){
  if grep --quiet '^Installed' /etc/motd; then
    echo -e "\n# Not updating /etc/motd now as it already has content.\n# You can always update it manually later.\\n" | tee -a /${_logger}
  else
    echo -e "\nSetting up MOTD. \n" | tee -a /${_logger}
    echo "==========" >> /etc/motd
    echo "Installed `date +"%F"`" >> /etc/motd
    echo "`hostname -f`" >> /etc/motd
    echo "==========" >> /etc/motd
    echo -e "/etc/motd updated." | tee -a /${_logger}
  fi
}


# To self delete this script after running it.
function func_selfDelete(){
  rm -f ${_script}
}


# trap func_selfDelete SIGINT SIGTERM   # for Self deleting of this script.


func_log
# func_firewalld
func_skel_vim
func_root_vim
func_utc
func_rpms
func_adduser
func_adduser_test
func_sudoers
func_selinux_off
func_ansible   
func_backupadmin
func_network_manager
func_motd
func_selfDelete
bash -c 'sleep 3 && reboot'  # This allows self delete of the script AND OS reboot immediately after.
