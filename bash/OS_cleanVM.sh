#!/bin/bash 

# Steps to make a clean VM for use as a Red Hat template.
# DNS config
# NTP config

# install necessary and helpful components
yum -y install net-tools nano deltarpm wget bash-completion yum-plugin-remove-with-leaves yum-utils git

# install VM tools and perl for VMware VM customizations
yum -y install open-vm-tools perl

#stop logging services 
/sbin/service rsyslog stop 
/sbin/service auditd stop 

#remove old kernels 
/bin/package-cleanup -y –oldkernels –count=1 

#clean yum cache 
/usr/bin/yum clean all 

#force logrotate to shrink logspace and remove old logs as well as truncate logs 
/usr/sbin/logrotate -f /etc/logrotate.conf 
/bin/rm -f /var/log/*-???????? /var/log/*.gz 
/bin/rm -f /var/log/dmesg.old 
/bin/rm -rf /var/log/anaconda 
/bin/rm -f /var/log/boot.log
/bin/rm -f /var/log/cron
/bin/rm -f /var/log/dmesg
/bin/rm -f /var/log/maillog
/bin/rm -f /var/log/messages
/bin/rm -f /var/log/secure
/bin/rm -f /var/log/spooler
/bin/rm -f /var/log/tallylog
/bin/rm -f /var/log/wpa_supplicant.log
/bin/rm -f /var/log/yum.log
/bin/rm -f /var/log/ovirt-guest-agent/ovirt-guest-agent.log
/bin/rm -f /var/log/tuned/tuned.log

# Truncate the audit logs
/bin/cat /dev/null > /var/log/audit/audit.log 
/bin/cat /dev/null > /var/log/wtmp 
/bin/cat /dev/null > /var/log/lastlog 
/bin/cat /dev/null > /var/log/grubby 

# Remove the traces of the template MAC address and UUIDs
sed -i '/^\(HWADDR\|UUID\)=/d' /etc/sysconfig/network-scripts/ifcfg-e*

# enable network interface onboot
sed -i -e 's@^ONBOOT="no@ONBOOT="yes@' /etc/sysconfig/network-scripts/ifcfg-e*

# Clean /tmp out ( vmware-tools dizini kalmali ) 
rm -rf /tmp/.*
rm -rf /var/tmp/*

#remove udev hardware rules 
/bin/rm -f /etc/udev/rules.d/70* 

#remove SSH host keys 
/bin/rm -f /etc/ssh/*key* 

#remove root users shell history 
/bin/rm -f ~root/.bash_history 
unset HISTFILE 

#remove root users SSH history 
/bin/rm -rf ~root/.ssh/

#remove machine-id
/bin/cat /dev/null > /etc/machine-id

# Remove the root user’s shell history
history -c

#### ............................................................................
#lock root password
####passwd -dl root

# configure sshd_config to only allow Pubkey Authentication
####sed -i -r 's/^#?(PermitRootLogin|PasswordAuthentication|PermitEmptyPasswords) (yes|no)/\1 no/' /etc/ssh/sshd_config
####sed -i -r 's/^#?(PubkeyAuthentication) (yes|no)/\1 yes/' /etc/ssh/sshd_config

# some variables
####export ADMIN_USER="admin"
####export ADMIN_PUBLIC_KEY="your public ssh key"

# add user 'ADMIN_USER'
####adduser $ADMIN_USER

# add public SSH key
####mkdir -m 700 /home/$ADMIN_USER/.ssh
####chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
####echo $ADMIN_PUBLIC_KEY > /home/$ADMIN_USER/.ssh/authorized_keys
####chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
####chown $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh/authorized_keys

# add support for ssh-add
####echo 'eval $(ssh-agent) > /dev/null' >> /home/$ADMIN_USER/.bashrc

# add user 'ADMIN_USER' to sudoers
####echo "$ADMIN_USER    ALL = NOPASSWD: ALL" > /etc/sudoers.d/$ADMIN_USER
####chmod 0440 /etc/sudoers.d/$ADMIN_USER

