# Description: This script creates a new user in WSL, sets up sudoers, and modifies WSL configuration.
#!/bin/bash

set -euo pipefail

verifyUserName () {
  if [[ ${USERNAME} == "" ]]; then
    echo "[verifyUserName] No username provided. Exiting with code 1." # Log missing username
    return 1 # Return failure
  elif [[ ${USERNAME} == "root" ]]; then
    HOMEDIR="/root" # Set home directory for user
    echo "[verifyUserName] Username is 'root'. Home directory set to '/root'." # Log root user home directory
  else
    HOMEDIR="/home/${USERNAME}" # Set home directory for non-root user
    echo "[verifyUserName] Username is '${USERNAME}'. Home directory set to '/home/${USERNAME}'." # Log non-root user home directory
  fi
  echo "[verifyUserName] verifyUserName function completed successfully." # Log function completion
  return 0 # Return success
}

setUserName () {
  USERNAME=${1-""} # Assign the first argument to USERNAME or default to an empty string
  echo "[setUserName] Setting username to '${USERNAME}'." # Log username being set
  verifyUserName || return 1 # Verify the username and return failure if it fails
  echo "[setUserName] setUserName function completed successfully." # Log function completion
  return 0 # Return success
}

createMainUser () {
  if [[ $(cat /etc/passwd | grep -c "${USERNAME}") == 0 ]]; then
    useradd -m -s /bin/bash "${USERNAME}" # Create a new user with a home directory and bash shell
    echo "[createMainUser] User '${USERNAME}' created with a home directory and bash shell." # Log user creation

    passwd -d "${USERNAME}" # Ensure no password is set for the user
    echo "[createMainUser] Password for user '${USERNAME}' has been removed." # Log password removal
  else
    echo "[createMainUser] User '${USERNAME}' already exists. Skipping creation." # Log existing user
  fi

  usermod -aG sudo "${USERNAME}" # Add the user to the sudo group
  echo "[createMainUser] User '${USERNAME}' added to the sudo group." # Log sudo group addition

  if [[ ! -d ${HOMEDIR}/Downloads ]]; then
      mkdir "${HOMEDIR}/Downloads" # Create a Downloads directory in the user's home directory
      echo "[createMainUser] Downloads directory created at '${HOMEDIR}/Downloads'." # Log directory creation
      chown "${USERNAME}:${USERNAME}" "${HOMEDIR}/Downloads" # Set ownership of the Downloads directory
      echo "[createMainUser] Ownership of '${HOMEDIR}/Downloads' set to '${USERNAME}'." # Log ownership change
  fi
  echo "[createMainUser] createMainUser function completed successfully." # Log function completion
  return 0 # Return success

}

addSudoers () {
  suodersString=${1-""} # Sudoers configuration string
  suodersFilename=${2-""} # Filename for the sudoers file
  echo "[addSudoers] Adding sudoers configuration for user '${USERNAME}'." # Log sudoers addition
  if [[ ${suodersFilename} == "" ]]; then
    echo "[addSudoers] No filename provided for sudoers file. Exiting with code 2." # Log missing filename
    return 2 # Return failure
  fi

  if [[ ! -d /etc/sudoers.d/${suodersFilename} ]]; then
    temp_sudoers=$(mktemp) # Create a temporary file for the sudoers configuration
    echo "${suodersString}" > "${temp_sudoers}" # Write the sudoers string to the temporary file
    echo "[addSudoers] Temporary sudoers file created at '${temp_sudoers}'." # Log temporary file creation

    VISUDO_RES=$(sudo visudo -c -f "${temp_sudoers}") # Validate the sudoers file using visudo
    echo "[addSudoers] Visudo validation output: ${VISUDO_RES}" # Log visudo validation output
    VISODU_PARSE_OK=$(echo "${VISUDO_RES}" | grep -so "parsed OK" | wc -l) # Check if visudo parsed it successfully
    echo "[addSudoers] Visudo validation result: ${VISODU_PARSE_OK}." # Log visudo validation result

    if [[ VISODU_PARSE_OK -eq 1  ]]; then
        sudo cp -f "${temp_sudoers}" "/etc/sudoers.d/${suodersFilename}" # Copy the validated file to sudoers.d
        echo "[addSudoers] Sudoers file copied to '/etc/sudoers.d/${suodersFilename}'." # Log file copy
    else
        echo "[addSudoers] Visudo validation failed. Sudoers file not copied." # Log validation failure
        rm -f "${temp_sudoers}" # Remove the temporary file

        return 3 # Return failure
    fi
  fi
  echo "[addSudoers] addSudoers function completed successfully." # Log function completion
  return 0 # Return success

}

modifyWslConf () {
  if [[ $(cat /etc/wsl.conf | grep -c "${USERNAME}") == 0 ]]; then
  echo "[modifyWslConf] Modifying WSL configuration." # Log WSL configuration modification
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
    # Update the WSL configuration file with the default user and other settings
  else
    echo "[modifyWslConf] WSL configuration already exists. Skipping modification." # Log existing configuration
  fi



  if [[ ! -f /etc/profile.d/02-shared-root.sh ]]; then
    echo "[modifyWslConf] Create a script to ensure the root filesystem is shared"
    sudo tee /etc/profile.d/02-shared-root.sh > /dev/null <<EOT
sudo mount --make-rshared /
EOT
  else
    echo "[modifyWslConf] The script to ensure the root filesystem is shared already exists."
  fi
}

  echo "*******************************************" # Log function completion
if setUserName "${1-""}"; then # Set the username from the first argument
  echo "*******************************************" # Log function completion
else
  echo "1. Failed to set username. Exiting with code 1." # Log failure and exit
  exit 1
  echo "*******************************************" # Log function completion
fi


  echo "*******************************************" # Log function completion
if createMainUser ; then { 
  # Create the main user
  echo "*******************************************" # Log function completion
}
else
  echo "2. Failed to create main user. Exiting with code 1." # Log failure and exit
  echo "*******************************************" # Log function completion
  exit 2
fi

  echo "*******************************************" # Log function completion
if addSudoers "${USERNAME} ALL=(ALL) NOPASSWD:ALL" "${USERNAME}" ; then { # Add the user to sudoers with no password requirement
  echo "*******************************************" # Log function completion
}
else
  echo "3. Failed to add sudoers configuration. Exiting with code 3." # Log failure and exit
  echo "*******************************************" # Log function completion
  exit 3
fi

  echo "*******************************************" # Log function completion
if modifyWslConf; then { # Modify the WSL configuration
  echo "*******************************************" # Log function completion
}
else
  echo "4. Failed to modify WSL configuration. Exiting with code 4." # Log failure and exit
  echo "*******************************************" # Log function completion
  exit 4
fi


echo "Script completed successfully." # Log script completion
