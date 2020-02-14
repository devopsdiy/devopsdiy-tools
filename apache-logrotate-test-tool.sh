#!/bin/bash

# Created: 2019.12.22  4:28 PM

# What does it do?
# Tool to prep Apache log files for logrotate testing. Script will find access.log and error.log files in /var/www/example.com/. If access.log is less than 11MB, the file size will be increased to 11MB by adding random text. If error.log is less than 3MB, the file size will be increased to 3MB by adding random text.

# What is it?
# Shell script for use on CentOS 7 server.

# Technologies used
# Bash shell script

# Goal of the project
# Wanted to artificially increase file size of access (11MB) and error (3MB) logs to test if logrotate configuration change is working.

# Stage of the project
# Complete

# Known issues or things that are not properly done
# If access or error log is deleted (which this script does not do) manually, you will need to restart Apache service once or twice for the log file to be recreated. And verify the deleted log file was recreated. If this is not done, no log file will be available to accept incoming logs.

# Specific things to look for
# Do not run this on Production Web server as it will delete Apache logs.

# How to run it
## On CentOS 7, as root
# ~/bin/script.sh


########################################################    

website="devopsdiy.xyz"   # This value should be changed to match your domain name.

folder_search="/var/www/${website}/"


echo -e "\n#######################################################"
echo "This script will delete Apache logs on this server."
echo -e "\nRun this script  ONLY  if you are ok with  LOSING  the content of existing Apache log files in "/var/www/${website}/" on this server."
echo -e "#######################################################\n"
read -p "Answer y if you want to proceed. Answer n if you want to cancel.: " -n 1 -r
echo  
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "This script aborted with no change made.\n"
    exit 1
    
fi

echo -e "This script will proceed.\n"


function func_curl() {
curl https://${website} > /dev/null 2>&1
curl https://${website}/abc123 > /dev/null 2>&1
curl https://devel.${website} > /dev/null 2>&1
curl https://devel.${website}/abc123 > /dev/null 2>&1
curl https://qatest.${website} > /dev/null 2>&1
curl https://qatest.${website}/abc123 > /dev/null 2>&1
}

function func_basename() {
find ${folder_search} -type f \( -name access.log -o -name error.log \) -print0 | while read -d $'\0'  file_found
do
    filesize=$(stat -c%s "${file_found}")
    folder_name=$(dirname ${file_found})
    file_name=$(basename ${file_found})


    echo "$folder_name/$file_name"
    # Create access.log-filler to use as filler for access.log
    if [ "${file_name}" == "access.log" ] && [ $filesize -lt 10000000  ] ; then
        # head -n10 ${folder_name}/access.log > ${folder_name}/access.log-filler
        base64 /dev/urandom | head -c 11000000 > ${folder_name}/access.log-filler
        cat ${folder_name}/access.log-filler >> ${folder_name}/access.log
        rm -f ${folder_name}/access.log-filler
    fi


    if [ "${file_name}" == "error.log" ] && [ $filesize -lt 3000000  ] ; then
        # head -n10 ${folder_name}/access.log > ${folder_name}/access.log-filler
        base64 /dev/urandom | head -c 3000000 > ${folder_name}/error.log-filler
        cat ${folder_name}/error.log-filler >> ${folder_name}/error.log
        rm -f ${folder_name}/error.log-filler
    fi

done
}


func_curl
func_basename
func_curl
