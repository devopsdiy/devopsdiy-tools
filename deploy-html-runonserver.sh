#!/bin/bash

# Updated: 2019.12.27

# What does it do?  ########################################################
# Goal: This script was created to help automate deploying website content on a web server. 
# Location: Kept and executed ON the web server.
#
# Two options for deploying content:
# 1. Rsync up files to web server and run "deploy-html-runonserver.sh" on web server:
# You will rsync up website content to the web server (folder: /home/_user_/devsite/devopsdiy.xyz/). And then you can run "deploy-html-runonserver.sh -d devel.site.com -s site.com" directly on the web server to deploy content. 
# 2. Check code into a Git repo and trigger a Jenkins job: 
# You will check in code into your Git repo and start a Jenkins job. This in turn will pull code from Git repo onto webserver, and execute "deploy-html-runonserver.sh" saved on the web server. This deploys content to the website.


# What is it?   ########################################################
# Bash script to be executed on web server to deploy website content.


# Technologies used   ########################################################
# Bash script is used. 
# This script is normally used with Git Repo and Jenkins. But it is possible to run only this bash script to deploy website content.


# Goal of the project   ########################################################
# This script was created to make deploying website content on an Apache web server easier.


# Stage of the project  ########################################################
# This script is complete and ready for use.


# Known issues or things that are not properly done   #########################
# None


# Specific things to look for   ###############################################
# Deploying website content to the Production website is only possible with code git tagged with `p`. You can also force deploying rsynced up code to the production website by using "-f y" argument, if necessary.
# You should deploy code still in development (normally rsynced up from macOS to web server) to devel.devopsdiy.xyz only.
# And deploy code for QA (normally code pulled from Git repo) to qatest.devopsdiy.xyz only.


# How to run it  ########################################################
# Option 1:
# To deploy code under development to devel.devopsdiy.xyz:
# 1. On macOS, run below to rsync up files from macOS to web server:
# > rsync --delete -ave ssh ~/codes/devopsdiy.xyz usera@devel.devopsdiy.xyz:~/devsite
# 2. On web server as root, run below to deploy rsynced up content to Document Root of devel.devopsdiy.xyz (used for testing while actively coding)
# > ./deploy-html-runonserver.sh -d devel.devopsdiy.xyz -s devopsdiy.xyz
#
# Option 2:
# To deploy code ready for QA to qatest.devopsdiy.xyz:
# 1. Check in code to git repo.
# 2. Run html-deploy-jenkins.sh on local macOS. This script git tags the code code with "q.yyyymmdd", pushes it to remote git repo, and triggers a Jenkins job.
# 3. Jenkins job executes "deploy-html-runonserver.sh" on web server to finish deploying web site content to qatest.devopsdiy.xyz.
#
# Option 3:
# To deploy code ready for Production to devopsdiy.xyz:
# 1. Check in code to git repo.
# 2. Run html-deploy-jenkins.sh on local macOS. This script git tags the code code with "p.yyyymmdd", pushes it to remote git repo, and triggers a Jenkins job.
# 3. Jenkins job executes "deploy-html-runonserver.sh" on web server to finish deploying web site content to devopsdiy.xyz.


# Arguments: 
#
# -d is for specifying destination domain. Required.
#   (ex: devopsdiy.xyz  or  devel.devopsdiy.xyz  or  qatest.devopsdiy.xyz)
#
# -s is for specifying source folder.     Required. 
#   (ex: devopsdiy.xyz OR devopsdiy.xyz)
#   On web server if "-t" argument is not used, argument -s will be parsed into  /home/_user_/devsite/devopsdiy.xyz/.
#   On web server if "-t p" (or d or q, any git tag) is used, argument -s will be parsed into  /home/_user_/build/devopsdiy.xyz/.
#
# -t is for specifying git tag.        Optional. Expected values are 'd' or 'q' or 'p'.
#   If any of the 3 values (d, q, p) is used with -t, deploy-html-runonserver.sh will pull code from Git repo and publish them.
#   If '-t' is not used, script deploy-html-runonserver.sh will deploy with rsynced up files.
#
# -f is for specifying whether to force deploying rsynced up code to production website. Carefully consider if you really want to use this argument or not.    Optional. Argument is "y" or "n". 
#
# END of  Arguments

########################################################

#####################
# Global variables declaration
#####################
# Array to hold list of folders containing old code
declare oldFolder
declare oldFolderArray

# Variables holding source/dest/rsynced-up-folder.
declare sourceFolder
declare destFolder

declare domainFqdn # /data/www/$domain/${domainFqdn}
declare domain      # /data/www/$domain/${domainFqdn}
declare domainDotCount  # ex value: 1 or 2   Count of dots in ${domainFqdn}
declare gitTag
declare sourceProject  # devopsdiy.xyz or pacificfleet-ww2.info.
declare fromRsync
forceProduction=n   # Option argument to specify whether to force deploying Production code to a domain with 2 or more dots.
topFolder="/var"   # topFolder and webWww combine to show /data/www/ is html files are served from by Apache
webWww="www"  
userName="usera"
userJenkinsAgent="jenkagent"
logDir="/root/logs"
logFile=${logDir}/deploy-$(TZ=":UTC" date +"%Y-%m-%d").log   # /home/_user_/logs/deploy-...


# Date/time stamp
nowMin=$(TZ=":UTC" date +"%Y-%m-%d_%H-%M-%Z")
nowMin=${nowMin}     # timestamp for naming backup files

nowDay=$(TZ=":UTC" date +"%Y-%m-%d")
nowDay=${nowDay}     # timestamp for naming backup files


# ===== Script ======= #
# Documentation for user.
function func_help() {
echo ""
echo "This script requires -d and -s options. . Options -t and -f are optional.";
echo "Examples:"
echo "    ./deploy-html-runonserver.sh -d devopsdiy.xyz -s devopsdiy.xyz -t p  # 1. Deploy production version (code git tagged with p.***) to devopsdiy.xyz"
echo -e "    ./deploy-html-runonserver.sh -d qatest.devopsdiy.xyz -s devopsdiy.xyz -t q   # 2. Deploy QA version (code git tagged with q.***) to qatest.devopsdiy.xyz"
echo -e "    ./deploy-html-runonserver.sh -d devel.devopsdiy.xyz -s devopsdiy.xyz   # 3. Deploy rsynced up files to devel.devopsdiy.xyz"
echo -e "-d: Required.  The target domain you are deploying the website to. Example below:\n    -d devopsdiy.xyz\n    -d qatest.devopsdiy.xyz\n    -d review.devopsdiy.xyz\n\n    This script accepts URLs ending with following\n    .com\n    .org\n    .co\n    .vag\n    .info \n    .xyz\n"
echo -e "-s: Required.  Name of source project folder. Example below:\n    -s devopsdiy.xyz\n "
echo -e "-t: Optional.  Git tag name used for the deployment, which are d, q, or p. You can also use 'r' to indicate deploying with rsyned up files. If this option is left out, -t r will be used by default.\n    NOTE on production version and target domain with 2 or more periods: You normally cannot deploy   Examples below:\n    -t q.20170603\n    -t p.2017.06.03\n    -t r\n"
echo -e "-f  Optional. Optional argument is either y or no. Forces deploying rsynced up code to production website (ex: devopsdiy.xyz). Normally, this option is rarely used. One reason you'd be using this is when Git repo is unavailable for some reason and you must push out code to the production website. Example below:\n    -f y"
exit;
}


while getopts "d:t:s:f:h" opt; do
    case "$opt" in
        d) domainFqdn=$OPTARG
            ;;
        t) gitTagInput=$OPTARG
            ;;
        s) sourceProject=$OPTARG
            ;;
        f) forceProduction=$OPTARG
            ;;
        h) func_help
            ;;
        *) func_help
            ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift


# Check if the 2 required option arguments are given.
function func_check_options(){
    if [[ -z ${domainFqdn} ]] || [[ -z ${sourceProject} ]] ; then
        func_help
    fi
}


function func_domain_check(){
case ${domainFqdn} in
    *.com|*.co|*.org|*.vag|*.info|*.xyz) echo "Verified valid URL was given as an option argument.";;
    *) func_help ;;
esac

echo -e "func_domain_check:domainFqdn \nDestination domain for deployment is:  ${domainFqdn}" >>  ${logFile}
}

# Extracts devopsdiy.xyz from devel.devopsdiy.xyz
function func_domainfqdn_to_domain() {
domainDotCount=$(echo ${domainFqdn} | grep -o "\." | wc -l)
if [[ ${domainDotCount} -eq 1 ]]; then
    domain=${domainFqdn}
    # echo "Domain has only 1 dot.  func_domainfqdn_to_domain:domainDotCount: ${domainDotCount}"
else
    domain=$(echo ${domainFqdn} | rev | cut -f1,2 -d'.' | rev)
    # echo "Domain has 2 or more dots.  func_domainfqdn_to_domain:domainDotCount: ${domainDotCount}"
fi

echo "You specified as destination domain: ${domainFqdn}" | tee -a ${logFile}
}


function func_last_check_production(){

##### show values of variables for test      DEBUGGING
echo "func_last_check_production:domainDotCount ${domainDotCount}"
echo "func_last_check_production:gitTag ${gitTag}"
echo "func_last_check_production:forceProduction ${forceProduction}"
echo "func_last_check_production:gitTag First character ${gitTagInput:0:1}"
echo "func_last_check_production:gitTagInput  ${gitTagInput}"


if [[ ${domainDotCount} -ge 2 ]] && [[ ${gitTagInput:0:1} == "p" ]] && [[ ${forceProduction} != "y" ]]; then
    echo "#################################################"
    echo -e "You tried to deploy production tagged code to a domain with 2 dots, which is normally not you want to do.\nCancellnig deployment."
    echo "#################################################\n"
    func_help
elif [[ ${domainDotCount} == 1 ]] && [[ ${gitTagInput:0:1} != "p" ]] && [[ ${forceProduction} != "y" ]]; then
    echo "#################################################"
    echo -e "You tried to deploy non-production code to a domain with 1 dot, which is normally not what you want to do.\nCancelling deployment"
    echo "#################################################\n"
    func_help
fi






# if [[ ${domainDotCount} -ge 2 ]] && [[ ${gitTag} == "p" ]] && [[ ${forceProduction} != "y" ]]; then
#     echo "#################################################"
#     echo -e "You tried to deploy production tagged code to a domain with 2 dots, which probably not you want to do.\nCancellnig deployment."
#     echo "#################################################\n"
#     func_help
# elif [[ ${domainDotCount} == 1 ]] && [[ ${gitTag} != "p" ]] && [[ ${forceProduction} != "y" ]]; then
#     echo "#################################################"
#     echo -e "You tried to deploy non-production code to a domain with 1 dot, which is normally not what you want to do.\nCancelling deployment"
#     echo "#################################################\n"
#     func_help
# fi








}


# Verify source project name matches destination website's name
function func_verify_website_sourcename() {
# compare destination website and source project name
domainDotCount=$(echo ${domainFqdn} | grep -o "\." | wc -l)
lastOf2Website=$(echo ${domainFqdn} | awk -F "." '{print $(NF-1),".",$NF}' | sed 's/ //g')
if [[ ${lastOf2Website} != ${sourceProject} ]]; then
    echo "#################################################"
    echo -e "Below 2 do not match. Aborting the script.\n"
    echo -e "Source Project name' and last two fields of destination website (ex: devopsdiy.xyz or devel.devopsdiy.xyz)"
    echo -e "#################################################\n"    
    func_help
fi

if [[ ${domainFqdn} == .* ]]; then
    echo "#################################################"
    echo -e "You specified destination domain name starting with a dot, which is not allowed. Aborting the script."
    echo -e "#################################################\n"    
    func_help
fi

if [[ ${domainDotCount} -gt 2 ]]; then
    echo "#################################################"
    echo -e "You specified destination domain name with three or more dots. Aborting the script."
    echo -e "#################################################\n"    
    func_help
fi
}


function func_git_tag_check(){
if [[ -z ${gitTagInput} ]]; then
    gitTag=r
    fromRsync=y
elif [[ ${gitTagInput} == r* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=y
elif [[ ${gitTagInput} == d* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
elif [[ ${gitTagInput} == q* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
elif [[ ${gitTagInput} == p* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
else
    func_help
fi

echo "Git tag name starts with ${gitTag}"  >>  ${logFile}
}

# Specify the number of backup copies you want to keep. Mainly used to keep down folder size.
foldersToKeep=5


# This is necessary because of the way 'tail -n +6' works. Nothing to change here.
_folders_value=$((${foldersToKeep} + 1))


############
# Script
############
function func_start_log(){
mkdir ${logDir} 2> /dev/null
echo "# ===== ${nowMin} ===============" | tee -a ${logFile}
echo "func_start_log:`hostname`" >> ${logFile}
}


# Determine source and destination folders.
function func_get_source_dest(){
_homeRsyncedFiles="/home/${userName}/build-rsync"   # where I rsync up files under development
_filesFromGit="/home/${userJenkinsAgent}/build"   # folder where Jenkins pushes website files to

if [[ ${fromRsync} == "y" ]]; then
    sourceFolder=${_homeRsyncedFiles}/${domain} # ex: /home/${userName}/devsite/${domainFqdn}
    echo -e "Script will deploy using rsyned up files" | tee -a ${logFile}
elif  [[ ${gitTagInput:0:1} == "d" ]] && [[ ${fromRsync} == "n" ]]; then
    sourceFolder=${_filesFromGit}/${domain} # ex: /home/${userName}/build/${domainFqdn}
    echo -e "Script will deploy to Dev environment" | tee -a ${logFile}
elif  [[ ${gitTagInput:0:1} == "d" ]] && [[ ${fromRsync} == "y" ]]; then
    sourceFolder=${_homeRsyncedFiles}/${domain} # ex: /home/${userName}/build/${domainFqdn}
    echo -e "Script will deploy to Dev environment" | tee -a ${logFile}
elif [ ${gitTagInput:0:1} == "q" ]; then
    sourceFolder=${_filesFromGit}/${domain} # ex: /home/${userName}/build/${domainFqdn}
    echo -e "Script will deploy to QA environment" | tee -a ${logFile}
elif [ ${gitTagInput:0:1} == "p" ]; then
    sourceFolder=${_filesFromGit}/${domain} # ex: ex: /home/${userName}/build/${domainFqdn}
    echo -e "Script will deploy to Production environment" | tee -a ${logFile}
fi






# if [[ ${fromRsync} == "y" ]]; then
#     sourceFolder=${_homeRsyncedFiles}/${domain} # ex: /home/${userName}/devsite/${domainFqdn}
#     echo -e "Script will deploy using rsyned up files" | tee -a ${logFile}
# elif  [[ ${gitTag} == "d" ]] && [[ ${fromRsync} == "n" ]]; then
#     sourceFolder=${_filesFromGit}/${domain} # ex: /home/${userName}/build/${domainFqdn}
#     echo -e "Script will deploy to Dev environment" | tee -a ${logFile}
# elif  [[ ${gitTag} == "d" ]] && [[ ${fromRsync} == "y" ]]; then
#     sourceFolder=${_homeRsyncedFiles}/${domain} # ex: /home/${userName}/build/${domainFqdn}
#     echo -e "Script will deploy to Dev environment" | tee -a ${logFile}
# elif [ ${gitTag} == "q" ]; then
#     sourceFolder=${_filesFromGit}/${domain} # ex: /home/${userName}/build/${domainFqdn}
#     echo -e "Script will deploy to QA environment" | tee -a ${logFile}
# elif [ ${gitTag} == "p" ]; then
#     sourceFolder=${_filesFromGit}/${domain} # ex: ex: /home/${userName}/build/${domainFqdn}
#     echo -e "Script will deploy to Production environment" | tee -a ${logFile}
# fi







destFolder="${topFolder}/${webWww}/${domain}/${domainFqdn}/html"


# Check ${sourceProject} has value and determine value of sourceFolder
# if [[ ${fromRsync} == "y" ]]; then
#   sourceFolder=${_homeRsyncedFiles}/${sourceProject}
# elif  [[ ${fromRsync} == "n" ]]; then
#   sourceFolder=${_filesFromGit}/${sourceProject}
# fi

echo "Files will be copied from: ${sourceFolder}" >> ${logFile}
echo "Files will be copied to:  ${destFolder}" >> ${logFile}
}


# Determine folder to backup files to
function func_get_old(){
oldFolder="${topFolder}/${webWww}/${domain}/${domainFqdn}_old"  # ex: var/www/destwebsite.cmm/d.destwebsite.com_old
oldFolderArray="($oldFolder/*)"

echo "Backup folder of old files is in ${oldFolder}/${nowMin}"  | tee -a ${logFile}
}


# If deploying to non-production, remove Google Analytics JS lines
function func_for_nonproduction(){
if [[ ${gitTag:0:1} != "p" ]]; then
    echo -e "${nowMin} Deploying non-production version. Script will remove Google Analytics JavaScript snip from ${sourceFolder}"  | tee -a ${logFile}
    find ${sourceFolder} -type f -exec sed -i '/google-analytics.js/d' {} \;
fi
}


# MOVE older website files to backup folder.
function func_remove_old(){
mkdir -p ${oldFolder}/${nowMin}/html > /dev/null 2>&1
mv ${destFolder}/{*,.[^.]*} ${oldFolder}/${nowMin}/html > /dev/null 2>&1 && echo "${nowMin} Moved content of ${destFolder}/ to ${oldFolder}/${nowMin}/" | tee -a ${logFile}

for i in ${oldFolderArray[@]}
do
    /bin/ls -dt ${oldFolder}/* | /usr/bin/tail -n +${_folders_value} | /usr/bin/xargs /bin/rm -rf  #keep only latest ${_folders_value} sets and delete older ones
done
echo -e "\n${nowMin} Only  ${foldersToKeep}  newer subfolders are now in ${oldFolder}/. \n" | tee -a ${logFile}
}


# Copy new files to destination folder and set permissions.
function func_copy_in_files(){

# chmod -R 775 ${sourceFolder}
# chown -R ${userName}: ${sourceFolder}

mkdir ${destFolder}/ > /dev/null 2>&1
echo "Issued mkdir command to create ${destFolder}/ in case it did not exist already." >> ${logFile}

rsync -a --exclude=.DS_Store --exclude=.git --exclude=.gitignore --exclude=.idea --exclude=.name --exclude=10content ${sourceFolder}/{*,.[^.]*} ${destFolder}/ > /dev/null 2>&1    # exclude=/1-* excluces only 1-* directories on the top level of the source dir.
chmod 775 ${topFolder}/${webWww}
chown apache:apache ${topFolder}/${webWww}
chown -R apache:apache ${destFolder}
chmod 775 -R ${destFolder}
find ${destFolder} -type d -exec chmod 755 {} \; && find ${destFolder} -type f -exec chmod 644 {} \; && echo "${nowMin} Copied files to destination folder and set permission" | tee -a ${logFile}

chown apache:apache ${logFile}
echo "Log is at ${logFile}"
}


func_check_options
func_start_log
func_domain_check
func_domainfqdn_to_domain
func_last_check_production
func_git_tag_check   
func_get_source_dest
func_verify_website_sourcename
func_get_old
func_for_nonproduction  
func_remove_old
func_copy_in_files


# End of script
