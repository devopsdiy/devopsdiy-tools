#!/bin/bash

# Make sure values of below variables match your environment:
webProject="devopsdiy.xyz"
jenkinsAgent="jenkagent"
userAcct="usera"

function func_sizes() {
  echo "Current size of folders:"
  du -sh /home/jenkagent/build/${webProject}/
  du -sh /home/usera/build-rsync/${webProject}/
  du -sh /var/www/${webProject}/${webProject}/html/
  du -sh /var/www/${webProject}/qatest.${webProject}/html/
  du -sh /var/www/${webProject}/devel.${webProject}/html/
}

function func_delete() {
  echo -e "\nThis script will zero out all content of above folders."

  read -p "Answer y if you want to proceed. Answer n if you want to cancel.: " -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "\nThis script aborted with no change made.\n"
      exit 1
  fi

  rm -rf /home/jenkagent/build/${webProject}/{*,.[^.]*}
  rm -rf /home/usera/build-rsync/${webProject}/{*,.[^.]*}
  rm -rf /var/www/${webProject}/${webProject}/html/{*,.[^.]*}
  rm -rf /var/www/${webProject}/qatest.${webProject}/html/{*,.[^.]*}
  rm -rf /var/www/${webProject}/devel.${webProject}/html/{*,.[^.]*}

  echo -e "\n\nZeroed out all files of Project '${webProject}'\n"

}


func_sizes
func_delete
func_sizes