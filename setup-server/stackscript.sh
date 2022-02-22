#!/usr/bin/env bash

# Version 0.1.0

# USER CONFIG
#
# <UDF name="user_name" label="Non-Root User Name" default="administrator" />
# <UDF name="user_password" label="Non-Root User Password"/>
# <UDF name="user_sshkey" label="Public Key for Non-Root User" default="" />
#
# SUDO CONFIG
#
# <UDF name="sudo_usergroup" label="Usergroup to use for Sudo Accounts" default="sudo" />
# <UDF name="sudo_passwordless" label="Passwordless Sudo" oneof="Require Password,Do Not Require Password", default="Require Password" />
#
# SSH CONFIG
#
# <UDF name="sshd_port" label="SSH Port" default="22" />
# <UDF name="sshd_permitroot" label="SSH Permit Root Login" oneOf="No,Yes" default="No" />
# <UDF name="sshd_passwordauth" label="SSH Password Authentication" oneOf="No,Yes" default="No" />
#
# FIREWALL CONFIG
#
# <UDF name="allowedServices" label="Allowed services" example="Punch holes in the firewall for these services. SSH is already open on port 22 (see Restrict SSH)." default="" manyOf="FTP Server: TCP 21,Telnet: TCP 23,SMTP: TCP 25,DNS Server: TCP/UDP 53,Web Server: TCP 80,POP3 Mail Service: TCP 110,NTP Service: UDP 123,IMAP Mail Service: TCP 143,SSL Web Server: TCP 443,Mail Submission: TCP 587,SSL IMAP Server: TCP 993,OpenVPN Server: UDP 1194,IRC Server: TCP 6667" />
# <UDF name="extraTCP" label="Extra TCP holes (SSH is already handled for you)" example="Extra holes in the firewall for TCP. Understands service names ('kerberos') and port numbers ('31337'), separate by spaces." default="" />
# <UDF name="extraUDP" label="Extra UDP holes" example="Extra holes in the firewall for UDP. Understands service names ('daytime') and port numbers ('1094'), separate by spaces." default="" />
#

logfile="/var/log/stackscript.log"

#  System Update & Install Packages

systemUpdate() {
  echo "" >> $logfile
  echo "Performing System Update..." >> $logfile

  if [ -f /etc/apt/sources.list ]; then
	  sudo apt-get update -qqy
		sudo apt-get upgrade -qqy
  else
     echo "Your distribution is not supported by this StackScript"
     exit
  fi
}

installDeps() {
  echo "" >> $logfile
  echo "Installing the following basic applications:" >> $logfile
  echo "sudo ufw" >> /var/log/stackscript.log

  if [ -f /etc/apt/sources.list ]; then
    sudo apt -qqy install sudo ufw
  else
     echo "Your distribution is not supported by this StackScript"
     exit
  fi
}

# Firewall Security

setupFirewall() {
  echo "" >> $logfile
  echo "Configure UFW..." >> $logfile

  sudo ufw allow $SSHD_PORT/tcp

  IFS=$','
  for service in $ALLOWEDSERVICES; do
    echo Service: $service
    interested=${service#*: }
    IFS=$' '
    set -- $interested
    for i in TCP UDP; do
      if [[ "$1" == *$i* ]]; then
        PP=$(echo $2/$i | tr '[:upper:]' '[:lower:]')
        sudo ufw allow $PP
      fi
    done
  done
  unset IFS

  # Extras
  for i in $EXTRAUDP; do
      echo Allowing: UDP $i
      sudo ufw allow $i/udp
  done
  for i in $EXTRATCP; do
      echo Allowing: TCP $i
      sudo ufw allow $i/tcp
  done

  sudo ufw enable
  echo "Completed UFW config..." >> $logfile
}

# SSH Security

setupSSH() {
  echo "" >> $logfile
  echo "Beginning SSH security setup..." >> $logfile

  cp /etc/sudoers /etc/sudoers.tmp
  chmod 0640 /etc/sudoers.tmp
  test "${SUDO_PASSWORDLESS}" == "Do Not Require Password" && (echo "%`echo ${SUDO_USERGROUP} | tr '[:upper:]' '[:lower:]'` ALL = NOPASSWD: ALL" >> /etc/sudoers.tmp)
  test "${SUDO_PASSWORDLESS}" == "Require Password" && (echo "%`echo ${SUDO_USERGROUP} | tr '[:upper:]' '[:lower:]'` ALL = (ALL) ALL" >> /etc/sudoers.tmp)
  chmod 0440 /etc/sudoers.tmp
  mv /etc/sudoers.tmp /etc/sudoers

  # Configure SSHD
  echo "Port ${SSHD_PORT}" > /etc/ssh/sshd_config.tmp

  sed -n 's/\(HostKey .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(UsePrivilegeSeparation .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(KeyRegenerationInterval .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(ServerKeyBits .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(SyslogFacility .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(LogLevel .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(LoginGraceTime .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  echo "PermitRootLogin `echo ${SSHD_PERMITROOT} | tr '[:upper:]' '[:lower:]'`" >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(StrictModes .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(RSAAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(PubkeyAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(IgnoreRhosts .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(RhostsRSAAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(HostbasedAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(PermitEmptyPasswords .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(ChallengeResponseAuthentication .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  echo "PasswordAuthentication `echo ${SSHD_PASSWORDAUTH} | tr '[:upper:]' '[:lower:]'`" >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(X11Forwarding .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(X11DisplayOffset .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(PrintMotd .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(PrintLastLog .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(TCPKeepAlive .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(MaxStartups .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(AcceptEnv .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(Subsystem .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp
  sed -n 's/\(UsePAM .*\)/\1/p' < /etc/ssh/sshd_config >> /etc/ssh/sshd_config.tmp

  chmod 0600 /etc/ssh/sshd_config.tmp
  mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config

  service ssh restart
  echo "Completed SSH security setup..." >> $logfile
}

# User Creation

createUser() {
  echo "" >> $logfile
  echo "Beginning User setup..." >> $logfile

  # Create User & Add SSH Key
  USER_NAME_LOWER=`echo ${USER_NAME} | tr '[:upper:]' '[:lower:]'`

  useradd -m -s /bin/bash -G sudo ${USER_NAME_LOWER}
  echo "${USER_NAME_LOWER}:${USER_PASSWORD}" | chpasswd

  USER_HOME=`sed -n "s/${USER_NAME_LOWER}:x:[0-9]*:[0-9]*:[^:]*:\(.*\):.*/\1/p" < /etc/passwd`

  sudo -u ${USER_NAME_LOWER} mkdir ${USER_HOME}/.ssh
  echo "${USER_SSHKEY}" >> $USER_HOME/.ssh/authorized_keys
  chmod 0600 $USER_HOME/.ssh/authorized_keys
  chown ${USER_NAME_LOWER}:${USER_NAME_LOWER} $USER_HOME/.ssh/authorized_keys

  echo "Completed User setup..." >> $logfile
}

# Install files

installFiles() {
  remoteURL="https://raw.githubusercontent.com/Th3-S1lenc3/Linode-Stackscripts/master/setup-server/files"
  USER_HOME=`sed -n "s/${USER_NAME_LOWER}:x:[0-9]*:[0-9]*:[^:]*:\(.*\):.*/\1/p" < /etc/passwd`

  wget $remoteURL/contents -O /tmp/contents

  contents=($(cat /tmp/contents))

  for file in "${contents[@]}"; do
    if [[ $file == "advcp" || $file == "advmv" ]]; then
      wget $remoteURL/$file -O /usr/local/bin/$file
    else
      wget $remoteURL/$file -O $USER_HOME/$USER_NAME/$file
    fi
  done

}

# Run Install in Sequence

# starting of stackscript
touch $logfile
echo "Starting StackScript processing..." >> $logfile

systemUpdate

installDeps

setupFirewall

setupSSH

createUser

installFiles

echo "StackScript Done..." >> $logfile
