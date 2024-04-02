#!/bin/bash
set -ex

while getopts w: flag; do
  case "${flag}" in
    w) local_workspace_path=${OPTARG} ;;
    *) throw 'Unknown argument' ;;
  esac
done

echo "local_workspace_path=${local_workspace_path}"

user_profile_path=""

full_cygpath=$(command -v cygpath) || :
if [ -n "$full_cygpath" ]; then
  local_workspace_path=$(cygpath -u "${local_workspace_path}")
fi

full_wslpath=$(command -v wslpath) || :
if [ -n "$full_wslpath" ]; then
  wsl_local_workspace_path=$(wslpath -u "${local_workspace_path}") || :
  if [ -n "$wsl_local_workspace_path" ]; then
    local_workspace_path=$wsl_local_workspace_path
  fi

  user_profile_path=$(cmd.exe /c "<nul set /p=%UserProfile%" 2> /dev/null) || :
  user_profile_path=$(wslpath -u "${user_profile_path}") || :
fi

export local_workspace_path=$local_workspace_path
