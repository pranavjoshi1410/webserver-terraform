#!/bin/bash -xe
apt-get update -y
apt-get install nfs-common -y
mkdir -p /var/www/html
efs_host="${efs_name}"
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $efs_host:/ /var/www/html
# Edit fstab so EFS automatically loads on reboot
echo $efs_host:/ /var/www/html nfs4 defaults,_netdev 0 0 >> /etc/fstab
mkdir -p /var/log/apache2
efs_logs_host="${efs_logs_name}"
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $efs_logs_host:/ /var/log/apache2
# Edit fstab so EFS automatically loads on reboot
echo $efs_logs_host:/ /var/log/apache2 nfs4 defaults,_netdev 0 0 >> /etc/fstab
# Install apache webserver
apt-get install apache2 -y
echo “Hello World from $(hostname -f)” > /var/www/html/index.html
printf "\n" >> /var/www/html/index.html
printf "\n" >> /var/www/html/index.html
printf "Output of df -h command:\n" >> /var/www/html/index.html
printf "%s\n" "$(df -h)" >> /var/www/html/index.html