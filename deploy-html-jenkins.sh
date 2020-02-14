#!/bin/bash
# For DevOps DIY

# Created: 2020.01.31


# Recommended usage #################################
# When actively coding a website and need to view the changes on a web server, run below:
#    ./deploy-html-jenkins.sh -d devel.site.com -s site.com
#
# When code is checked into Git repo and ready for QA, run below:
#    ./deploy-html-jenkins.sh -d qatest.site.com -s site.com -t q
#
# When code is checked into Git repo and ready for production, run below:
#    ./deploy-html-jenkins.sh -d site.com -s site.com -t p

# What does it do? #################################
# This script deploys website content to a remote webserver by doing one of these two.
#
# 1) Deploying with rsyned up files
# HTML content is rsyned up from macOS upto web server.
# This script deploy-html-jenkins.sh then runs a curl command against a Jenkins job to start it.
# This Jenkins job executes script deploy-html-runonserver.sh (located on the web server) which copies files into place.
# 
# 2) Deploying with Git repo
# This script deploy-html-jenkins.sh git tags website content on local macOS and then pushes it to Git repo.
# This script deploy-html-jenkins.sh then runs a curl command against a Jenkins job to start it.
# This Jenkins job executes script deploy-html-runonserver.sh (located on the web server) which copies files into place.

# What is it? #################################
# This script helps automating deploying website content from a local macOS onto remote webservers. 

# Technologies used #################################
# 1. deploy-html-jenkins.sh located on local macOS
# 2. Jenkins server
# 3. deploy-html-runonserver.sh

# Goal of the project #################################
# I wanted to automate repetitive deployments of website content out to remote web servers.

# Stage of the project #################################
# In production.

# Known issues or things that are not properly done #################################
# None

# Specific things to look for #################################
# Script deploy-html-jenkins.sh has been tested on macOS (10.10) only.
# Script deploy-html-runonserver.sh has been tested on CentOS 7.x only.

# How to run it #################################
# 1) ./deploy-html-jenkins.sh    
#   Get help menu
#
# 2) ./deploy-html-jenkins.sh -d devopsdiy.xyz -s devopsdiy.xyz -t p       
#   Deploy production version in Git repo to devopsdiy.xyz
#
# 3) ./deploy-html-jenkins.sh -d qatest.devopsdiy.xyz -s devopsdiy.xyz -t q     
#   Deploy QA version  in Git repo to qatest.devopsdiy.xyz
#
# 4) ./deploy-html-jenkins.sh -d devel.devopsdiy.xyz -s devopsdiy.xyz -t r
# OR 
#    ./deploy-html-jenkins.sh -d devel.devopsdiy.xyz -s devopsdiy.xyz
#   Deploy rsynced up files to devel.devopsdiy.xyz    Note "-t" (for git tag) is not used.

# Log output
# New file name will be assigned using date stamp.
# Script html-dev-rsync-deploy.sh will log output here:  /tmp/deploy-yyyy-mm-dd.log

########################################################

##### Update below 5 variable names

userSshWebServer="usera"
userConsoleJenkinsServer="jenkuser01"

apiJenkins="11c4aae7eea7efb442ff274cc1616dc22f"
jenkinsServer="jenkserv01.devopsdiy.xyz"

webServer="devel.devopsdiy.xyz"  # For scp/ssh into a remote web server. Cloudflare.com proxies (which only allows in http/https) normal hostname like "site.com", so I had to create a separate hostname to allow sshing into remote web servers. Example would be hostname "devel.site.com".

declare sourceFolder
declare domainFqdn # Used in /data/www/${domain}/${domainFqdn}
declare domain      # User in /data/www/${domain}/${domainFqdn}
declare domainDotCount  # ex value: 1 or 2   Count of dots in ${domainFqdn}
declare gitTag
declare gitTagInput
declare sourceProject  # devopsdiy.xyz or example.com
declare gitTagYN # Indicates whether git Tag will be used to specify source files. If this is set to y, git tag command will be done and git pushed. And curl against Jenskins will be for build job that does not have "*--rsync"
##### Variable gitTagYN is not really used?

declare gittagProposed  # ex value: q.20200205-08
homeCodes="${HOME}/codes"   # Directory where I keep web site files on my Mac.

fromRsync=y  # Activates rcyncing up files to web server. And this also activates using Jenkins Build job name ending with "*-rsync".
forceProduction=n   # Argument to specify whether to force deploying non-production tested code to Production website.

log_dir=/tmp
logFile=${log_dir}/deploy-$(TZ=":UTC" date +"%Y-%m-%d").log     # ex value: /tmp/deploy-2018-06-12.log

selfScript=`basename "$0"`

# For coloring output in Terminal
cyan='\033[1;36m'
nc='\033[0m' # No Color


function func_help() {
  echo -e "\n# ===== Script ${selfScript} Help ===== #"
  echo "This script requires -d and -s options. Options -t and -f are optional.";
  echo "Examples:"
  echo "1. Deploy production version to devopsdiy.xyz"
  echo "    ./deploy-html-jenkins.sh -d devopsdiy.xyz -s devopsdiy.xyz -t p"
  echo "2. Deploy QA version to qatest.devopsdiy.xyz"
  echo -e "    ./deploy-html-jenkins.sh -d qatest.devopsdiy.xyz -s devopsdiy.xyz -t q   "
  echo "3. Deploy 'rsynced up' files to devel.devopsdiy.xyz"
  echo -e "    ./deploy-html-jenkins.sh -d devel.devopsdiy.xyz -s devopsdiy.xyz   "

  echo -e "\n-d: Required.  The target domain you are deploying the website to. Example below:\n    -d devopsdiy.xyz\n    -d qatest.devopsdiy.xyz\n    -d devel.devopsdiy.xyz\n\n    This script accepts URLs ending with certain string such as:\n    .com\n    .org\n    .co\n    .vag\n    .info \n"
  echo -e "For complete list of a top level domain (TLD) that will be accepted, check function 'func_domain_check' below in this script.\n\n"

  echo -e "-s: Required.  Name of source project folder. Example below:\n    -s devopsdiy.xyz\n "

  echo -e "-t: Optional.  Git tag name used for the deployment, which are d, q, or p. You can also use 'r' to indicate deploying with rsyned up files. If this option is left out, -t r will be used by default. Examples below:\n    -g q.20170603\n    -g p.2017.06.03\n    -g r\n"

  echo -e "-f  Optional. Optional argument is either y or no. 1) Use this option to force deploying production code to any domain even if it has 2 or more dots in the domain. 2) You can also use this option to force deploying code-not-verified-for-production to the production website. However note that if you end up using '-f y', you are probably doing something wrong. Example below:\n    -f y\n"
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


function func_start_log() {
  export TZ=UDT
  timeUdt=`date "+%Y-%m-%d %H:%M %Z"`
  unset TZ
  timeLocal=`date "+%Y-%m-%d %H:%M %Z"`

  echo "# ===== Script ${selfScript} is running ===== #" | tee -a ${logFile}
  echo -e "Start at ${timeUdt}." | tee -a ${logFile}
  echo -e "Start at ${timeLocal}." | tee -a ${logFile}
  echo -e "\nYou picked following options to deploy to a website:" | tee -a ${logFile}
  echo -e "Destination URL: ${domainFqdn}" | tee -a ${logFile}
  echo -e "Source folder: ${sourceProject}" | tee -a ${logFile}

  if [[ -z ${gitTagInput} ]]; then
      echo -e "\nYou did not specify a git tag with the script. So the script will assume you picked ${cyan} \"-t r\" ${nc}, r standing for \"rsync up\". " | tee -a ${logFile}
  elif [[ ${gitTagInput} == r* ]]; then
      echo -e "\nYou chose to rsync up files first and deploy them to ${domainFqdn}." | tee -a ${logFile}
  elif [[ ${gitTagInput} == d* ]]; then
      echo -e "\nYou chose to deploy files 1) checked into Git Repo and 2) tagged with \"d\" (for Dev) to ${domainFqdn}." | tee -a ${logFile}
  elif [[ ${gitTagInput} == q* ]]; then
      echo -e "\nYou chose to deploy files 1) checked into Git Repo and 2) tagged with \"q\" (for QA) to ${domainFqdn}." | tee -a ${logFile}
  elif [[ ${gitTagInput} == p* ]]; then
      echo -e "\nYou chose to deploy files 1) checked into Git Repo and 2) tagged with \"p\" (for production) to ${domainFqdn}." | tee -a ${logFile}
  fi

  domainDotCount=$(echo ${domainFqdn} | grep -o "\." | wc -l)
}


function func_force_captcha() {
  if [[ ${forceProduction} == "y" ]] && [[ "${gitTag:0:1}" == "p" ]] && [[ ${domainDotCount} -eq 1 ]]; then
    echo -e "\n\n########## CAPTCHA ##########"
    echo -e "You used 1) '-f y' option and 2) git tag that starts with "p" to deploy to a domain with only one dot (ex: site.com). You do not need to use '-f y' option when deploying code git tagged with "p..." to a production website. But since you are deploying to production website, please type in the sum of two numbers below to confirm your intention. If wrong answer is given, the script will abort."
  elif  [[ ${forceProduction} == "y" ]]; then
    echo -e "\n\n########## CAPTCHA ##########"
    echo -e "You used '-f y' option with this script to indicate you want to force deploying code (ex1: non-production code to Production website.  ex2: production code to non-production website). Please type in the sum of two numbers below to confirm your intention. If wrong answer is given, the script will abort."
  elif [[ "${gitTag:0:1}" == "p" ]]; then
    echo -e "\n\n########## CAPTCHA ##########"
    echo -e "You chose to deploy production ready code to the Production website. Please type in the sum of two numbers below to confirm your intention. If wrong answer is given, the script will abort." 
  fi


  if [[ ${forceProduction} == "y" ]] || [[ "${gitTag:0:1}" == "p" ]]; then
    capt1=$((1 + RANDOM % 3))
    capt2=$((1 + RANDOM % 6))
    echo -e "\n${capt1} + ${capt2}\n"
    read -p "Please add above 2 numbers and enter the sum: " captInput
    captSum=$(( $capt1 + $capt2 ))

    if [ ${captInput} -eq ${captSum} ]; then
      echo "Proceeding"
      echo -e "########## END OF CAPTCHA ##########\n"
    else
      echo "Wrong input. Quitting" 
      echo -e "########## END OF CAPTCHA ##########\n"
      func_help
    fi

  fi
}


# Check if the 2 required arguments are provided.
function func_check_options() {
  if [[ -z ${domainFqdn} ]] || [[ -z ${sourceProject} ]]; then
      func_help
  fi
}


# Check if valid TLD (top level domain) such as .com or .org is given.
function func_domain_check() {
  case ${domainFqdn} in
      # if you want to allow new TLD like ".edu", add it below.
      *.com|*.co|*.org|*.info|*.xyz|*.net) echo "Verified valid URL was given as an option argument."  | tee -a ${logFile} ;;
      *) func_help ;;
  esac
}


# Compare target destination URL and source folder to ensure they match.
# This is to avoid deploying SiteA sitefiles to SiteB DocRoot accidentally.
function func_compare_sourceProject_domain_fqdn() {

  domainFqdnLastTwo=$(echo ${domainFqdn} | rev | cut -d '.' -f -2 | rev)

  if [[ ${sourceProject} == ${domainFqdnLastTwo} ]]; then
    echo -e "\nYou can deploy the content of folder ${sourceProject} to ${domainFqdn}. Proceeding with deployment.\n"  | tee -a ${logFile}
  else
    echo -e "\n####################\nYou cannot deploy the content folder ${sourceProject} to ${domainFqdn}. Check for typos and rerun ths command. \nAborting script.\n####################\n" | tee -a ${logFile}
    func_help 
  fi
}

# If destination domain has 2 periods, it means the target destination should start with devel or qatest.
# If not, abort script.
function checkDomainFqdnFirst() {
  if [ ${domainDotCount} == 2 ]; then
    domainFqdnFirstCheck=$(echo ${domainFqdn} | cut -d '.' -f 1 ) 

    case ${domainFqdnFirstCheck} in
      # if you want to allow new TLD like ".edu", add it below.
      devel|qatest) echo "Verified valid URL was given as an option argument."  | tee -a ${logFile} ;;
      *) echo -e "\n####################\nFor destination domain you picked ${domainFqdn} which is not right. For devel, you should pick devel.site.com. For QAtest, you should pick qatest.site.com. Aborting script.\n####################\n"; func_help ;;
    esac
  fi
}


# Assign value to ${domain}, which is used to determine DocRoot folder on the web server (ex: webserver:/var/www/sitea.com/).
# If destination domain has 2 levels, the destination domain provided with -d is used.
# If destination domain has 3 or more levels, only the last 2 levels are assigned to ${domain}.
# ex: Given site.com, site.com is assigned to ${domain}.
# ex: Given web1.site.com, site.com is assigned to ${domain}.
function func_domainfqdn_to_domain() {
  if [[ ${domainDotCount} -eq 1 ]]; then
      domain=${domainFqdn}
      else
      domain=$(echo ${domainFqdn} | rev | cut -f1,2 -d'.' | rev)
  fi
}


# Based on what argument is provided with -t, determine source of sitefiles to deploy with.
function func_git_tag_check() {
  if [[ -z ${gitTagInput} ]]; then
    gitTag=r
    fromRsync=y
    echo -e "\nWill attempt to deploy to dev environment, with rsynced up files." | tee -a ${logFile}
  elif [[ ${gitTagInput} == r* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=y
    echo -e "\nWill attempt to deploy to dev environment, with rsynced up files." | tee -a ${logFile}
  elif [[ ${gitTagInput} == d* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
    echo -e "\nWill attempt to deploy to dev environment." | tee -a ${logFile}
  elif [[ ${gitTagInput} == p* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
    echo -e "\nWill attempt to deploy to Production environment." | tee -a ${logFile}
  elif [[ ${gitTagInput} == q* ]]; then
    gitTag=${gitTagInput:0:1}
    fromRsync=n
    echo -e "\nWill attempt to deploy to QA environment." | tee -a ${logFile}
  else
    func_help
  fi
}


# You normally would not deploy non-production ready code to production environment (ex: https://devopsdiy.xzy). This function serves as a check for that rule. If you did try to publish non-production ready code to production environment, this function will abort the script.
# Note using forceProduction option "-f y" will override this restriction. 
function func_compare_domain_and_gittag() {
gitTagFirstChar="${gitTag:0:1}"

if [[ ${domainDotCount} -eq 1 ]] && [[ ${gitTag} != "p" ]] && [[ ${forceProduction} != "y" ]] ; then
  # Two echo commands are used here.
  # First one is for showing output with colored font in Terminal.
  # Second is for appending the same note into ${logFile}, but without ${cyan}  and  ${nc}.
  
  echo -e "\n####################\nYou tried to deploy to ${cyan}${domainFqdn}${nc}, but the git tag name does not start with \"${cyan}p${nc}\". Deploying any non-production ready code to production website is a bad idea. Please rerun the script and select correct git tag name and full destination URL. (ex1: git tag ${cyan}q.${nc} for ${cyan}qatest.site.com${nc}    ex:2 git tag ${cyan}p.${nc} for ${cyan}site.com${nc})\n####################\n"

  # Below echo has same message as above echo command. But below echo command adds a log entry into ${logFile} without all the color coding related options.
  echo -e "\nYou tried to deploy to ${domainFqdn}, but the git tag name does not start with \"p\". Deploying any non-production ready code to production website is a bad idea. Please rerun the script and select correct git tag name and full destination URL (ex: git tag q. for q.site.com or p. for site.com.\n" >> ${logFile}

  echo -e "If you MUST deploy rsyned up files to production site ${cyan}${domainFqdn}${nc}, use ${cyan}-s ${domainFqdn} -d ${domainFqdn} -t r -f y${nc} options."

  func_help
elif [[ ${domainDotCount} -eq 1 ]] && [[ ${gitTag} == "r" ]] && [[ ${forceProduction} != "y" ]]; then
  echo -e "\n####################\nYou tried to deploy to ${domainFqdn} with rsynced up files as you did not use the git tag "${cyan}p.${nc}". Script will abort and deployment will not run.\n####################\n" 

  func_help
elif [[ ${domainDotCount} -ge 2 ]] && [[ ${gitTag} == "p" ]] && [[ ${forceProduction} != "y" ]]; then
  echo -e "\n####################\nYou tried to deploy production tagged code to a domain with 2 dots, which probably not you want to do.\nCancellnig deployment.\n####################\n"

  func_help
fi
}


# If fromRsync is y, script will rsync up files.
# This function is called in func_get_source_dest.
function func_rsync_up() {
  func_force_captcha
  rsync -ae ssh --delete --stats --exclude=".DS_Store" --exclude="*.swp" --exclude=".git" --exclude=".idea" --exclude="1-*" ${homeCodes}/${sourceProject} ${userSshWebServer}@${webServer}:~/build-rsync/ | tee -a ${logFile}
}


# If fromRsync value is n, script will git tag and push code to git repo.
# This function is called in func_get_source_dest.
function func_git_tag_push() {
  # Check git tag name starts q, d or p. If not abort the script.
  func_force_captcha

  case ${gitTag} in
    q|d|p) echo "Correct option was given as the 1st argument of the script." ;;
    *)     func_help ;;
  esac

  echo -e "\n\nThis script assumes you have executed 'git commit' and other related commands already.\n" | tee -a ${logFile}

  # Pulling date-time value to create git tag value.
  export TZ=UDT
  time=`date "+%Y%m%d-%H %Z"`
  timeMin=`date "+%M"`
  unset TZ

  time=${time%????}

  # Determine possible git tag name to use, $_env + data-time
  #_env_1st=`echo "${gitTag:0:1}"`
  gittagProposed=${gitTag}.${time}
  echo "Proposed Git tag name: ${gittagProposed}" | tee -a ${logFile}

  # Get latest git tag already present.
  gittagLast=`git -C "${homeCodes}/${sourceProject}" tag | grep "^${gitTag}.*" | tail -n 1`
  echo "Last Git tag name used: $gittagLast"  tee -a ${logFile}

  # Compare lastest Git tag value and proposed git tag value. Determine final git tag value to use.
  if [[ `echo ${gittagLast} | cut -c1-13` == `echo ${gittagProposed} | cut -c1-13` ]]; then
    echo "This script will pick for you a new Git tag name using date-time stamp." | tee -a ${logFile}
    gittagProposed01=${gittagProposed}fix${timeMin}
    gitTag=${gittagProposed01}
  else
    echo -e "Confirmed ${gittagProposed} has not been used.\n" | tee -a ${logFile}
    gitTag=${gittagProposed}
  fi

  echo -e "Will tag code with tag name: ${gitTag} \n" | tee -a ${logFile}

  # Git tag code and push
  git -C "${homeCodes}/${sourceProject}" tag -a ${gitTag} -m "update"
  git -C "${homeCodes}/${sourceProject}" push origin --tags
}


# Depending on rsync y/n and git tag provided as arguments with this script, this function determines whether to
# 1) sync up files and deploy or 2) deploy with code git git repo
#
# 1) rsync up files
# 1.2) curl against Jenkins which executes script webserver:html-deploy-jenkins-runonserver.sh.
#
# OR
# Git tag, git push, and deploy
# 2) tig tag code as d, q, or p
# 2.1) git push
# 2.2) curl against Jenkins server which executes script webserver:html-deploy-jenkins-runonserver.sh.
function func_get_source_dest() {
  if [[ ${fromRsync} == "y" ]]; then
    sourceFolder=${homeCodes}/${domain} # ex: /home/jenkins/devsite/${domainFqdn}
    gitTagYN=n
    echo -e "Script will 1) rsync up files from  ${sourceFolder}   to web server and 2) trigger html-deploy-jenkins-runonserver.sh on web server.\n" | tee -a ${logFile}
  elif  [[ ${gitTag} == "d" ]] && [[ ${fromRsync} == "n" ]]; then
    gitTagYN=y
    echo -e "Script will deploy with git checked-in/tagged code.\n" | tee -a ${logFile}
    echo -e "You will not see any list of files being deployed here as Jenkins 1) pulls the files from the Git Repo and 2) copies them to the web server.\n" | tee -a ${logFile}
  elif [ ${gitTag} == "q" ]; then
    gitTagYN=y
    echo -e "Script will deploy with git checked-in/tagged code.\n" | tee -a ${logFile}
    echo -e "You will not see any list of files being deployed here as Jenkins is handling it." | tee -a ${logFile}
  elif [ ${gitTag} == "p" ]; then
    gitTagYN=y
    echo -e "Script will deploy with git checked-in/tagged code.\n"| tee -a ${logFile}
    echo -e "You will not see any list of files being deployed here as Jenkins is handling it." | tee -a ${logFile}
  fi


  if [[ ${fromRsync} == "y" ]]; then
    sourceFolder=${homeCodes}/${sourceProject}
    func_rsync_up  # Rsyncing up files to web server
  elif  [[ ${fromRsync} == "n" ]]; then
    sourceFolder=${_filesFromGit}/${sourceProject}     ##### Seems variable  ${_filesFromGit}  is not used at all?
    func_git_tag_push  # Git tagging and push to git repo.
  fi
}


function func_get_jenkins_curl_token() {
  echo ""

  if [[ ${fromRsync} == "y" ]]; then
    read -s -p "Enter the Jenkins Authentication Token for deploying with Rynced-Up files: " jenkins_curl_token_rsync
  elif [[ ${fromRsync} == "n" ]]; then
    read -s -p "Enter the Jenkins Authentication Token for deploying with files from Git Repo: " jenkins_curl_token_git
  fi


  if [ -z "${jenkins_curl_token_rsync}" ] && [ -z "${jenkins_curl_token_git}" ]; then
    echo -e "\n\nWhen starting a Jenkins job with curl command, Jenkins Authentication Token must be provided. Unfortunately you did not provide any value for it so this script will abort.\n"
    sleep 5
    func_help 
  fi
  
  echo ""
}


# Run curl against Jenskins Build job named as  "site.com" (deploying with files pulled from Git repo) or "domain.com-rsync" (deploying with files rsynced up from coder's Mac).
function func_jenkins_rsync_git() {
  CRUMB=$(curl -s "https://${userConsoleJenkinsServer}:${apiJenkins}@${jenkinsServer}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)")

  if [[ ${fromRsync} == "y" ]]; then
    # On the web server, script ~/bin/html-deploy-by-jenkins-runonserver.sh will deploy with rsyced up files.
    curl -X POST -H "$CRUMB" "https://${userConsoleJenkinsServer}:${apiJenkins}@${jenkinsServer}/job/${domain}-rsync-container/job/${domain}-rsync/buildWithParameters?token=${jenkins_curl_token_rsync}&domain=${domainFqdn}&source=${sourceProject}&tag=${gitTag}&force=${forceProduction}" && echo -e "\nJenkins server completed deploying the files." | tee -a ${logFile} || echo -e "\nSomething went wrong and Jenkins could not deploy the files." | tee -a ${logFile}
  elif  [[ ${fromRsync} == "n" ]]; then
    # On the web server, script ~/bin/html-deploy-by-jenkins-runonserver.sh will deploy with git tagged code in Git repo.
    curl -X POST -H "$CRUMB" "https://${userConsoleJenkinsServer}:${apiJenkins}@${jenkinsServer}/job/${domain}-container/job/${domain}/buildWithParameters?token=${jenkins_curl_token_git}&domain=${domainFqdn}&source=${sourceProject}&tag=${gitTag}&force=${forceProduction}" && echo -e "\nJenkins server completed deploying the files." | tee -a ${logFile} || echo -e "\nSomething went wrong and Jenkins could not deploy the files." | tee -a ${logFile}
  fi

  echo -e "\nYou can review log file ${logFile} for detailed output.\nB y e\n" | tee -a $logFile
}


func_check_options
func_start_log
checkDomainFqdnFirst
func_compare_sourceProject_domain_fqdn
func_domain_check
func_domainfqdn_to_domain
func_git_tag_check
func_compare_domain_and_gittag
func_get_jenkins_curl_token
func_get_source_dest
func_jenkins_rsync_git

# End of script
