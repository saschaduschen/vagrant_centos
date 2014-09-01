# install tools
#
# already installed:
# netstat	: shows open ports and which port was opened by which process
# arping	: usefull if there are any problems on OSI layer 2 (arp flux for example)
# free	: shows different information about memory
# vmstat 	: shows different information about the system like memory, cpu, swap
# df 		: shows disk usage
# du 		: shows Filesize of folders
# w 		: shows users logged in
# uptime 	: shows the uptime of the system
# ps 		: shows running processes (used in combination with grep)
#
# to be installed:
# lsof 	: shows which file is used by which process
# tcpdump 	: logs all network traffic
# iptraf 	: shows netwok traffic in realtime
# htop 	: improved version of top, shows different system information in realtime.

echo "installing tools"
yum install -y -q lsof tcpdump iptraf htop 

# set hostname
echo "set hostname"
sed -i 's/^HOSTNAME=.*$/HOSTNAME=wizbox/' /etc/sysconfig/network
hostname wizbox

# configure shell
echo "configure shell"
# removes default promt
sed -i '/\[ "$PS1" =/ s/^/#/' /etc/bashrc
# insert custom promt: username@hosrname::timestamp>
echo 'PS1="\u@\H::\D{%F %T}>"' >> /etc/bashrc
#colors the promt for the root user red
echo 'PS1="\[\033[0;31m\]\u@\H::\D{%F %T}> \[\033[0m\]"' >> /root/.bashrc

# configure ssh
#
# on every login there will be a welcome message which provides the following information:
# number of users currently logged in
# current disk space of the root disk
# amount of free memory
echo "configure ssh"
/bin/cat << EOF > /etc/profile.d/motd.sh 
#!/bin/bash
#
# number of users conneted
users=\`w |grep sshd | wc -l\`
echo "\$users user connected"

# diskspace of root disk
freedisk=\`df -h | grep -w / | awk '{print \$4}'\`
totaldisk=\`df -h | grep -w / | awk '{print \$2}'\`
echo "\$freedisk of \$totaldisk free Diskspace"

# amount of free memory
freemem=\`free -m | grep "Mem:" | awk '{print \$4}'\`
totalmem=\`free -m | grep "Mem:" | awk '{print \$2}'\`
echo "\${freemem}M of \${totalmem}M free Memory"
EOF

# disable selinux
echo "disable selinux"
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/sysconfig/selinux

# optimize sysctl
# 
# optimizing is always difficult because it depends on the function of the system.
# in this case my goal is to improve network traffic.
# 
# tcp_timestapms 	: remove overhead from tcp packages.
#
# tcp_window_scaling	: allows they system to recive bigger tcp packages
echo "optimize sysctl"
echo "
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_window_scaling = 1 " >> /etc/sysctl.conf

# configure Firewall
#
# this part will set up basic rules to controll the network access.i
# unfortunately I couldn't find a way to enable "vagrant ssh" and only allow connections from the subnet 172.16.0.0/16
#
echo "configure Firewall"
# allow to acces the server on port 80 from any IP.
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# allow to acces the server on port 443 from any IP.
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
# allow to acces the server on port 22 from the subnet 172.16.0.0/16.
iptables -A INPUT -p tcp -s 172.16.0.0/16 --dport 22 -j ACCEPT
# allow ssh from the host (needed for vagrant)
hostip=`netstat -an |grep ":22" |grep ESTABLISHED | awk '{print $5}' |cut -d":" -f1`
iptables -A INPUT -p tcp -s $hostip --dport 22 -j ACCEPT
# allow nfs for vagrant nfs mount
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# deny all other connection to the server
iptables -P INPUT DROP
iptables -L

# optimize fstab
#
# optimizing is always difficult because it depends on the function of the system.
# in this case my goal is to improve the write performance.  
#
# warning		: by optimizing the performance may result in dataloss after a systemcrash 
#
# noatime		: Linux will not record the access time of a file anymore.
# barrier=0	: Linux will not enforce proper ordering of writes, but after a system crash you need to use fsck. 

echo "optimize fstab"
sed -i '/ \/ / s/defaults/barrier=0,noatime,defaults/' /etc/fstab
