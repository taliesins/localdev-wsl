#!/bin/bash

set -euo pipefail

verifyUserName () {
  if [[ ${USERNAME} == "" ]]; then
    echo "Please pass a user name"
    exit 1
  elif [[ ${USERNAME} == "root" ]]; then
    HOMEDIR="/root"
  else
    HOMEDIR="/home/${USERNAME}"
  fi
}

setUserName () {
  USERNAME=${1-""}
  verifyUserName
}

createMainUser () {
  verifyUserName
  if [[ $(cat /etc/passwd | grep -c "${USERNAME}") == 0 ]]; then
    useradd -m -s /bin/bash "${USERNAME}"

    # ensure no password is set
    passwd -d "${USERNAME}"
  fi

  # add to sudo group
  usermod -aG sudo "${USERNAME}"

  if [[ ! -d ${HOMEDIR}/Downloads ]]; then
      mkdir "${HOMEDIR}/Downloads"
      chown "${USERNAME}:${USERNAME}" "${HOMEDIR}/Downloads"
  fi
}

addSudoers () {
  suodersString=${1-""}
  suodersFilename=${2-""}
  if [[ ${suodersFilename} == "" ]]; then
    echo "Please provide a filename for sudoers file"
    exit 1
  fi

  if [[ ! -d /etc/sudoers.d/${suodersFilename} ]]; then
    temp_sudoers=$(mktemp)
    echo "${suodersString}" > "${temp_sudoers}"

    # only add sudoers.d additions after checking with visudo
    VISUDO_RES=$(sudo visudo -c -f "${temp_sudoers}")
    # check with no error messages (s) and only mathcing (o)
    VISODU_PARSE_OK=$(echo "${VISUDO_RES}" | grep -so "parsed OK" | wc -l)

    #only add if vidudo said OK
    if [[ VISODU_PARSE_OK -eq 1  ]]; then
        sudo cp -f "${temp_sudoers}" "/etc/sudoers.d/${suodersFilename}"
    fi
  fi
}

modifyWslConf () {
  verifyUserName

  if [[ $(cat /etc/wsl.conf | grep -c "${USERNAME}") == 0 ]]; then
    sudo tee /etc/wsl.conf > /dev/null <<EOT
# Enable extra metadata options by default
[automount]
enabled = true
root = /mnt
options="metadata,umask=22,fmask=11"
mountFsTab = false

[Interop]
appendWindowsPath = False

[user]
default=${USERNAME}

[boot]
systemd=true
EOT
  fi

  if [[ ! -f /etc/profile.d/02-shared-root.sh ]]; then
    sudo tee /etc/profile.d/02-shared-root.sh > /dev/null <<EOT
sudo mount --make-rshared /
EOT
  fi
}

setUserName "${1-""}"

createMainUser
addSudoers "${USERNAME} ALL=(ALL) NOPASSWD:ALL" "${USERNAME}"
modifyWslConf
